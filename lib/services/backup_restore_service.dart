import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import 'offline_db_helper.dart';
import 'sync_service.dart';

class BackupRestoreService {
  static final BackupRestoreService instance = BackupRestoreService._();
  BackupRestoreService._();

  /// Topological dependency order for uploading tables to Supabase Cloud
  static const List<String> uploadTableOrder = [
    // 1. Roles and global configs
    'roles',
    'rate_configs',
    'main_dairy_rate_configs',
    'app_settings',
    // 2. Primary master entities
    'farmers',
    'main_dairies',
    'suppliers',
    'customers',
    'products',
    'employees',
    // 3. Dependent master entities
    'animals',
    'role_permissions',
    // 4. Primary transactions
    'milk_collections',
    'main_dairy_collections',
    'sales',
    'purchases',
    'payments',
    'expenses',
    'main_dairy_payments',
    'rate_history',
    // 5. Line items / detail transactions
    'sale_items',
    'purchase_items',
  ];

  /// Initialize SQLite factory on desktop platforms
  void _ensureSqliteInitialized() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// Inspect a .db backup file and return row counts for recognized tables
  Future<Map<String, int>> inspectBackupFile(String filePath) async {
    _ensureSqliteInitialized();
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Backup file does not exist at: $filePath');
    }

    final db = await databaseFactory.openDatabase(
      filePath,
      options: OpenDatabaseOptions(readOnly: true),
    );

