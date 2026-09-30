import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_config.dart';
import '../services/offline_db_helper.dart';
import '../services/backup_restore_service.dart';
import '../providers/settings_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/farmer_provider.dart';
import '../providers/milk_collection_provider.dart';
import '../providers/product_provider.dart';
import '../services/translations.dart';
import '../providers/language_provider.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isProcessing = false;
  String _statusMessage = '';
  double _progressValue = 0.0;

  String? _dbPath;
  int _dbSizeBytes = 0;
  bool _isCompacting = false;

  @override
  void initState() {
    super.initState();
    _loadDbInfo();
  }

  Future<void> _loadDbInfo() async {
    if (AppConfig.isOfflineMode) {
      try {
        final path = await OfflineDbHelper.instance.getDatabasePath();
        final file = File(path);
        final size = await file.exists() ? await file.length() : 0;
        if (mounted) {
          setState(() {
            _dbPath = path;
            _dbSizeBytes = size;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _handleCompact() async {
    setState(() => _isCompacting = true);
    try {
      final res = await OfflineDbHelper.instance.compactDatabase();
      await _loadDbInfo();
      if (mounted) {
        final beforeKb = ((res['before'] ?? 0) / 1024).toStringAsFixed(1);
        final afterKb = ((res['after'] ?? 0) / 1024).toStringAsFixed(1);
        final savedKb = (((res['before'] ?? 0) - (res['after'] ?? 0)) / 1024).toStringAsFixed(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              'Database compressed successfully! Reclaimed $savedKb KB ($beforeKb KB → $afterKb KB). 0 data lost.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Compaction notice: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompacting = false);
    }
  }

  Future<void> _handleExport() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Preparing backup...';
    });

    try {
      final backupPath = await BackupRestoreService.instance.exportBackup(
        onProgress: (msg) {
          if (mounted) setState(() => _statusMessage = msg);
        },
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        await BackupRestoreService.instance.deliverBackupFile(backupPath, context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Backup Failed'),
              ],
            ),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    try {
      final pickedPath = await BackupRestoreService.instance.pickBackupFile();
      if (pickedPath == null || !mounted) return;

      // 1. Inspect backup file and display preview summary
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Inspecting backup file...'),
                ],
              ),
            ),
          ),
        ),
      );

      Map<String, int> summary;
      try {
        summary = await BackupRestoreService.instance.inspectBackupFile(pickedPath);
      } finally {
        if (mounted) Navigator.pop(context); // Close inspect dialog
      }

      if (!mounted) return;

      // 2. Show confirmation dialog with detected records
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 28),
              const SizedBox(width: 10),
              const Text('Confirm Restore'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConfig.isOfflineMode
                      ? 'Restoring will replace the current local database with data from the backup file. A safe rollback copy will be preserved in case of errors.'
                      : 'Restoring will read all records from the backup file and batch-upload them directly into your Supabase Cloud account.',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Records Found in Backup File:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(height: 12),
                      if (summary.isEmpty)
                        const Text('No standard records detected in this file.', style: TextStyle(color: Colors.red))
                      else
                        ...summary.entries.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatTableName(e.key),
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                  Text(
                                    '${e.value} records',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Are you sure you want to proceed?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: Text(AppConfig.isOfflineMode ? 'RESTORE DATABASE' : 'UPLOAD TO CLOUD'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // 3. Execute Restore with live progress
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Starting restore process...';
        _progressValue = 0.0;
      });

      await BackupRestoreService.instance.importBackup(
        filePath: pickedPath,
        onProgress: (msg, percent) {
          if (mounted) {
            setState(() {
              _statusMessage = msg;
              _progressValue = percent;
            });
          }
        },
      );

      // Invalidate providers to refresh UI with freshly restored data
      ref.invalidate(settingsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(farmersProvider);
      ref.invalidate(milkCollectionProvider);
      ref.invalidate(productsProvider);

      if (mounted) {
        setState(() => _isProcessing = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Restore Successful'),
              ],
            ),
            content: Text(
              AppConfig.isOfflineMode
                  ? 'Your database has been restored successfully.'
                  : 'All records have been imported and uploaded to Supabase Cloud successfully.',
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
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Restore Error'),
              ],
            ),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  String _formatTableName(String name) {
    return name
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final editionName = AppConfig.isHybridMode
        ? 'Hybrid Auto-Sync Edition'
        : (AppConfig.isOfflineMode ? 'Offline Standalone Edition' : 'Online Cloud Edition');

    final editionColor = AppConfig.isHybridMode
        ? Colors.teal.shade800
        : (AppConfig.isOfflineMode ? Colors.blueGrey.shade800 : Colors.blue.shade900);

    return Scaffold(
      appBar: AppBar(
        title: Text('Backup & Restore Database'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: editionColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Info Banner
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: editionColor.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: editionColor,
                            radius: 28,
                            child: const Icon(Icons.settings_backup_restore, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  editionName,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: editionColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Universal .db Database File Compatibility across Offline, Hybrid, and Online editions on Windows & Android.'.tr,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Active Processing Indicator
                  if (_isProcessing)
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.amber.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 3),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    _statusMessage,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            if (_progressValue > 0) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: _progressValue,
                                  minHeight: 8,
                                  backgroundColor: Colors.amber.shade200,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${(_progressValue * 100).toInt()}%',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  if (_isProcessing) const SizedBox(height: 24),

                  // 1. EXPORT BACKUP CARD
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(22.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.file_download, color: Colors.blue.shade800, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Export Database Backup'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text(
                                      AppConfig.isOfflineMode
                                          ? 'Exports all local records into a standard .db file.'
                                          : 'Pulls all your data from Supabase Cloud and packages it into a standard .db file.',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text(
                            '• Contains Farmers, Milk Collections, Rate Configs, Products, Sales, Animals, and settings.\n'
                            '• The exported .db file can be transferred to a USB drive or other devices.\n'
                            '• Can be imported into Offline, Hybrid, or Online editions at any time.',
                            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing ? null : _handleExport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.download),
                              label: Text(
                                'EXPORT BACKUP (.db)'.tr,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. IMPORT BACKUP CARD
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(22.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.file_upload, color: Colors.teal.shade800, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Import & Restore Backup'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text(
                                      AppConfig.isOfflineMode
                                          ? 'Safely restores local SQLite data from a selected .db backup file.'
                                          : 'Reads a .db backup file and batch-uploads all data into your Supabase Cloud account.',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          Text(
                            AppConfig.isOfflineMode
                                ? '• Automatic rollback copy is created before restoring to prevent data loss.\n'
                                  '• Any .db backup file created on Windows or Android can be selected.\n'
                                  '• In Hybrid mode, all restored entries are automatically queued for cloud synchronization.'
                                : '• Perfect for migrating from Offline Edition to Online Cloud Edition!\n'
                                  '• Automatically assigns your Cloud User ID to all imported farmers, milk collections, and sales.\n'
                                  '• Foreign keys and generated columns are verified and safely handled.',
                            style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing ? null : _handleImport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                'IMPORT BACKUP (.db)'.tr,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. DATABASE STORAGE & LOSSLESS COMPRESSION CARD
                  if (AppConfig.isOfflineMode) ...[
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(22.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.folder_special, color: Colors.green.shade800, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Database Storage & Lossless Compaction'.tr,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Stored in Milkdatabase folder with zero-loss SQLite page compaction.'.tr,
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.black87),
                                      const SizedBox(width: 8),
                                      Text('Storage Folder: '.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('Documents/Milkdatabase', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 13)),
                                    ],
                                  ),
                                  if (_dbPath != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'File: $_dbPath',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'monospace'),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.data_usage, size: 18, color: Colors.black87),
                                      const SizedBox(width: 8),
                                      Text('Current DB File Size: '.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text(
                                        _dbSizeBytes > 0 ? '${(_dbSizeBytes / 1024).toStringAsFixed(1)} KB' : 'Checking...',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade800, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              '• Compressing runs SQLite VACUUM and WAL truncation to eliminate database bloat.\n'
                              '• All tables, records, and calculations are 100% preserved without any loss of data.\n'
                              '• Reduces disk footprint and accelerates database query performance.',
                              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (_isProcessing || _isCompacting) ? null : _handleCompact,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 2,
                                ),
                                icon: _isCompacting
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.compress),
                                label: Text(
                                  _isCompacting ? 'COMPACTING DATABASE...'.tr : 'COMPRESS & OPTIMIZE DATABASE (VACUUM)'.tr,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Data Safety & Risk Advisory Note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueGrey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.blueGrey, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Data Safety Guarantee: The import engine uses transaction batching, foreign key dependency ordering, and atomic rollback to ensure that your database records are never corrupted during export or import.'.tr,
                            style: const TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
