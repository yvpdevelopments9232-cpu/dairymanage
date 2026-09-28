import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_db_helper.dart';
import 'app_config.dart';
import 'sync_service.dart';

class OfflineDbClient {
  static final OfflineDbClient instance = OfflineDbClient._();
  OfflineDbClient._();

  final OfflineAuthClient auth = OfflineAuthClient();

  OfflineQueryBuilder from(String table) {
    return OfflineQueryBuilder(table);
  }
}

class OfflineUser {
  final String id;
  final String? email;
  OfflineUser({required this.id, this.email});
}

class OfflineAuthClient {
  final OfflineUser? currentUser = OfflineUser(id: 'offline-admin', email: 'admin@offline.local');

  Stream<dynamic> get onAuthStateChange => const Stream.empty();

  Future<void> signInWithPassword({required String email, required String password}) async {}

  Future<void> signUp({required String email, required String password}) async {}

  Future<void> signOut() async {}
}

class OfflineQueryBuilder {
  final String table;
  OfflineQueryBuilder(this.table);

  OfflineFilterBuilder select([String columns = '*']) {
    return OfflineFilterBuilder(
      table: table,
      action: 'select',
      columns: columns,
    );
  }

  OfflineFilterBuilder insert(dynamic values) {
    return OfflineFilterBuilder(
      table: table,
      action: 'insert',
      insertValues: values,
    );
  }

  OfflineFilterBuilder update(Map<String, dynamic> values) {
    return OfflineFilterBuilder(
      table: table,
      action: 'update',
      updateValues: values,
    );
  }

  OfflineFilterBuilder delete() {
    return OfflineFilterBuilder(
      table: table,
      action: 'delete',
    );
  }

  OfflineFilterBuilder upsert(dynamic values, {String? onConflict, bool ignoreDuplicates = false, String? defaultToNull}) {
    return OfflineFilterBuilder(
      table: table,
      action: 'upsert',
      insertValues: values,
      onConflict: onConflict,
    );
  }

  // Delegation helpers so filters called directly on table without .select() also work
  OfflineFilterBuilder not(String column, String operator, dynamic value) => select().not(column, operator, value);
  OfflineFilterBuilder eq(String column, dynamic value) => select().eq(column, value);
  OfflineFilterBuilder neq(String column, dynamic value) => select().neq(column, value);
  OfflineFilterBuilder gte(String column, dynamic value) => select().gte(column, value);
  OfflineFilterBuilder lte(String column, dynamic value) => select().lte(column, value);
  OfflineFilterBuilder gt(String column, dynamic value) => select().gt(column, value);
  OfflineFilterBuilder lt(String column, dynamic value) => select().lt(column, value);
  OfflineFilterBuilder isFilter(String column, dynamic value) => select().isFilter(column, value);
  OfflineFilterBuilder or(String filterString) => select().or(filterString);
  OfflineFilterBuilder order(String column, {bool ascending = true}) => select().order(column, ascending: ascending);
  OfflineFilterBuilder limit(int count) => select().limit(count);
  OfflineFilterBuilder range(int from, int to) => select().range(from, to);
}

class _OrderRule {
  final String column;
  final bool ascending;
  _OrderRule(this.column, this.ascending);
}

class OfflineFilterBuilder implements Future<dynamic> {
  final String table;
  String action; // 'select', 'insert', 'update', 'delete', 'upsert'
  String columns;
  dynamic insertValues;
  Map<String, dynamic>? updateValues;
  final String? onConflict;

  final List<String> _whereConditions = [];
  final List<dynamic> _whereArgs = [];
  final List<_OrderRule> _orders = [];
  int? _limit;
  int? _offset;

  OfflineFilterBuilder({
    required this.table,
    required this.action,
    this.columns = '*',
    this.insertValues,
    this.updateValues,
    this.onConflict,
  });

  OfflineFilterBuilder select([String cols = '*']) {
    columns = cols;
    return this;
  }