    final summary = <String, int>{};
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );
      for (var t in tables) {
        final tableName = t['name'].toString();
        if (tableName == 'sync_queue' || tableName == 'sync_metadata') continue;
        try {
          final countRes = await db.rawQuery('SELECT COUNT(*) AS c FROM $tableName');
          final count = (countRes.first['c'] as num?)?.toInt() ?? 0;
          if (count > 0) {
            summary[tableName] = count;
          }
        } catch (_) {}
      }
    } finally {
      await db.close();
    }

    return summary;
  }

  /// Export Universal .db Backup File
  Future<String> exportBackup({void Function(String message)? onProgress}) async {
    _ensureSqliteInitialized();
    final baseDir = await OfflineDbHelper.instance.getBaseStorageDirectory();
    final backupFolder = Directory(p.join(baseDir.path, 'Milkdatabase', 'Backups'));
    if (!await backupFolder.exists()) {
      await backupFolder.create(recursive: true);
    }

    final now = DateTime.now();
    final timeStamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final targetPath = p.join(backupFolder.path, 'dairy_backup_$timeStamp.db');

    // 1. Offline or Hybrid Edition: Copy local SQLite database
    if (AppConfig.isOfflineMode) {
      onProgress?.call('Compacting and optimizing local database...');
      await OfflineDbHelper.instance.compactDatabase();
      final dbPath = await OfflineDbHelper.instance.getDatabasePath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        throw Exception('No local database found to back up.');
      }
      onProgress?.call('Creating copy of local database...');
      await dbFile.copy(targetPath);
      onProgress?.call('Backup created successfully.');
      return targetPath;
    }

    // 2. Online Edition: Fetch all data from Supabase Cloud and generate a universal .db file
    onProgress?.call('Connecting to cloud account...');
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged into your Online account to export cloud backup.');
    }

    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    final db = await databaseFactory.openDatabase(targetPath);
    try {
      onProgress?.call('Preparing local database schema...');
      await OfflineDbHelper.instance.createAllTables(db);

      for (var i = 0; i < uploadTableOrder.length; i++) {
        final table = uploadTableOrder[i];
        onProgress?.call('Exporting $table (${i + 1}/${uploadTableOrder.length})...');

        try {
          // Query table from Supabase Cloud
          final validCols = await _getTableColumns(db, table);
          if (validCols.isEmpty) continue;

          final rows = await client.from(table).select().timeout(const Duration(seconds: 45));
          if (rows.isNotEmpty) {
            final batch = db.batch();
            for (var r in rows) {
              final sanitized = SyncService.instance.sanitizeRowForSqlite(
                Map<String, dynamic>.from(r),
                validCols,
              );
              batch.insert(
                table,
                sanitized,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            await batch.commit(noResult: true);
          }
        } catch (e) {
          debugPrint('Online export note for table $table: $e');
        }
      }
      try {
        await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
        await db.execute('VACUUM');
      } catch (_) {}
    } finally {
      await db.close();
    }

    onProgress?.call('Universal .db backup created successfully.');
    return targetPath;
  }

  /// Import Universal .db Backup File
  Future<void> importBackup({
    required String filePath,
    void Function(String message, double progress)? onProgress,
  }) async {
    _ensureSqliteInitialized();
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('Selected backup file does not exist: $filePath');
    }

    // Verify it is a valid SQLite file
    final headerBytes = await sourceFile.openRead(0, 16).first;
    final headerStr = String.fromCharCodes(headerBytes);
    if (!headerStr.startsWith('SQLite format 3')) {
      throw Exception('Selected file is not a valid SQLite .db database.');
    }

    // 1. Offline or Hybrid Mode: Direct safe atomic restore into local SQLite
    if (AppConfig.isOfflineMode) {
      onProgress?.call('Restoring database safely...', 0.3);
      await OfflineDbHelper.instance.restoreDatabaseSafely(filePath);

      if (AppConfig.isHybridMode) {
        onProgress?.call('Queueing restored records for cloud sync...', 0.8);
        SyncService.instance.triggerSync();
      }

      onProgress?.call('Database restored successfully!', 1.0);
      return;
    }

    // 2. Online Mode: Read .db file and batch-upload all data into Supabase Cloud
    onProgress?.call('Connecting to Supabase Cloud account...', 0.05);
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged into your Online account to import data into the cloud.');
    }
    final currentUid = user.id;

    final db = await databaseFactory.openDatabase(
      filePath,
      options: OpenDatabaseOptions(readOnly: true),
    );

    try {
      final totalSteps = uploadTableOrder.length;
      int completedSteps = 0;

      for (var table in uploadTableOrder) {
        completedSteps++;
        final stepPercent = completedSteps / totalSteps;

        // Check if table exists in source SQLite database
        final existsRes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
          [table],
        );
        if (existsRes.isEmpty) continue;

        final rows = await db.query(table);
        if (rows.isEmpty) continue;

        onProgress?.call('Uploading $table (${rows.length} records)...', stepPercent);

        // Process and upload rows in chunks of 50 to prevent HTTP timeouts
        const chunkSize = 50;
        for (var i = 0; i < rows.length; i += chunkSize) {
          final end = (i + chunkSize < rows.length) ? i + chunkSize : rows.length;
          final chunk = rows.sublist(i, end);

          final formattedChunk = <Map<String, dynamic>>[];
          for (var r in chunk) {
            final formatted = SyncService.instance.formatRowForSupabase(
              table,
              Map<String, dynamic>.from(r),
              currentUid,
            );
            formattedChunk.add(formatted);
          }

          // In app_settings, prevent unique constraint collision by reusing user's existing settings row id
          if (table == 'app_settings') {
            try {
              final existing = await client.from('app_settings').select('id').eq('user_id', currentUid).maybeSingle();
              if (existing != null && existing['id'] != null) {
                for (var f in formattedChunk) {
                  f['id'] = existing['id'];
                }
              }
            } catch (_) {}
          }

          if (formattedChunk.isNotEmpty) {
            try {
              await client.from(table).upsert(formattedChunk).timeout(const Duration(seconds: 45));
            } catch (chunkErr) {
              debugPrint('Batch upsert failed for $table, trying row-by-row fallback: $chunkErr');
              for (var singleRow in formattedChunk) {
                try {
                  await client.from(table).upsert(singleRow).timeout(const Duration(seconds: 15));
                } catch (rowErr) {
                  debugPrint('Skipped problematic row in $table (${singleRow['id']}): $rowErr');
                }
              }
            }
          }
        }
      }

      onProgress?.call('All data uploaded to cloud successfully!', 1.0);
    } finally {
      await db.close();
    }
  }

  /// Opens native file picker to select a .db backup file
  Future<String?> pickBackupFile() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['db', 'sqlite', 'sqlite3', 'bak'],
    );

    if (result != null && result.path != null) {
      return result.path!;
    }
    return null;
  }

  /// Save or Share the exported backup file
  Future<void> deliverBackupFile(String backupPath, BuildContext context) async {
    final file = File(backupPath);
    final fileName = p.basename(backupPath);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // On mobile: Share via system dialog (WhatsApp, Google Drive, Gmail, Files, etc.)
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(backupPath)],
          text: 'Dairy Management Database Backup (.db)',
          subject: fileName,
        ),
      );
    } else {
      // On Windows / Desktop: Let user choose where to save the file
      try {
        final bytes = await file.readAsBytes();
        final saveUri = await FilePicker.saveFile(
          dialogTitle: 'Save Database Backup (.db)',
          fileName: fileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['db'],
        );

        if (saveUri != null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Backup saved successfully: $fileName'),
                backgroundColor: Colors.green.shade700,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      } catch (_) {}

      // Fallback: Show location dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Backup File Ready'),
              ],
            ),
            content: SelectableText(
              'Your backup file has been generated:\n\n$backupPath\n\nYou can copy this file to a USB flash drive or another PC.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<Set<String>> _getTableColumns(Database db, String table) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.map((r) => r['name'].toString()).toSet();
    } catch (_) {
      return {};
    }
  }
}
