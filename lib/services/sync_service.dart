import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'app_config.dart';
import 'offline_db_helper.dart';

enum SyncStatus { idle, syncing, offline, error }

class SyncState {
  final bool isOnline;
  final SyncStatus status;
  final int pendingCount;
  final String? message;
  final DateTime? lastSyncTime;

  const SyncState({
    required this.isOnline,
    required this.status,
    required this.pendingCount,
    this.message,
    this.lastSyncTime,
  });

  SyncState copyWith({
    bool? isOnline,
    SyncStatus? status,
    int? pendingCount,
    String? message,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      message: message ?? this.message,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final ValueNotifier<SyncState> state = ValueNotifier<SyncState>(
    const SyncState(
      isOnline: false,
      status: SyncStatus.idle,
      pendingCount: 0,
    ),
  );

  /// Incremented after every successful cloud pull to notify UI providers to refresh
  final ValueNotifier<int> syncVersion = ValueNotifier<int>(0);

  StreamSubscription? _connectivitySub;
  Timer? _periodicTimer;
  Timer? _debounceTimer;
  RealtimeChannel? _realtimeChannel;
  bool _isSyncRunning = false;
  bool _initialized = false;

  /// Start monitoring and sync service
  Future<void> start() async {
    if (_initialized) return;
    _initialized = true;

    await refreshPendingCount();

    // Listen to network changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      _checkConnectivityAndSync();
    });

    // Initial sync on launch
    _checkConnectivityAndSync(isInitial: true);

    // Setup Supabase Realtime channel so any new entry on Supabase syncs instantly
    _setupRealtimeSubscription();

    // Periodic heartbeat sync every 60 seconds (silent check, only syncs if new data exists)
    _periodicTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (AppConfig.isHybridMode) {
        _heartbeatCheck();
      }
    });
  }

  void stop() {
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _initialized = false;
  }

  void _setupRealtimeSubscription() {
    try {
      final client = Supabase.instance.client;
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = client.channel('public:hybrid-realtime')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          callback: (payload) {
            _handleRealtimePayload(payload);
          },
        )
        ..subscribe();
    } catch (e) {
      debugPrint('Realtime channel subscription note: $e');
    }
  }

  Future<void> _handleRealtimePayload(PostgresChangePayload payload) async {
    final table = payload.table;
    if (!cloudTableColumns.containsKey(table)) return;

    try {
      final client = Supabase.instance.client;
      final currentUid = client.auth.currentUser?.id;
      if (currentUid != null) {
        if (payload.eventType == PostgresChangeEvent.delete) {
          final recordUid = payload.oldRecord['user_id'] ?? payload.oldRecord['owner_id'];
          if (recordUid != null && recordUid.toString().isNotEmpty && recordUid.toString() != currentUid) return;
        } else {
          final recordUid = payload.newRecord['user_id'] ?? payload.newRecord['owner_id'];
          if (recordUid != null && recordUid.toString().isNotEmpty && recordUid.toString() != currentUid) return;
        }
      }

      final db = await OfflineDbHelper.instance.database;
      final validCols = await _getTableColumns(db, table);
      if (validCols.isEmpty) return;

      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id']?.toString();
        if (id != null && id.isNotEmpty) {
          await db.delete(table, where: 'id = ?', whereArgs: [id]);
          syncVersion.value++;
        }
      } else {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          final sanitized = sanitizeRowForSqlite(newRecord, validCols);
          await db.insert(
            table,
            sanitized,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          final rowTs = (newRecord['updated_at'] ?? newRecord['created_at'])?.toString();
          if (rowTs != null && rowTs.isNotEmpty) {
            await OfflineDbHelper.instance.setLastPulledAt(table, rowTs);
          }
          syncVersion.value++;
        }
      }
    } catch (e) {
      debugPrint('Realtime payload handling note: $e');
    }
  }

  /// Refreshes the pending items count from SQLite
  Future<int> refreshPendingCount() async {
    try {
      final count = await OfflineDbHelper.instance.getPendingSyncCount();
      state.value = state.value.copyWith(pendingCount: count);
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Debounced trigger called after local mutations
  void triggerSync() {
    if (!AppConfig.isHybridMode) return;
    refreshPendingCount();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      final isConnected = await _hasInternetConnection();
      if (isConnected) {
        await _pushOnly();
      }
    });
  }

  /// Check connectivity and execute sync if needed
  Future<void> _checkConnectivityAndSync({bool isInitial = false}) async {
    if (!AppConfig.isHybridMode) return;

    final isConnected = await _hasInternetConnection();
    final count = await refreshPendingCount();

    if (!isConnected) {
      state.value = state.value.copyWith(
        isOnline: false,
        status: SyncStatus.offline,
        pendingCount: count,
        message: count > 0 ? '$count items pending sync' : 'Offline',
      );
      return;
    }

    if (isInitial) {
      final client = Supabase.instance.client;
      await _ensureCloudAuth();
      if (client.auth.currentUser != null) {
        await syncAll(forceFull: true);
      }
    } else {
      if (count > 0) {
        await _pushOnly();
      }
      await _pullIncrementalCloudUpdates();
    }
  }

  /// Silent periodic heartbeat:
  /// - Only pushes if pendingCount > 0
  /// - Only pulls if there are newer records on Supabase
  /// - Does NOT show intrusive 'Syncing...' UI or rebuild screens if there is no new data
  Future<void> _heartbeatCheck() async {
    if (!AppConfig.isHybridMode || _isSyncRunning) return;

    final isConnected = await _hasInternetConnection();
    if (!isConnected) {
      final count = await refreshPendingCount();
      state.value = state.value.copyWith(
        isOnline: false,
        status: SyncStatus.offline,
        pendingCount: count,
        message: count > 0 ? '$count items pending sync' : 'Offline',
      );
      return;
    }

    // 1. If there are pending local items, push them
    final count = await refreshPendingCount();
    if (count > 0) {
      await _pushOnly();
    }

    // 2. Silently check for newer records on Supabase using timestamp delta
    await _pullIncrementalCloudUpdates();
  }

  /// Pushes local pending items ONLY when pendingCount > 0
  Future<void> _pushOnly() async {
    if (_isSyncRunning) return;
    _isSyncRunning = true;
    try {
      final count = await refreshPendingCount();
      if (count == 0) return;

      state.value = state.value.copyWith(
        isOnline: true,
        status: SyncStatus.syncing,
        message: 'Uploading $count pending items...',
      );

      await _ensureCloudAuth();
      if (!await _isAccountActive()) return;
      await _pushPendingQueue();

      final remaining = await refreshPendingCount();
      state.value = state.value.copyWith(
        isOnline: true,
        status: SyncStatus.idle,
        pendingCount: remaining,
        lastSyncTime: DateTime.now(),
        message: remaining == 0 ? 'All synced' : '$remaining items pending',
      );
    } catch (e) {
      state.value = state.value.copyWith(
        status: SyncStatus.error,
        message: 'Push error: $e',
      );
    } finally {
      _isSyncRunning = false;
    }
  }

  /// Tests if Supabase cloud is reachable
  Future<bool> _hasInternetConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none)) {
        return false;
      }

      // Quick probe to Supabase or DNS
      try {
        final res = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        if (res.isNotEmpty && res[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        // Fallback for environments where DNS lookup fails
        return results.any((r) => r != ConnectivityResult.none);
      }
    } catch (_) {}
    return false;
  }

  /// Ensures Cloud Authentication Session is active using saved credentials
  Future<void> _ensureCloudAuth() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedEmail = prefs.getString(AppConfig.prefKey('logged_in_email')) ??
            prefs.getString(AppConfig.prefKey('active_offline_user_email')) ??
            prefs.getString('offline_logged_in_email') ??
            prefs.getString('active_offline_user_email');
        final savedPin = prefs.getString(AppConfig.prefKey('admin_pin')) ??
            prefs.getString('offline_admin_pin');
        if (savedEmail != null && savedPin != null && savedEmail.contains('@')) {
          await client.auth.signInWithPassword(
            email: savedEmail.trim().toLowerCase(),
            password: savedPin.trim(),
          ).timeout(const Duration(seconds: 10));
        }
      } catch (e) {
        debugPrint('Cloud auth signIn note: $e');
      }
    }
  }

  Future<bool> _isAccountActive() async {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return true;

      final res = await client
          .from('users')
          .select('status')
          .eq('id', currentUser.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (res != null && res['status'] != null) {
        final s = res['status'].toString().trim().toLowerCase();
        final prefKey = AppConfig.prefKey('account_status_${currentUser.id}');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefKey, s);
        return s == 'active';
      }
    } catch (_) {}
    return true;
  }

  /// Perform Push & Pull sync (used by manual Sync button or initial launch)
  Future<void> syncAll({bool forceFull = false}) async {
    if (_isSyncRunning) return;
    _isSyncRunning = true;

    try {
      final count = await refreshPendingCount();
      state.value = state.value.copyWith(
        isOnline: true,
        status: SyncStatus.syncing,
        message: count > 0 ? 'Syncing $count pending items...' : 'Checking cloud updates...',
      );

      // 0. Ensure Cloud Auth is established before attempting push/pull
      await _ensureCloudAuth();

      // Verify account status before cloud communication
      final isActive = await _isAccountActive();
      if (!isActive) {
        state.value = state.value.copyWith(
          isOnline: true,
          status: SyncStatus.idle,
          message: 'Account pending activation',
        );
        return;
      }

      // 1. Push pending local changes to Supabase Cloud only if count > 0
      if (count > 0) {
        await _pushPendingQueue();
      }

      // 2. Pull from Cloud to SQLite
      if (forceFull) {
        await _pullCloudUpdates();
        OfflineDbHelper.instance.compactDatabase().ignore();
      } else {
        await _pullIncrementalCloudUpdates();
      }

      final remaining = await refreshPendingCount();
      state.value = state.value.copyWith(
        isOnline: true,
        status: SyncStatus.idle,
        pendingCount: remaining,
        lastSyncTime: DateTime.now(),
        message: remaining == 0 ? 'All synced' : '$remaining items pending',
      );
    } catch (e) {
      state.value = state.value.copyWith(
        status: SyncStatus.error,
        message: 'Sync error: $e',
      );
    } finally {
      _isSyncRunning = false;
    }
  }

  /// Supabase Cloud Table Schema Whitelist
  static const Map<String, Set<String>> cloudTableColumns = {
    'rate_configs': {'id', 'animal_type', 'rate_type', 'base_fat', 'base_snf', 'base_rate', 'fat_range_from', 'fat_range_to', 'fat_point', 'fat_rate', 'snf_range_from', 'snf_range_to', 'snf_point', 'snf_rate', 'effective_date', 'is_active', 'created_at'},
    'main_dairy_rate_configs': {'id', 'animal_type', 'rate_type', 'base_fat', 'base_snf', 'base_rate', 'fat_rate', 'snf_rate', 'fat_range_from', 'fat_range_to', 'snf_range_from', 'snf_range_to', 'effective_date', 'is_active', 'created_at', 'fat_point', 'snf_point'},
    'app_settings': {'id', 'dairy_name', 'logo_url', 'address', 'mobile', 'email', 'gst_number', 'license_number', 'updated_at', 'user_id', 'gst_no', 'owner_name', 'receipt_header', 'receipt_footer'},
    'roles': {'id', 'name', 'created_at', 'owner_id'},
    'role_permissions': {'id', 'role_id', 'module_name', 'can_view', 'can_add', 'can_edit', 'can_delete', 'can_print', 'owner_id'},
    'products': {'id', 'name', 'category', 'unit', 'purchase_rate', 'selling_rate', 'opening_stock', 'current_stock', 'min_stock', 'tax_percent', 'status', 'created_at', 'user_id'},
    'stock_transactions': {'id', 'product_id', 'transaction_date', 'trans_type', 'quantity', 'reference_id', 'reference_type', 'created_at', 'user_id'},
    'farmers': {'id', 'name', 'mobile', 'address', 'village', 'bank_details', 'opening_balance', 'current_balance', 'status', 'notes', 'created_at', 'user_id', 'farmer_no'},
    'animals': {'id', 'farmer_id', 'animal_type', 'breed', 'name', 'age', 'milk_capacity', 'status', 'notes', 'created_at', 'user_id'},
    'main_dairies': {'id', 'dairy_no', 'name', 'contact_person', 'mobile', 'email', 'address', 'opening_balance', 'current_balance', 'status', 'notes', 'created_at', 'village', 'animal_type'},
    'suppliers': {'id', 'name', 'mobile', 'address', 'product_type', 'opening_balance', 'current_balance', 'payment_terms', 'status', 'created_at', 'user_id'},
    'customers': {'id', 'name', 'mobile', 'address', 'customer_type', 'opening_balance', 'current_balance', 'credit_limit', 'status', 'created_at', 'user_id'},
    'employees': {'id', 'name', 'mobile', 'username', 'pin', 'role_id', 'is_active', 'photo_url', 'created_at', 'owner_id'},
    'milk_collections': {'id', 'collection_date', 'collection_time', 'farmer_id', 'animal_id', 'milk_type', 'quantity', 'fat', 'snf', 'rate', 'payment_status', 'remarks', 'created_at', 'user_id', 'shift'},
    'sales': {'id', 'invoice_no', 'sale_date', 'customer_id', 'subtotal', 'discount', 'tax_amount', 'grand_total', 'paid_amount', 'balance', 'payment_mode', 'created_at', 'user_id', 'farmer_id'},
    'sale_items': {'id', 'sale_id', 'product_id', 'quantity', 'unit', 'rate', 'total_amount'},
    'purchases': {'id', 'invoice_no', 'purchase_date', 'supplier_id', 'subtotal', 'discount', 'tax_amount', 'grand_total', 'paid_amount', 'balance', 'created_at', 'user_id', 'vehicle_no'},
    'purchase_items': {'id', 'purchase_id', 'product_id', 'quantity', 'purchase_rate', 'total_amount'},
    'expenses': {'id', 'category', 'amount', 'expense_date', 'payment_mode', 'notes', 'description', 'remarks', 'user_id', 'created_at'},
    'payments': {'id', 'payment_date', 'party_type', 'farmer_id', 'customer_id', 'supplier_id', 'payment_type', 'amount', 'payment_mode', 'reference_no', 'remarks', 'created_at', 'user_id'},
    'rate_history': {'id', 'item_name', 'old_rate', 'new_rate', 'rate_category', 'effective_from', 'reason', 'user_id', 'created_at'},
    'main_dairy_collections': {'id', 'main_dairy_id', 'collection_date', 'shift', 'milk_type', 'quantity', 'fat', 'snf', 'rate', 'total_amount', 'payment_status', 'remarks', 'created_at'},
    'main_dairy_payments': {'id', 'main_dairy_id', 'amount', 'payment_date', 'payment_mode', 'reference_no', 'remarks', 'created_at'},
    'bonus_settings': {'id', 'cow_rate', 'buffalo_rate', 'updated_at', 'user_id'},
    'bonus_transactions': {'id', 'farmer_id', 'farmer_name', 'farmer_no', 'animal_type', 'from_date', 'to_date', 'milk_quantity', 'bonus_rate', 'total_bonus', 'previous_paid', 'paid_amount', 'total_paid', 'remaining_bonus', 'payment_date', 'payment_mode', 'transaction_number', 'remarks', 'created_at', 'user_id'},
    'staff': {'id', 'name', 'phone', 'role', 'salary_amount', 'salary_type', 'balance', 'is_active', 'created_at', 'user_id'},
    'staff_transactions': {'id', 'staff_id', 'transaction_date', 'type', 'amount', 'remarks', 'created_at', 'user_id'},
    'staff_attendance': {'id', 'staff_id', 'attendance_date', 'status', 'created_at', 'user_id'},
  };

  /// Parent -> Child table dependency order for bunch upserts
  static const List<String> tableDependencyOrder = [
    'app_settings',
    'roles',
    'role_permissions',
    'employees',
    'rate_configs',
    'main_dairy_rate_configs',
    'farmers',
    'animals',
    'main_dairies',
    'suppliers',
    'customers',
    'products',
    'milk_collections',
    'sales',
    'sale_items',
    'purchases',
    'purchase_items',
    'stock_transactions',
    'expenses',
    'payments',
    'rate_history',
    'main_dairy_collections',
    'main_dairy_payments',
    'bonus_settings',
    'bonus_transactions',
    'staff',
    'staff_transactions',
    'staff_attendance',
  ];

  bool _isNetworkError(dynamic err) {
    final s = err.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('clientexception') ||
        s.contains('timeout') ||
        s.contains('network') ||
        s.contains('connection refused') ||
        s.contains('failed host lookup');
  }

  /// Pushes items from SQLite sync_queue to Supabase Cloud in bunches (bulk upsert)
  Future<void> _pushPendingQueue() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      await _ensureCloudAuth();
    }
    final currentUid = client.auth.currentUser?.id;
    const int maxBatchSize = 100;

    while (true) {
      final items = await OfflineDbHelper.instance.getPendingSyncItems(limit: 500);
      if (items.isEmpty) break;

      int processedCount = 0;
      bool hasNetworkError = false;

      // 1. Separate items by action: DELETE vs UPSERT
      final deleteItems = <Map<String, dynamic>>[];
      final upsertItems = <Map<String, dynamic>>[];

      for (var item in items) {
        final action = item['action'] as String;
        if (action == 'DELETE') {
          deleteItems.add(item);
        } else {
          upsertItems.add(item);
        }
      }

      // 2. Process UPSERT items grouped by table, ordered by table dependencies
      if (upsertItems.isNotEmpty) {
        final Map<String, List<Map<String, dynamic>>> itemsByTable = {};
        for (var item in upsertItems) {
          final t = item['table_name'] as String;
          itemsByTable.putIfAbsent(t, () => []).add(item);
        }

        final sortedTables = itemsByTable.keys.toList()
          ..sort((a, b) {
            final idxA = tableDependencyOrder.indexOf(a);
            final idxB = tableDependencyOrder.indexOf(b);
            final orderA = idxA == -1 ? 999 : idxA;
            final orderB = idxB == -1 ? 999 : idxB;
            return orderA.compareTo(orderB);
          });

        for (var tableName in sortedTables) {
          if (hasNetworkError) break;
          final tableItems = itemsByTable[tableName]!;

          // Deduplicate multiple edits to the same row_id while tracking all queue IDs
          final Map<String, Map<String, dynamic>> latestRowsByRowId = {};
          final Map<String, List<int>> queueIdsByRowId = {};

          for (var item in tableItems) {
            final qId = item['id'] as int;
            final rowId = item['row_id'] as String;
            final payloadRaw = item['payload'] as String?;
            if (payloadRaw == null) {
              await OfflineDbHelper.instance.markSyncItemCompleted(qId);
              processedCount++;
              continue;
            }

            try {
              final row = jsonDecode(payloadRaw) as Map<String, dynamic>;
              final formatted = formatRowForSupabase(tableName, row, currentUid);
              latestRowsByRowId[rowId] = formatted;
              queueIdsByRowId.putIfAbsent(rowId, () => []).add(qId);
            } catch (jsonErr) {
              await OfflineDbHelper.instance.markSyncItemFailed(qId, 'Invalid JSON payload: $jsonErr');
              processedCount++;
            }
          }

          final distinctRowIds = latestRowsByRowId.keys.toList();
          if (distinctRowIds.isEmpty) continue;

          // Chunk into bunches of up to maxBatchSize
          for (int i = 0; i < distinctRowIds.length; i += maxBatchSize) {
            if (hasNetworkError) break;

            final end = (i + maxBatchSize < distinctRowIds.length) ? i + maxBatchSize : distinctRowIds.length;
            final chunkRowIds = distinctRowIds.sublist(i, end);
            final chunkRows = chunkRowIds.map((id) => latestRowsByRowId[id]!).toList();
            final chunkQueueIds = <int>[];
            for (var id in chunkRowIds) {
              chunkQueueIds.addAll(queueIdsByRowId[id] ?? []);
            }

            // Ensure uniform keys across rows in chunk for PostgREST
            final allKeys = <String>{};
            for (final r in chunkRows) {
              allKeys.addAll(r.keys);
            }
            final normalizedChunk = chunkRows.map((r) {
              final map = Map<String, dynamic>.from(r);
              for (final k in allKeys) {
                map.putIfAbsent(k, () => null);
              }
              return map;
            }).toList();

            try {
              // BUNCH / BULK UPSERT in a single HTTP request to Supabase
              await client
                  .from(tableName)
                  .upsert(normalizedChunk)
                  .timeout(const Duration(seconds: 30));

              // Mark all queue items in this bunch completed in SQLite
              await OfflineDbHelper.instance.markSyncItemsBatchCompleted(chunkQueueIds);
              processedCount += chunkQueueIds.length;
            } catch (bulkErr) {
              if (_isNetworkError(bulkErr)) {
                hasNetworkError = true;
                break;
              }

              // Fallback to row-by-row upsert so valid rows still sync
              for (var rowId in chunkRowIds) {
                final singleRow = latestRowsByRowId[rowId]!;
                final singleQIds = queueIdsByRowId[rowId] ?? [];
                try {
                  await client
                      .from(tableName)
                      .upsert(singleRow)
                      .timeout(const Duration(seconds: 15));
                  await OfflineDbHelper.instance.markSyncItemsBatchCompleted(singleQIds);
                  processedCount += singleQIds.length;
                } catch (singleErr) {
                  await OfflineDbHelper.instance.markSyncItemsBatchFailed(singleQIds, singleErr.toString());
                  processedCount += singleQIds.length;
                  if (_isNetworkError(singleErr)) {
                    hasNetworkError = true;
                    break;
                  }
                }
              }
            }
          }
        }
      }

      // 3. Process DELETE items grouped by table (in reverse dependency order)
      if (deleteItems.isNotEmpty && !hasNetworkError) {
        final Map<String, List<Map<String, dynamic>>> deletesByTable = {};
        for (var item in deleteItems) {
          final t = item['table_name'] as String;
          deletesByTable.putIfAbsent(t, () => []).add(item);
        }

        final sortedDeleteTables = deletesByTable.keys.toList()
          ..sort((a, b) {
            final idxA = tableDependencyOrder.indexOf(a);
            final idxB = tableDependencyOrder.indexOf(b);
            final orderA = idxA == -1 ? 0 : idxA;
            final orderB = idxB == -1 ? 0 : idxB;
            return orderB.compareTo(orderA);
          });

        for (var tableName in sortedDeleteTables) {
          if (hasNetworkError) break;
          final tableDeletes = deletesByTable[tableName]!;
          final rowIds = tableDeletes.map((e) => e['row_id'] as String).toSet().toList();
          final qIds = tableDeletes.map((e) => e['id'] as int).toList();

          try {
            // Bulk delete using inFilter in a single request
            await client.from(tableName).delete().inFilter('id', rowIds).timeout(const Duration(seconds: 30));
            await OfflineDbHelper.instance.markSyncItemsBatchCompleted(qIds);
            processedCount += qIds.length;
          } catch (deleteErr) {
            if (_isNetworkError(deleteErr)) {
              hasNetworkError = true;
              break;
            }
            // Fallback row-by-row
            for (var item in tableDeletes) {
              final qId = item['id'] as int;
              final rId = item['row_id'] as String;
              try {
                await client.from(tableName).delete().eq('id', rId).timeout(const Duration(seconds: 15));
                await OfflineDbHelper.instance.markSyncItemCompleted(qId);
                processedCount++;
              } catch (singleErr) {
                await OfflineDbHelper.instance.markSyncItemFailed(qId, singleErr.toString());
                processedCount++;
                if (_isNetworkError(singleErr)) {
                  hasNetworkError = true;
                  break;
                }
              }
            }
          }
        }
      }

      // If internet went down or no items were processed, stop loop
      if (hasNetworkError || processedCount == 0) {
        break;
      }
    }
  }

  /// Pulls ONLY newly added or updated rows from Supabase Cloud
  /// If there are no new rows on Supabase, it touches 0 records and does not rebuild UI!
  Future<void> _pullIncrementalCloudUpdates() async {
    final client = Supabase.instance.client;
    final db = await OfflineDbHelper.instance.database;
    await _ensureCloudAuth();
    if (!await _isAccountActive()) return;

    final cloudTables = [
      'rate_configs',
      'main_dairy_rate_configs',
      'app_settings',
      'roles',
      'role_permissions',
      'products',
      'farmers',
      'animals',
      'main_dairies',
      'suppliers',
      'customers',
      'employees',
      'milk_collections',
      'sales',
      'sale_items',
      'purchases',
      'purchase_items',
      'stock_transactions',
      'expenses',
      'payments',
      'rate_history',
      'main_dairy_collections',
      'main_dairy_payments',
      'bonus_settings',
      'bonus_transactions',
      'staff',
      'staff_transactions',
      'staff_attendance',
    ];

    bool hasNewData = false;

    for (var table in cloudTables) {
      try {
        final validCols = await _getTableColumns(db, table);
        if (validCols.isEmpty) continue;

        final localCountRes = await db.rawQuery('SELECT COUNT(*) as c FROM $table');
        final localCount = (localCountRes.first['c'] as num?)?.toInt() ?? 0;

        final lastPulled = await OfflineDbHelper.instance.getLastPulledAt(table);
        final currentUid = client.auth.currentUser?.id;
        const int pageSize = 1000;
        int offset = 0;
        final List<Map<String, dynamic>> incrementalRows = [];

        while (true) {
          dynamic query = client.from(table).select();
          if (currentUid != null) {
            if (validCols.contains('user_id')) {
              query = query.eq('user_id', currentUid);
            } else if (validCols.contains('owner_id')) {
              query = query.eq('owner_id', currentUid);
            }
          }
          if (localCount > 0 && lastPulled != null && lastPulled.isNotEmpty) {
            final filterCol = (table == 'app_settings' || validCols.contains('updated_at')) ? 'updated_at' : 'created_at';
            query = query.gt(filterCol, lastPulled);
          }
          final page = await query.range(offset, offset + pageSize - 1).timeout(const Duration(seconds: 30));
          if (page is List && page.isNotEmpty) {
            for (var item in page) {
              incrementalRows.add(Map<String, dynamic>.from(item as Map));
            }
            if (page.length < pageSize) break;
            offset += pageSize;
          } else {
            break;
          }
        }

        if (incrementalRows.isNotEmpty) {
          hasNewData = true;
          if (table == 'app_settings') {
            await db.delete('app_settings');
          }

          String? maxTimestamp = lastPulled;

          for (var r in incrementalRows) {
            final sanitized = sanitizeRowForSqlite(r, validCols);
            await db.insert(
              table,
              sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            final rowTs = (r['updated_at'] ?? r['created_at'])?.toString();
            if (rowTs != null && (maxTimestamp == null || rowTs.compareTo(maxTimestamp) > 0)) {
              maxTimestamp = rowTs;
            }
          }

          if (maxTimestamp != null) {
            await OfflineDbHelper.instance.setLastPulledAt(table, maxTimestamp);
          }
        }
      } catch (err) {
        debugPrint('Incremental cloud pull note for $table: $err');
      }
    }

    // ONLY notify UI if actual new entries were pulled from cloud!
    if (hasNewData) {
      syncVersion.value++;
    }
  }

  /// Pulls all tables from Supabase Cloud to Local SQLite (Full reconciliation)
  Future<void> _pullCloudUpdates() async {
    final client = Supabase.instance.client;
    final db = await OfflineDbHelper.instance.database;

    // 1. Ensure Cloud Authentication Session is active
    await _ensureCloudAuth();
    if (!await _isAccountActive()) return;

    // 2. All verified business and master tables to reconcile from cloud
    final cloudTables = [
      'rate_configs',
      'main_dairy_rate_configs',
      'app_settings',
      'roles',
      'role_permissions',
      'products',
      'farmers',
      'animals',
      'main_dairies',
      'suppliers',
      'customers',
      'employees',
      'milk_collections',
      'sales',
      'sale_items',
      'purchases',
      'purchase_items',
      'stock_transactions',
      'expenses',
      'payments',
      'rate_history',
      'main_dairy_collections',
      'main_dairy_payments',
      'bonus_settings',
      'bonus_transactions',
      'staff',
      'staff_transactions',
      'staff_attendance',
    ];

    bool hasAnyData = false;

    for (var table in cloudTables) {
      try {
        // Ensure user_id & owner_id exist in SQLite table
        try { await db.execute('ALTER TABLE $table ADD COLUMN user_id TEXT'); } catch (_) {}
        try { await db.execute('ALTER TABLE $table ADD COLUMN owner_id TEXT'); } catch (_) {}

        final validCols = await _getTableColumns(db, table);
        if (validCols.isEmpty) continue;

        final currentUid = client.auth.currentUser?.id;
        const int pageSize = 1000;
        int offset = 0;
        final List<Map<String, dynamic>> allRows = [];
        bool pullSuccess = true;

        while (true) {
          try {
            dynamic query = client.from(table).select();
            if (currentUid != null) {
              if (validCols.contains('user_id')) {
                query = query.eq('user_id', currentUid);
              } else if (validCols.contains('owner_id')) {
                query = query.eq('owner_id', currentUid);
              }
            }
            final page = await query.range(offset, offset + pageSize - 1).timeout(const Duration(seconds: 45));
            if (page is List && page.isNotEmpty) {
              for (var item in page) {
                allRows.add(Map<String, dynamic>.from(item as Map));
              }
              if (page.length < pageSize) break;
              offset += pageSize;
            } else {
              break;
            }
          } catch (e) {
            pullSuccess = false;
            debugPrint('Error during paginated pull for $table: $e');
            break;
          }
        }

        if (!pullSuccess) continue;

        hasAnyData = true;
        if (table == 'app_settings') {
          await db.delete('app_settings');
        }

        // Reconcile cloud deletions ONLY when we have successfully fetched all paginated cloud rows
        final cloudIds = allRows.map((r) => r['id']?.toString()).whereType<String>().toSet();
        final pendingQueue = await db.query(
          'sync_queue',
          columns: ['row_id'],
          where: 'table_name = ? AND status = ?',
          whereArgs: [table, 'pending'],
        );
        final pendingIds = pendingQueue.map((q) => q['row_id'].toString()).toSet();

        final localRows = await db.query(table, columns: ['id']);
        for (var loc in localRows) {
          final locId = loc['id']?.toString();
          if (locId != null && !cloudIds.contains(locId) && !pendingIds.contains(locId)) {
            await db.delete(table, where: 'id = ? OR CAST(id AS TEXT) = ?', whereArgs: [locId, locId]);
          }
        }

        if (allRows.isNotEmpty) {
          String? maxTimestamp;
          for (var r in allRows) {
            final sanitized = sanitizeRowForSqlite(r, validCols);
            await db.insert(
              table,
              sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            final rowTs = (r['updated_at'] ?? r['created_at'])?.toString();
            if (rowTs != null && (maxTimestamp == null || rowTs.compareTo(maxTimestamp) > 0)) {
              maxTimestamp = rowTs;
            }
          }
          if (maxTimestamp != null) {
            await OfflineDbHelper.instance.setLastPulledAt(table, maxTimestamp);
          }
        }
      } catch (err) {
        debugPrint('Cloud pull note for $table: $err');
      }
    }

    if (hasAnyData) {
      syncVersion.value++;
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

  /// Converts SQLite formatted row back to Supabase PostgreSQL types
  Map<String, dynamic> formatRowForSupabase(String table, Map<String, dynamic> row, [String? currentUid]) {
    final copy = Map<String, dynamic>.from(row);

    // 1. Convert integer booleans (1/0) back to real booleans (true/false)
    const boolCols = {'status', 'is_active', 'can_view', 'can_add', 'can_edit', 'can_delete', 'can_print'};
    for (var col in boolCols) {
      if (copy.containsKey(col)) {
        if (copy[col] is int) {
          copy[col] = (copy[col] == 1);
        } else if (copy[col] is String) {
          copy[col] = (copy[col] == '1' || copy[col].toLowerCase() == 'true');
        }
      }
    }

    // 2. Decode JSON strings back to Maps for json/jsonb columns
    if (copy.containsKey('bank_details')) {
      if (copy['bank_details'] is String) {
        final str = copy['bank_details'].toString().trim();
        if (str.isEmpty || str == 'null') {
          copy['bank_details'] = null;
        } else {
          try {
            copy['bank_details'] = jsonDecode(str);
          } catch (_) {
            copy['bank_details'] = null;
          }
        }
      }
    }

    // 3. Map milkType to milk_type if needed
    if (table == 'milk_collections' || table == 'main_dairy_collections') {
      if (!copy.containsKey('milk_type') || copy['milk_type'] == null) {
        copy['milk_type'] = copy['milkType'] ?? 'Cow Milk';
      }
      copy.remove('milkType');
    }

    // 4. In Supabase, milk_collections.total_amount is a PostgreSQL GENERATED ALWAYS STORED column.
    // PostgreSQL disallows inserting or updating non-DEFAULT values into generated columns.
    if (table == 'milk_collections') {
      copy.remove('total_amount');
    }

    // 5. Ensure user_id / owner_id is set to the authenticated Supabase user
    final validCols = cloudTableColumns[table];
    if (currentUid != null && currentUid.isNotEmpty) {
      if (validCols == null || validCols.contains('user_id')) {
        copy['user_id'] = currentUid;
      }
      if (validCols != null && validCols.contains('owner_id')) {
        copy['owner_id'] = currentUid;
      }
    }

    // 6. Convert empty strings to null for UUID primary & foreign keys to prevent PostgreSQL syntax errors (22P02)
    final keysToCheck = copy.keys.toList();
    for (var k in keysToCheck) {
      if ((k.endsWith('_id') || k == 'id') && copy[k] is String && (copy[k] as String).trim().isEmpty) {
        copy[k] = null;
      }
    }

    // 7. Whitelist filter: Remove any column NOT in Supabase cloud schema to avoid PGRST204 errors
    if (validCols != null) {
      copy.removeWhere((k, _) => !validCols.contains(k));
    }

    // 8. Remove any temporary join prefixes or local-only columns
    copy.removeWhere((k, _) => k.startsWith('_'));

    return copy;
  }

  /// Converts Supabase PostgreSQL row to SQLite types, dropping keys not present in SQLite columns
  Map<String, dynamic> sanitizeRowForSqlite(Map<String, dynamic> raw, Set<String> validCols) {
    final sanitized = <String, dynamic>{};
    raw.forEach((k, v) {
      if (validCols.isEmpty || validCols.contains(k)) {
        if (v is bool) {
          sanitized[k] = v ? 1 : 0;
        } else if (v is Map || v is List) {
          sanitized[k] = jsonEncode(v);
        } else {
          sanitized[k] = v;
        }
      }
    });

    // Ensure milk_type is copied to milkType if validCols contains it
    if (raw.containsKey('milk_type') && raw['milk_type'] != null) {
      sanitized['milk_type'] = raw['milk_type'];
      if (validCols.contains('milkType')) {
        sanitized['milkType'] = raw['milk_type'];
      }
    } else if (raw.containsKey('milkType') && raw['milkType'] != null) {
      sanitized['milkType'] = raw['milkType'];
      if (validCols.contains('milk_type')) {
        sanitized['milk_type'] = raw['milkType'];
      }
    }

    return sanitized;
  }
}