  OfflineFilterBuilder eq(String column, dynamic value) {
    _whereConditions.add('$column = ?');
    _whereArgs.add(_convertValueForDb(value));
    return this;
  }

  OfflineFilterBuilder neq(String column, dynamic value) {
    _whereConditions.add('$column != ?');
    _whereArgs.add(_convertValueForDb(value));
    return this;
  }

  OfflineFilterBuilder gte(String column, dynamic value) {
    _whereConditions.add('$column >= ?');
    _whereArgs.add(_convertValueForDb(value));
    return this;
  }

  OfflineFilterBuilder lte(String column, dynamic value) {
    _whereConditions.add('$column <= ?');
    _whereArgs.add(_convertValueForDb(value));
    return this;
  }

  OfflineFilterBuilder gt(String column, dynamic value) {
    _whereConditions.add('$column > ?');
    _whereArgs.add(_convertValueForDb(value));
    return this;
  }

  OfflineFilterBuilder lt(String column, dynamic value) {
    _whereConditions.add('$column < ?');
    _whereArgs.add(_convertValueForDb(value));
    return this;
  }

  OfflineFilterBuilder like(String column, String pattern) {
    _whereConditions.add('$column LIKE ?');
    _whereArgs.add(pattern);
    return this;
  }

  OfflineFilterBuilder ilike(String column, String pattern) {
    _whereConditions.add('$column LIKE ?');
    _whereArgs.add(pattern);
    return this;
  }

  OfflineFilterBuilder inFilter(String column, List values) {
    if (values.isEmpty) {
      _whereConditions.add('1 = 0');
    } else {
      final placeholders = List.filled(values.length, '?').join(', ');
      _whereConditions.add('$column IN ($placeholders)');
      _whereArgs.addAll(values.map(_convertValueForDb));
    }
    return this;
  }

  OfflineFilterBuilder isFilter(String column, dynamic value) {
    if (value == null) {
      _whereConditions.add('$column IS NULL');
    } else {
      _whereConditions.add('$column IS ?');
      _whereArgs.add(_convertValueForDb(value));
    }
    return this;
  }

  OfflineFilterBuilder not(String column, String operator, dynamic value) {
    if (operator == 'is') {
      if (value == null) {
        _whereConditions.add('$column IS NOT NULL');
      } else {
        _whereConditions.add('$column IS NOT ?');
        _whereArgs.add(_convertValueForDb(value));
      }
    } else if (operator == 'eq') {
      _whereConditions.add('$column != ?');
      _whereArgs.add(_convertValueForDb(value));
    } else if (operator == 'in') {
      if (value is List && value.isNotEmpty) {
        final placeholders = List.filled(value.length, '?').join(', ');
        _whereConditions.add('$column NOT IN ($placeholders)');
        _whereArgs.addAll(value.map(_convertValueForDb));
      }
    } else {
      _whereConditions.add('NOT ($column = ?)');
      _whereArgs.add(_convertValueForDb(value));
    }
    return this;
  }

  OfflineFilterBuilder or(String filterString) {
    // E.g. "status.is.null,status.eq.true"
    final parts = filterString.split(',');
    List<String> subClauses = [];
    for (var part in parts) {
      final p = part.trim();
      if (p.contains('.is.null')) {
        final col = p.split('.is.null').first;
        subClauses.add('$col IS NULL');
      } else if (p.contains('.eq.true')) {
        final col = p.split('.eq.true').first;
        subClauses.add('$col = 1');
      } else if (p.contains('.eq.false')) {
        final col = p.split('.eq.false').first;
        subClauses.add('$col = 0');
      }
    }
    if (subClauses.isNotEmpty) {
      _whereConditions.add('(${subClauses.join(' OR ')})');
    }
    return this;
  }

  OfflineFilterBuilder order(String column, {bool ascending = true}) {
    // Clean column name if formatted like 'sales(sale_date)'
    var cleanCol = column;
    if (cleanCol.contains('(') && cleanCol.contains(')')) {
      final inside = cleanCol.substring(cleanCol.indexOf('(') + 1, cleanCol.indexOf(')'));
      cleanCol = inside;
    }
    _orders.add(_OrderRule(cleanCol, ascending));
    return this;
  }

  OfflineFilterBuilder limit(int count) {
    _limit = count;
    return this;
  }

  OfflineFilterBuilder range(int from, int to) {
    _offset = from;
    _limit = to - from + 1;
    return this;
  }

  Future<Map<String, dynamic>> single() async {
    final res = await _execute();
    if (res is List && res.isNotEmpty) {
      return res.first as Map<String, dynamic>;
    } else if (res is Map<String, dynamic>) {
      return res;
    }
    throw StateError('No rows returned for single()');
  }

  Future<Map<String, dynamic>?> maybeSingle() async {
    final res = await _execute();
    if (res is List) {
      return res.isNotEmpty ? (res.first as Map<String, dynamic>) : null;
    } else if (res is Map<String, dynamic>) {
      return res;
    }
    return null;
  }

  @override
  Stream<dynamic> asStream() => _execute().asStream();

  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object error)? test}) =>
      _execute().catchError(onError, test: test);

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) =>
      _execute().then(onValue, onError: onError);

  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) =>
      _execute().whenComplete(action);

  @override
  Future<dynamic> timeout(Duration timeLimit, {FutureOr<dynamic> Function()? onTimeout}) =>
      _execute().timeout(timeLimit, onTimeout: onTimeout);

  dynamic _convertValueForDb(dynamic val) {
    if (val is bool) return val ? 1 : 0;
    if (val is Map || val is List) return jsonEncode(val);
    return val;
  }

  Map<String, dynamic> _sanitizeRowForDb(Map<String, dynamic> raw) {
    final sanitized = <String, dynamic>{};
    raw.forEach((k, v) {
      sanitized[k] = _convertValueForDb(v);
    });
    return sanitized;
  }

  Map<String, dynamic> _formatRowFromDb(Map<String, dynamic> row) {
    final copy = Map<String, dynamic>.from(row);

    // Boolean column conversions
    const boolCols = {'status', 'is_active', 'can_view', 'can_add', 'can_edit', 'can_delete', 'can_print'};
    for (var col in boolCols) {
      if (copy.containsKey(col) && copy[col] is int) {
        copy[col] = (copy[col] == 1);
      }
    }

    // JSON column conversions
    if (copy.containsKey('bank_details') && copy['bank_details'] is String) {
      try {
        copy['bank_details'] = jsonDecode(copy['bank_details']);
      } catch (_) {}
    }

    // Ensure milk_type is always populated
    if (copy.containsKey('milk_type') || copy.containsKey('milkType')) {
      final mt = copy['milk_type'] ?? copy['milkType'] ?? 'Cow Milk';
      copy['milk_type'] = mt;
      copy['milkType'] = mt;
    }

    return copy;
  }

  Future<dynamic> _execute() async {
    final db = await OfflineDbHelper.instance.database;

    switch (action) {
      case 'insert':
      case 'upsert':
        if (insertValues is List) {
          final results = <Map<String, dynamic>>[];
          for (var item in insertValues as List) {
            final row = await _processSingleInsert(db, Map<String, dynamic>.from(item), action == 'upsert');
            results.add(row);
          }
          return results;
        } else if (insertValues is Map<String, dynamic>) {
          final row = await _processSingleInsert(db, Map<String, dynamic>.from(insertValues), action == 'upsert');
          return [row];
        }
        return [];

      case 'update':
        if (updateValues != null && updateValues!.isNotEmpty) {
          final sanitized = _sanitizeRowForDb(updateValues!);
          String? whereClause = _whereConditions.isNotEmpty ? _whereConditions.join(' AND ') : null;

          if (AppConfig.isHybridMode &&
              table != 'offline_users' &&
              table != 'sync_queue' &&
              table != 'sync_metadata') {
            try {
              final matching = await db.query(table, where: whereClause, whereArgs: _whereArgs.isNotEmpty ? _whereArgs : null);
              await db.update(table, sanitized, where: whereClause, whereArgs: _whereArgs.isNotEmpty ? _whereArgs : null);
              for (var item in matching) {
                final updatedRow = Map<String, dynamic>.from(item)..addAll(sanitized);
                await OfflineDbHelper.instance.enqueueSync(
                  tableName: table,
                  rowId: item['id'].toString(),
                  action: 'UPSERT',
                  payload: jsonEncode(updatedRow),
                );
              }
              SyncService.instance.triggerSync();
            } catch (_) {
              await db.update(table, sanitized, where: whereClause, whereArgs: _whereArgs.isNotEmpty ? _whereArgs : null);
            }
          } else {
            await db.update(table, sanitized, where: whereClause, whereArgs: _whereArgs.isNotEmpty ? _whereArgs : null);
          }
        }
        return [];

      case 'delete':
        String? whereClause = _whereConditions.isNotEmpty ? _whereConditions.join(' AND ') : null;
        List<dynamic>? whereArgs = _whereArgs.isNotEmpty ? List<dynamic>.from(_whereArgs) : null;

        if (_whereConditions.length == 1 && _whereConditions.first == 'id = ?' && whereArgs != null && whereArgs.isNotEmpty) {
          final targetId = whereArgs.first.toString();
          whereClause = '(id = ? OR CAST(id AS TEXT) = ?)';
          whereArgs = [targetId, targetId];
        }

        if (AppConfig.isHybridMode &&
            table != 'offline_users' &&
            table != 'sync_queue' &&
            table != 'sync_metadata') {
          try {
            final matching = await db.query(table, where: whereClause, whereArgs: whereArgs);
            await db.delete(table, where: whereClause, whereArgs: whereArgs);
            for (var item in matching) {
              await OfflineDbHelper.instance.enqueueSync(
                tableName: table,
                rowId: item['id'].toString(),
                action: 'DELETE',
                payload: jsonEncode({'id': item['id']}),
              );
            }
            SyncService.instance.triggerSync();
          } catch (_) {
            await db.delete(table, where: whereClause, whereArgs: whereArgs);
          }
        } else {
          await db.delete(table, where: whereClause, whereArgs: whereArgs);
        }
        return [];

      case 'select':
      default:
        return await _executeSelect(db);
    }
  }

  Future<Map<String, dynamic>> _processSingleInsert(Database db, Map<String, dynamic> rawRow, bool isUpsert) async {
    final row = Map<String, dynamic>.from(rawRow);

    // Conflict-aware upsert resolution (e.g. for staff_attendance or role_permissions)
    if (isUpsert && onConflict != null && onConflict!.isNotEmpty) {
      final conflictCols = onConflict!.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      if (conflictCols.isNotEmpty && conflictCols.every((c) => rawRow.containsKey(c) && rawRow[c] != null)) {
        final whereConditions = conflictCols.map((c) => '$c = ?').join(' AND ');
        final whereArgs = conflictCols.map((c) => _convertValueForDb(rawRow[c])).toList();
        final existing = await db.query(table, where: whereConditions, whereArgs: whereArgs, limit: 1);
        if (existing.isNotEmpty) {
          row['id'] = existing.first['id'];
          final sanitized = _sanitizeRowForDb(row);
          await db.update(table, sanitized, where: 'id = ?', whereArgs: [row['id']]);
          if (AppConfig.isHybridMode &&
              table != 'offline_users' &&
              table != 'sync_queue' &&
              table != 'sync_metadata') {
            try {
              await OfflineDbHelper.instance.enqueueSync(
                tableName: table,
                rowId: row['id'].toString(),
                action: 'UPSERT',
                payload: jsonEncode(sanitized),
              );
              SyncService.instance.triggerSync();
            } catch (_) {}
          }
          return _formatRowFromDb(row);
        }
      }
    }

    // Auto-generate UUID if missing
    if (!row.containsKey('id') || row['id'] == null || row['id'].toString().isEmpty) {
      row['id'] = OfflineDbHelper.generateId();
    }

    // Auto-increment farmer_no
    if (table == 'farmers' && (!row.containsKey('farmer_no') || row['farmer_no'] == null)) {
      final maxRes = await db.rawQuery('SELECT COALESCE(MAX(farmer_no), 0) + 1 AS next_no FROM farmers');
      row['farmer_no'] = (maxRes.first['next_no'] as num).toInt();
    }

    // Auto-increment dairy_no
    if (table == 'main_dairies' && (!row.containsKey('dairy_no') || row['dairy_no'] == null)) {
      final maxRes = await db.rawQuery('SELECT COALESCE(MAX(dairy_no), 0) + 1 AS next_no FROM main_dairies');
      row['dairy_no'] = (maxRes.first['next_no'] as num).toInt();
    }

    // Auto calculate total_amount on milk collections if not provided
    if ((table == 'milk_collections' || table == 'main_dairy_collections') &&
        (!row.containsKey('total_amount') || row['total_amount'] == null || (row['total_amount'] as num) == 0)) {
      final qty = ((row['quantity'] ?? 0) as num).toDouble();
      final rate = ((row['rate'] ?? 0) as num).toDouble();
      row['total_amount'] = qty * rate;
    }

    if (table == 'milk_collections' || table == 'main_dairy_collections') {
      final mt = row['milk_type'] ?? row['milkType'] ?? 'Cow Milk';
      row['milk_type'] = mt;
      row['milkType'] = mt;
    }

    if (AppConfig.isHybridMode &&
        table != 'offline_users' &&
        table != 'sync_queue' &&
        table != 'sync_metadata') {
      if (!row.containsKey('user_id') || row['user_id'] == null) {
        try {
          String? currentUid;
          if (Supabase.instance.client.auth.currentUser != null) {
            currentUid = Supabase.instance.client.auth.currentUser!.id;
          }
          if (currentUid == null) {
            final prefs = await SharedPreferences.getInstance();
            final activeEmail = prefs.getString(AppConfig.prefKey('active_offline_user_email')) ??
                prefs.getString(AppConfig.prefKey('logged_in_email'));
            if (activeEmail != null) {
              final users = await db.query(
                'offline_users',
                where: 'LOWER(email) = ?',
                whereArgs: [activeEmail.trim().toLowerCase()],
                limit: 1,
              );
              if (users.isNotEmpty) {
                currentUid = users.first['id']?.toString();
              }
            }
          }
          if (currentUid == null) {
            final users = await db.query('offline_users', limit: 1);
            if (users.isNotEmpty && users.first['id'] != null) {
              currentUid = users.first['id']?.toString();
            }
          }
          if (currentUid != null) {
            row['user_id'] = currentUid;
          }
        } catch (_) {}
      }
      // Only set owner_id for tables that actually track role/employee ownership
      if (table == 'roles' || table == 'role_permissions' || table == 'employees') {
        if (!row.containsKey('owner_id') || row['owner_id'] == null) {
          row['owner_id'] = row['user_id'];
        }
      } else {
        // Strip owner_id for other tables so it doesn't accidentally leak
        row.remove('owner_id');
      }
    }

    if (!row.containsKey('created_at') || row['created_at'] == null) {
      row['created_at'] = DateTime.now().toIso8601String();
    }

    final sanitized = _sanitizeRowForDb(row);
    await db.insert(
      table,
      sanitized,
      conflictAlgorithm: isUpsert ? ConflictAlgorithm.replace : ConflictAlgorithm.abort,
    );

    if (AppConfig.isHybridMode &&
        table != 'offline_users' &&
        table != 'sync_queue' &&
        table != 'sync_metadata') {
      try {
        await OfflineDbHelper.instance.enqueueSync(
          tableName: table,
          rowId: row['id'].toString(),
          action: 'UPSERT',
          payload: jsonEncode(sanitized),
        );
        SyncService.instance.triggerSync();
      } catch (_) {}
    }

    return _formatRowFromDb(row);
  }

  Future<List<Map<String, dynamic>>> _executeSelect(Database db) async {
    // 1. Check if join relations are requested
    final hasFarmersJoin = columns.contains('farmers(') || columns.contains('farmers (');
    final hasMainDairiesJoin = columns.contains('main_dairies(') || columns.contains('main_dairies (');
    final hasSuppliersJoin = columns.contains('suppliers(') || columns.contains('suppliers (');
    final hasCustomersJoin = columns.contains('customers(') || columns.contains('customers (');
    final hasProductsJoin = (columns.contains('products(') || columns.contains('products (')) && table != 'sales' && table != 'purchases';
    final hasRolesJoin = columns.contains('roles(') || columns.contains('roles (');
    final hasSalesInnerJoin = columns.contains('sales!inner(') || columns.contains('sales!inner (');
    final hasSaleItemsChild = columns.contains('sale_items(') || columns.contains('sale_items (');
    final hasPurchaseItemsChild = columns.contains('purchase_items(') || columns.contains('purchase_items (');

    // Build SELECT fields and JOINs
    StringBuffer query = StringBuffer();
    query.write('SELECT $table.* ');

    if (hasFarmersJoin) {
      query.write(', f.name AS _f_name, f.farmer_no AS _f_no, f.mobile AS _f_mobile ');
    }
    if (hasMainDairiesJoin) {
      query.write(', md.name AS _md_name, md.dairy_no AS _md_no ');
    }
    if (hasSuppliersJoin) {
      query.write(', s.name AS _s_name ');
    }
    if (hasCustomersJoin) {
      query.write(', c.name AS _c_name ');
    }
    if (hasProductsJoin) {
      query.write(', p.name AS _p_name, p.selling_rate AS _p_srate, p.purchase_rate AS _p_prate, p.category AS _p_cat ');
    }
    if (hasRolesJoin) {
      query.write(', r.name AS _r_name ');
    }
    if (hasSalesInnerJoin) {
      query.write(', sa.sale_date AS _sa_date, sa.farmer_id AS _sa_fid, sa.customer_id AS _sa_cid ');
    }

    query.write('FROM $table ');

    // Add table joins
    if (hasFarmersJoin) {
      final fKey = table == 'sales' ? 'farmer_id' : (table == 'payments' ? 'farmer_id' : 'farmer_id');
      query.write('LEFT JOIN farmers f ON $table.$fKey = f.id ');
    }
    if (hasMainDairiesJoin) {
      query.write('LEFT JOIN main_dairies md ON $table.main_dairy_id = md.id ');
    }
    if (hasSuppliersJoin) {
      query.write('LEFT JOIN suppliers s ON $table.supplier_id = s.id ');
    }
    if (hasCustomersJoin) {
      query.write('LEFT JOIN customers c ON $table.customer_id = c.id ');
    }
    if (hasProductsJoin) {
      query.write('LEFT JOIN products p ON $table.product_id = p.id ');
    }
    if (hasRolesJoin) {
      query.write('LEFT JOIN roles r ON $table.role_id = r.id ');
    }
    if (hasSalesInnerJoin) {
      query.write('INNER JOIN sales sa ON $table.sale_id = sa.id ');
    }

    // WHERE clause
    if (_whereConditions.isNotEmpty) {
      final transformedWhere = _whereConditions.map((cond) {
        if (cond.startsWith('sales.')) {
          return cond.replaceAll('sales.', 'sa.');
        }
        return cond;
      }).join(' AND ');
      query.write('WHERE $transformedWhere ');
    }

    // ORDER BY
    if (_orders.isNotEmpty) {
      final orderParts = _orders.map((o) {
        String col = o.column;
        if (col.startsWith('sales.')) col = col.replaceAll('sales.', 'sa.');
        return '$col ${o.ascending ? 'ASC' : 'DESC'}';
      }).join(', ');
      query.write('ORDER BY $orderParts ');
    }

    // LIMIT / OFFSET
    if (_limit != null) {
      query.write('LIMIT $_limit ');
    }
    if (_offset != null) {
      query.write('OFFSET $_offset ');
    }

    final rawRows = await db.rawQuery(query.toString(), _whereArgs);
    final results = <Map<String, dynamic>>[];

    for (var rawRow in rawRows) {
      final row = _formatRowFromDb(rawRow);

      if (hasFarmersJoin && (row['_f_name'] != null || row['_f_no'] != null)) {
        row['farmers'] = {
          'name': row['_f_name'],
          'farmer_no': row['_f_no'],
          'mobile': row['_f_mobile'],
        };
      }
      if (hasMainDairiesJoin && (row['_md_name'] != null || row['_md_no'] != null)) {
        row['main_dairies'] = {
          'name': row['_md_name'],
          'dairy_no': row['_md_no'],
        };
      }
      if (hasSuppliersJoin && row['_s_name'] != null) {
        row['suppliers'] = {
          'name': row['_s_name'],
        };
      }
      if (hasCustomersJoin && row['_c_name'] != null) {
        row['customers'] = {
          'name': row['_c_name'],
        };
      }
      if (hasProductsJoin && (row['_p_name'] != null || row['_p_prate'] != null)) {
        row['products'] = {
          'name': row['_p_name'],
          'selling_rate': row['_p_srate'],
          'purchase_rate': row['_p_prate'],
          'category': row['_p_cat'],
        };
      }
      if (hasRolesJoin && row['_r_name'] != null) {
        row['roles'] = {
          'name': row['_r_name'],
        };
      }
      if (hasSalesInnerJoin) {
        row['sales'] = {
          'sale_date': row['_sa_date'],
          'farmer_id': row['_sa_fid'],
          'customer_id': row['_sa_cid'],
        };
      }

      // Fetch child relations if requested (e.g. sale_items on sales, purchase_items on purchases)
      if (hasSaleItemsChild && table == 'sales') {
        final saleId = row['id'];
        final itemsRaw = await db.rawQuery('''
          SELECT si.*, p.name AS _p_name, p.selling_rate AS _p_srate, p.purchase_rate AS _p_prate
          FROM sale_items si
          LEFT JOIN products p ON si.product_id = p.id
          WHERE si.sale_id = ?
        ''', [saleId]);
        final itemsList = <Map<String, dynamic>>[];
        for (var itemRaw in itemsRaw) {
          final item = _formatRowFromDb(itemRaw);
          if (item['_p_name'] != null) {
            item['products'] = {
              'name': item['_p_name'],
              'selling_rate': item['_p_srate'],
              'purchase_rate': item['_p_prate'],
            };
          }
          itemsList.add(item);
        }
        row['sale_items'] = itemsList;
      }

      if (hasPurchaseItemsChild && table == 'purchases') {
        final purchaseId = row['id'];
        final itemsRaw = await db.rawQuery('''
          SELECT pi.*, p.name AS _p_name, p.purchase_rate AS _p_prate
          FROM purchase_items pi
          LEFT JOIN products p ON pi.product_id = p.id
          WHERE pi.purchase_id = ?
        ''', [purchaseId]);
        final itemsList = <Map<String, dynamic>>[];
        for (var itemRaw in itemsRaw) {
          final item = _formatRowFromDb(itemRaw);
          if (item['_p_name'] != null) {
            item['products'] = {
              'name': item['_p_name'],
              'purchase_rate': item['_p_prate'],
            };
          }
          itemsList.add(item);
        }
        row['purchase_items'] = itemsList;
      }

      results.add(row);
    }

    return results;
  }
}
