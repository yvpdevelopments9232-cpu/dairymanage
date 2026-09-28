import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app_config.dart';

class OfflineDbHelper {
  static final OfflineDbHelper instance = OfflineDbHelper._init();
  static Database? _database;

  OfflineDbHelper._init();

  static String generateId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant 1
    final hexChars = [
      for (int i = 0; i < 16; i++) values[i].toRadixString(16).padLeft(2, '0')
    ].join('');
    return '${hexChars.substring(0, 8)}-${hexChars.substring(8, 12)}-${hexChars.substring(12, 16)}-${hexChars.substring(16, 20)}-${hexChars.substring(20)}';
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    final dbName = AppConfig.isHybridMode ? 'dairy_hybrid.db' : 'dairy_offline.db';
    _database = await _initDB(dbName);
    return _database!;
  }

  Future<Directory> getBaseStorageDirectory() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        final exeFile = File(Platform.resolvedExecutable);
        final exeDir = exeFile.parent;
        // Verify this is an actual application folder (not test runner or dart sdk)
        if (!exeFile.path.toLowerCase().contains('flutter_tester') &&
            !exeFile.path.toLowerCase().contains('dart.exe')) {
          final testDir = Directory(p.join(exeDir.path, 'MilkDatabase'));
          if (!await testDir.exists()) {
            await testDir.create(recursive: true);
          }
          return exeDir;
        }
      } catch (e) {
        debugPrint('Exe directory resolution note: $e');
      }
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final dbFolder = Directory(p.join(docsDir.path, 'MilkDatabase'));
    if (!await dbFolder.exists()) {
      await dbFolder.create(recursive: true);
    }
    return docsDir;
  }

  Future<String> getDatabasePath() async {
    final baseDir = await getBaseStorageDirectory();
    final dbFolder = Directory(p.join(baseDir.path, 'MilkDatabase'));
    if (!await dbFolder.exists()) {
      await dbFolder.create(recursive: true);
    }
    final dbName = AppConfig.isHybridMode ? 'dairy_hybrid.db' : 'dairy_offline.db';
    final targetFile = File(p.join(dbFolder.path, dbName));

    // Zero-data-loss automatic migration: Check if previous Documents, Milkdatabase, or default databases dir has database
    if (!await targetFile.exists()) {
      final candidateDirs = <Directory>[];
      try {
        final docs = await getApplicationDocumentsDirectory();
        candidateDirs.add(Directory(p.join(docs.path, 'MilkDatabase')));
        candidateDirs.add(Directory(p.join(docs.path, 'Milkdatabase')));
        candidateDirs.add(Directory(p.join(docs.path, 'DairyManagement')));
      } catch (_) {}

      try {
        final defDatabasesPath = await getDatabasesPath();
        candidateDirs.add(Directory(defDatabasesPath));
      } catch (_) {}

      for (var cand in candidateDirs) {
        if (p.canonicalize(cand.path) == p.canonicalize(dbFolder.path)) continue;
        final candFile = File(p.join(cand.path, dbName));
        if (await candFile.exists()) {
          try {
            await candFile.copy(targetFile.path);
            debugPrint('Migrated database from ${cand.path} to ${targetFile.path} successfully.');

            // Also migrate -wal and -shm files if present
            final candWal = File('${candFile.path}-wal');
            if (await candWal.exists()) {
              await candWal.copy('${targetFile.path}-wal');
            }
            final candShm = File('${candFile.path}-shm');
            if (await candShm.exists()) {
              await candShm.copy('${targetFile.path}-shm');
            }
            break; // Stop after first successful migration
          } catch (e) {
            debugPrint('Legacy database migration note: $e');
          }
        }
      }
    }

    return targetFile.path;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = await getDatabasePath();

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL');
          await db.rawQuery('PRAGMA auto_vacuum = INCREMENTAL');
        } catch (_) {}
      },
      onOpen: (db) async {
        await _ensureTables(db);
      },
    );
  }

  Future<void> _ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        name TEXT,
        role TEXT DEFAULT 'Admin',
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        row_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT,
        created_at TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        error_message TEXT,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    try { await db.execute('ALTER TABLE sync_queue ADD COLUMN retry_count INTEGER DEFAULT 0'); } catch (_) {}

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue (status)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        table_name TEXT PRIMARY KEY,
        last_pulled_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS role_permissions (
        id TEXT PRIMARY KEY,
        role_id TEXT,
        module_name TEXT,
        can_view INTEGER DEFAULT 1,
        can_add INTEGER DEFAULT 1,
        can_edit INTEGER DEFAULT 1,
        can_delete INTEGER DEFAULT 1,
        can_print INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // Seed all standard roles if missing
    final standardRoles = [
      {'name': 'Admin', 'desc': 'Full access to all dairy modules'},
      {'name': 'Manager', 'desc': 'Management and operations access'},
      {'name': 'Collection Staff', 'desc': 'Milk collection, farmer entries'},
      {'name': 'Billing Staff', 'desc': 'Sales, purchases, payments, invoicing'},
      {'name': 'Data Entry', 'desc': 'Daily record entry'},
      {'name': 'View Only', 'desc': 'Read-only access to records and reports'},
    ];

    for (var r in standardRoles) {
      final existing = await db.query('roles', where: 'name = ?', whereArgs: [r['name']]);
      String roleId;
      if (existing.isEmpty) {
        roleId = generateId();
        await db.insert('roles', {
          'id': roleId,
          'name': r['name'],
          'description': r['desc'],
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        roleId = existing.first['id'].toString();
      }

      final permsCountRes = await db.rawQuery('SELECT COUNT(*) AS c FROM role_permissions WHERE role_id = ?', [roleId]);
      final permsCount = (permsCountRes.first['c'] as num?)?.toInt() ?? 0;
      if (permsCount == 0) {
        for (var mod in [
          'Dashboard', 'Farmers', 'Animals', 'Milk Collection', 'Sales',
          'Customers', 'Products', 'Stock', 'Suppliers', 'Purchases',
          'Payments', 'Expenses', 'Staff', 'Advances', 'Reports',
          'Rate Management', 'Settings', 'Employee Management', 'Employee Rights'
        ]) {
          bool canAdd = (r['name'] != 'View Only');
          bool canEdit = (r['name'] == 'Admin' || r['name'] == 'Manager');
          bool canDelete = (r['name'] == 'Admin');

          if (r['name'] == 'Collection Staff') {
            canAdd = (mod == 'Milk Collection' || mod == 'Farmers');
            canEdit = (mod == 'Milk Collection');
            canDelete = false;
          } else if (r['name'] == 'Billing Staff') {
            canAdd = (mod == 'Sales' || mod == 'Purchases' || mod == 'Payments');
            canEdit = (mod == 'Sales');
            canDelete = false;
          } else if (r['name'] == 'Data Entry') {
            canAdd = (mod == 'Milk Collection' || mod == 'Sales' || mod == 'Farmers');
            canEdit = false;
            canDelete = false;
          }

          await db.insert('role_permissions', {
            'id': generateId(),
            'role_id': roleId,
            'module_name': mod,
            'can_view': 1,
            'can_add': canAdd ? 1 : 0,
            'can_edit': canEdit ? 1 : 0,
            'can_delete': canDelete ? 1 : 0,
            'can_print': 1,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    }

    // Bonus Management Tables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bonus_settings (
        id TEXT PRIMARY KEY,
        cow_rate REAL DEFAULT 0.40,
        buffalo_rate REAL DEFAULT 0.50,
        updated_at TEXT,
        user_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bonus_transactions (
        id TEXT PRIMARY KEY,
        farmer_id TEXT NOT NULL,
        farmer_name TEXT,
        farmer_no TEXT,
        animal_type TEXT,
        from_date TEXT NOT NULL,
        to_date TEXT NOT NULL,
        milk_quantity REAL NOT NULL,
        bonus_rate REAL NOT NULL,
        total_bonus REAL NOT NULL,
        previous_paid REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL,
        total_paid REAL NOT NULL,
        remaining_bonus REAL NOT NULL,
        payment_date TEXT NOT NULL,
        payment_mode TEXT NOT NULL,
        transaction_number TEXT,
        remarks TEXT,
        created_at TEXT,
        user_id TEXT
      )
    ''');

    final bonusSetCheck = await db.rawQuery('SELECT COUNT(*) AS c FROM bonus_settings');
    if ((bonusSetCheck.first['c'] as num?)?.toInt() == 0) {
      await db.insert('bonus_settings', {
        'id': 'default_settings',
        'cow_rate': 0.40,
        'buffalo_rate': 0.50,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    // Ensure user_id and owner_id columns exist across tables for cloud compatibility
    const tablesWithUser = [
      'farmers', 'animals', 'milk_collections', 'rate_configs', 'main_dairies',
      'main_dairy_rate_configs', 'main_dairy_collections', 'customers', 'products',
      'sales', 'sale_items', 'stock_transactions', 'suppliers', 'purchases',
      'purchase_items', 'expenses', 'payments', 'staff', 'staff_transactions',
      'staff_attendance', 'employees', 'roles', 'role_permissions', 'audit_logs', 'app_settings',
      'bonus_settings', 'bonus_transactions'
    ];
    for (var t in tablesWithUser) {
      try { await db.execute('ALTER TABLE $t ADD COLUMN user_id TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE $t ADD COLUMN owner_id TEXT'); } catch (_) {}
    }

    try {
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_att_unique ON staff_attendance (staff_id, attendance_date)');
    } catch (_) {}

    // Ensure milk_type and milkType columns exist and stay in sync
    try { await db.execute('ALTER TABLE milk_collections ADD COLUMN milk_type TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE milk_collections ADD COLUMN milkType TEXT'); } catch (_) {}
    try { await db.execute('UPDATE milk_collections SET milk_type = milkType WHERE milk_type IS NULL AND milkType IS NOT NULL'); } catch (_) {}
    try { await db.execute('UPDATE milk_collections SET milkType = milk_type WHERE milkType IS NULL AND milk_type IS NOT NULL'); } catch (_) {}
    try { await db.execute("UPDATE milk_collections SET milk_type = 'Cow Milk' WHERE milk_type IS NULL"); } catch (_) {}
    try { await db.execute("UPDATE milk_collections SET milkType = 'Cow Milk' WHERE milkType IS NULL"); } catch (_) {}

    try { await db.execute('ALTER TABLE main_dairy_collections ADD COLUMN milk_type TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE main_dairy_collections ADD COLUMN milkType TEXT'); } catch (_) {}
    try { await db.execute('UPDATE main_dairy_collections SET milk_type = milkType WHERE milk_type IS NULL AND milkType IS NOT NULL'); } catch (_) {}
    try { await db.execute('UPDATE main_dairy_collections SET milkType = milk_type WHERE milkType IS NULL AND milk_type IS NOT NULL'); } catch (_) {}

    // Stock transaction deduplication and unique constraint protection
    try {
      await db.execute('''
        DELETE FROM stock_transactions 
        WHERE rowid NOT IN (
          SELECT MIN(rowid) 
          FROM stock_transactions 
          GROUP BY reference_id, product_id, trans_type
        )
      ''');
    } catch (_) {}

    try {
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_stock_trans_unique 
        ON stock_transactions (reference_id, product_id, trans_type)
      ''');
    } catch (_) {}

    // Ensure idempotent triggers for stock management
    try {
      await db.execute('DROP TRIGGER IF EXISTS trg_sale_stock');
      await db.execute('DROP TRIGGER IF EXISTS trg_purchase_stock');
      await db.execute('DROP TRIGGER IF EXISTS trg_sale_stock_delete');
      await db.execute('DROP TRIGGER IF EXISTS trg_purchase_stock_delete');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_sale_stock AFTER INSERT ON sale_items
        BEGIN
          UPDATE products 
          SET current_stock = current_stock - NEW.quantity 
          WHERE id = NEW.product_id
            AND NOT EXISTS (
              SELECT 1 FROM stock_transactions 
              WHERE reference_id = NEW.sale_id AND product_id = NEW.product_id AND trans_type = 'OUT'
            );

          INSERT OR IGNORE INTO stock_transactions (
            id, product_id, transaction_date, trans_type, quantity, reference_id, reference_type, created_at
          )
          SELECT 
            'stk_sale_' || NEW.id,
            NEW.product_id,
            date('now'),
            'OUT',
            NEW.quantity,
            NEW.sale_id,
            'Sale',
            datetime('now')
          WHERE NOT EXISTS (
            SELECT 1 FROM stock_transactions 
            WHERE reference_id = NEW.sale_id AND product_id = NEW.product_id AND trans_type = 'OUT'
          );
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_purchase_stock AFTER INSERT ON purchase_items
        BEGIN
          UPDATE products 
          SET current_stock = current_stock + NEW.quantity 
          WHERE id = NEW.product_id
            AND NOT EXISTS (
              SELECT 1 FROM stock_transactions 
              WHERE reference_id = NEW.purchase_id AND product_id = NEW.product_id AND trans_type = 'IN'
            );

          INSERT OR IGNORE INTO stock_transactions (
            id, product_id, transaction_date, trans_type, quantity, reference_id, reference_type, created_at
          )
          SELECT 
            'stk_pur_' || NEW.id,
            NEW.product_id,
            date('now'),
            'IN',
            NEW.quantity,
            NEW.purchase_id,
            'Purchase',
            datetime('now')
          WHERE NOT EXISTS (
            SELECT 1 FROM stock_transactions 
            WHERE reference_id = NEW.purchase_id AND product_id = NEW.product_id AND trans_type = 'IN'
          );
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_sale_stock_delete AFTER DELETE ON sale_items
        BEGIN
          UPDATE products SET current_stock = current_stock + OLD.quantity WHERE id = OLD.product_id;
          DELETE FROM stock_transactions WHERE reference_id = OLD.sale_id AND product_id = OLD.product_id;
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_purchase_stock_delete AFTER DELETE ON purchase_items
        BEGIN
          UPDATE products SET current_stock = current_stock - OLD.quantity WHERE id = OLD.product_id;
          DELETE FROM stock_transactions WHERE reference_id = OLD.purchase_id AND product_id = OLD.product_id;
        END;
      ''');
    } catch (_) {}
  }

  /// Creates all standard schema tables on any given SQLite Database instance
  Future<void> createAllTables(Database db) async {
    await _ensureTables(db);
    await _createDB(db, 1);
  }

  Future<void> _createDB(Database db, int version) async {
    await _ensureTables(db);
    // 1. Farmers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS farmers (
        id TEXT PRIMARY KEY,
        farmer_no INTEGER,
        name TEXT NOT NULL,
        mobile TEXT,
        address TEXT,
        village TEXT,
        bank_details TEXT,
        opening_balance REAL DEFAULT 0,
        current_balance REAL DEFAULT 0,
        status INTEGER DEFAULT 1,
        notes TEXT,
        created_at TEXT
      )
    ''');

    // 2. Animals
    await db.execute('''
      CREATE TABLE IF NOT EXISTS animals (
        id TEXT PRIMARY KEY,
        farmer_id TEXT,
        animal_type TEXT,
        breed TEXT,
        name TEXT,
        tag_no TEXT,
        age INTEGER,
        milk_capacity REAL,
        status INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // 3. Milk Collections
    await db.execute('''
      CREATE TABLE IF NOT EXISTS milk_collections (
        id TEXT PRIMARY KEY,
        collection_date TEXT,
        collection_time TEXT,
        shift TEXT,
        farmer_id TEXT,
        animal_id TEXT,
        milk_type TEXT,
        quantity REAL DEFAULT 0,
        fat REAL DEFAULT 0,
        snf REAL DEFAULT 0,
        rate REAL DEFAULT 0,
        total_amount REAL DEFAULT 0,
        payment_status TEXT DEFAULT 'Pending',
        remarks TEXT,
        created_at TEXT
      )
    ''');

    // 4. Rate Configurations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rate_configs (
        id TEXT PRIMARY KEY,
        animal_type TEXT,
        rate_type TEXT DEFAULT 'Increase',
        base_fat REAL DEFAULT 0,
        base_snf REAL DEFAULT 0,
        base_rate REAL DEFAULT 0,
        fat_rate REAL DEFAULT 0,
        snf_rate REAL DEFAULT 0,
        fat_point REAL DEFAULT 0.1,
        snf_point REAL DEFAULT 0.1,
        fat_range_from REAL DEFAULT 0,
        fat_range_to REAL DEFAULT 15.0,
        snf_range_from REAL DEFAULT 0,
        snf_range_to REAL DEFAULT 15.0,
        effective_date TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // 5. Main Dairies
    await db.execute('''
      CREATE TABLE IF NOT EXISTS main_dairies (
        id TEXT PRIMARY KEY,
        dairy_no INTEGER,
        name TEXT NOT NULL,
        contact_person TEXT,
        mobile TEXT,
        email TEXT,
        address TEXT,
        village TEXT,
        animal_type TEXT,
        opening_balance REAL DEFAULT 0,
        current_balance REAL DEFAULT 0,
        status INTEGER DEFAULT 1,
        notes TEXT,
        created_at TEXT
      )
    ''');

    // 6. Main Dairy Rate Configurations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS main_dairy_rate_configs (
        id TEXT PRIMARY KEY,
        dairy_id TEXT,
        animal_type TEXT,
        rate_type TEXT DEFAULT 'Increase',
        base_fat REAL DEFAULT 0,
        base_snf REAL DEFAULT 0,
        base_rate REAL DEFAULT 0,
        fat_rate REAL DEFAULT 0,
        snf_rate REAL DEFAULT 0,
        fat_point REAL DEFAULT 0.1,
        snf_point REAL DEFAULT 0.1,
        fat_range_from REAL DEFAULT 0,
        fat_range_to REAL DEFAULT 15.0,
        snf_range_from REAL DEFAULT 0,
        snf_range_to REAL DEFAULT 15.0,
        effective_date TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // 7. Main Dairy Collections
    await db.execute('''
      CREATE TABLE IF NOT EXISTS main_dairy_collections (
        id TEXT PRIMARY KEY,
        main_dairy_id TEXT,
        collection_date TEXT,
        shift TEXT,
        milk_type TEXT,
        quantity REAL DEFAULT 0,
        fat REAL DEFAULT 0,
        snf REAL DEFAULT 0,
        rate REAL DEFAULT 0,
        total_amount REAL DEFAULT 0,
        payment_status TEXT DEFAULT 'Pending',
        remarks TEXT,
        created_at TEXT
      )
    ''');

    // 8. Main Dairy Payments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS main_dairy_payments (
        id TEXT PRIMARY KEY,
        main_dairy_id TEXT,
        payment_date TEXT,
        amount REAL DEFAULT 0,
        payment_mode TEXT DEFAULT 'Bank Transfer',
        reference_no TEXT,
        remarks TEXT,
        created_at TEXT
      )
    ''');

    // 9. Customers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        mobile TEXT,
        address TEXT,
        customer_type TEXT DEFAULT 'Regular',
        opening_balance REAL DEFAULT 0,
        current_balance REAL DEFAULT 0,
        credit_limit REAL DEFAULT 0,
        status INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // 10. Products
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT,
        unit TEXT DEFAULT 'Litres',
        purchase_rate REAL DEFAULT 0,
        selling_rate REAL DEFAULT 0,
        opening_stock REAL DEFAULT 0,
        current_stock REAL DEFAULT 0,
        min_stock REAL DEFAULT 0,
        tax_percent REAL DEFAULT 0,
        status INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // 11. Sales
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id TEXT PRIMARY KEY,
        invoice_no TEXT,
        sale_date TEXT,
        customer_id TEXT,
        farmer_id TEXT,
        subtotal REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        grand_total REAL DEFAULT 0,
        paid_amount REAL DEFAULT 0,
        balance REAL DEFAULT 0,
        payment_mode TEXT DEFAULT 'Cash',
        created_at TEXT
      )
    ''');

    // 12. Sale Items
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT,
        product_id TEXT,
        quantity REAL DEFAULT 0,
        unit TEXT,
        rate REAL DEFAULT 0,
        total_amount REAL DEFAULT 0,
        created_at TEXT
      )
    ''');

    // 13. Stock Transactions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transactions (
        id TEXT PRIMARY KEY,
        product_id TEXT,
        transaction_date TEXT,
        trans_type TEXT,
        quantity REAL DEFAULT 0,
        reference_id TEXT,
        reference_type TEXT,
        created_at TEXT
      )
    ''');

    // 14. Suppliers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        mobile TEXT,
        address TEXT,
        product_type TEXT,
        opening_balance REAL DEFAULT 0,
        current_balance REAL DEFAULT 0,
        payment_terms TEXT,
        status INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // 15. Purchases
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id TEXT PRIMARY KEY,
        invoice_no TEXT,
        purchase_date TEXT,
        supplier_id TEXT,
        subtotal REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        grand_total REAL DEFAULT 0,
        paid_amount REAL DEFAULT 0,
        balance REAL DEFAULT 0,
        vehicle_no TEXT,
        created_at TEXT
      )
    ''');

    // 16. Purchase Items
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT,
        product_id TEXT,
        quantity REAL DEFAULT 0,
        purchase_rate REAL DEFAULT 0,
        created_at TEXT
      )
    ''');

    // 17. Expenses
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        expense_date TEXT,
        category TEXT,
        description TEXT,
        amount REAL DEFAULT 0,
        payment_mode TEXT DEFAULT 'Cash',
        remarks TEXT,
        created_at TEXT
      )
    ''');

    // 18. Payments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        payment_date TEXT,
        party_type TEXT,
        farmer_id TEXT,
        customer_id TEXT,
        supplier_id TEXT,
        payment_type TEXT,
        amount REAL DEFAULT 0,
        payment_mode TEXT DEFAULT 'Cash',
        reference_no TEXT,
        remarks TEXT,
        created_at TEXT
      )
    ''');

    // 19. Staff
    await db.execute('''
      CREATE TABLE IF NOT EXISTS staff (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        role TEXT,
        salary_amount REAL DEFAULT 0,
        salary_type TEXT DEFAULT 'Monthly',
        balance REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // 20. Staff Transactions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS staff_transactions (
        id TEXT PRIMARY KEY,
        staff_id TEXT,
        transaction_date TEXT,
        type TEXT,
        amount REAL DEFAULT 0,
        remarks TEXT,
        created_at TEXT
      )
    ''');

    // 21. Staff Attendance
    await db.execute('''
      CREATE TABLE IF NOT EXISTS staff_attendance (
        id TEXT PRIMARY KEY,
        staff_id TEXT,
        attendance_date TEXT,
        status TEXT,
        created_at TEXT
      )
    ''');

    // 22. App Settings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        id TEXT PRIMARY KEY,
        dairy_name TEXT DEFAULT 'My Dairy',
        owner_name TEXT,
        mobile TEXT,
        address TEXT,
        gst_no TEXT,
        receipt_header TEXT,
        receipt_footer TEXT,
        logo_url TEXT,
        created_at TEXT
      )
    ''');

    // 23. Employees
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        mobile TEXT,
        username TEXT,
        pin TEXT,
        role_id TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // 24. Roles
    await db.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT
      )
    ''');

    // 25. Role Permissions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS role_permissions (
        id TEXT PRIMARY KEY,
        role_id TEXT,
        module_name TEXT,
        can_view INTEGER DEFAULT 1,
        can_add INTEGER DEFAULT 1,
        can_edit INTEGER DEFAULT 1,
        can_delete INTEGER DEFAULT 1,
        can_print INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // 26. Audit Logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        user_type TEXT,
        user_name TEXT,
        action TEXT,
        details TEXT,
        created_at TEXT
      )
    ''');

    // Initial default seed rows
    await db.insert('app_settings', {
      'id': '1',
      'dairy_name': 'My Local Dairy',
      'created_at': DateTime.now().toIso8601String(),
    });

    final adminRoleId = generateId();
    await db.insert('roles', {
      'id': adminRoleId,
      'name': 'Admin',
      'description': 'Full access to all dairy modules',
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('employees', {
      'id': generateId(),
      'name': 'Administrator',
      'username': 'admin',
      'pin': '1234',
      'role_id': adminRoleId,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Lossless SQLite Compaction & Space Reclamation
  /// Flushes uncommitted WAL pages and executes VACUUM to defragment and physically shrink .db file
  Future<Map<String, int>> compactDatabase() async {
    int beforeBytes = 0;
    int afterBytes = 0;
    try {
      final path = await getDatabasePath();
      final file = File(path);
      if (await file.exists()) {
        beforeBytes = await file.length();
      }

      final db = await database;
      // 1. Truncate WAL file back into main DB file
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      // 2. Repack all tables and indices into minimal contiguous storage (100% lossless)
      await db.execute('VACUUM');
      // 3. Incremental vacuum if free pages remain
      try {
        await db.rawQuery('PRAGMA incremental_vacuum');
      } catch (_) {}

      if (await file.exists()) {
        afterBytes = await file.length();
      }
      debugPrint('Database compacted: ${beforeBytes ~/ 1024} KB -> ${afterBytes ~/ 1024} KB');
    } catch (e) {
      debugPrint('Database compaction notice: $e');
    }
    return {'before': beforeBytes, 'after': afterBytes};
  }

  /// Create a backup copy of the SQLite database
  Future<String> backupDatabase([String? destinationPath]) async {
    // Losslessly compact database prior to backup
    await compactDatabase();

    final dbFile = File(await getDatabasePath());
    if (!await dbFile.exists()) {
      throw Exception('Database file does not exist to backup.');
    }

    String target;
    if (destinationPath != null && destinationPath.isNotEmpty) {
      target = destinationPath;
    } else {
      final baseDir = await getBaseStorageDirectory();
      final now = DateTime.now();
      final timeStamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      target = p.join(baseDir.path, 'Milkdatabase', 'Backups', 'dairy_backup_$timeStamp.db');
    }

    final parentDir = Directory(p.dirname(target));
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    await dbFile.copy(target);
    return target;
  }

  /// Restore database safely with rollback safety copy
  Future<void> restoreDatabaseSafely(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source backup file does not exist: $sourcePath');
    }

    final dbPath = await getDatabasePath();
    final dbFile = File(dbPath);
    String? rollbackBackupPath;

    // 1. Create a safety backup copy of the current database if it exists
    if (await dbFile.exists()) {
      rollbackBackupPath = '$dbPath.bak';
      await dbFile.copy(rollbackBackupPath);
    }

    // 2. Close active SQLite connection
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }

    try {
      // 3. Overwrite current database with source backup file
      await sourceFile.copy(dbPath);

      // 4. Re-open database with proper name (hybrid or offline)
      final dbName = AppConfig.isHybridMode ? 'dairy_hybrid.db' : 'dairy_offline.db';
      _database = await _initDB(dbName);

      // 5. Verify integrity
      final check = await _database!.rawQuery('PRAGMA integrity_check');
      if (check.isEmpty || check.first.values.first != 'ok') {
        throw Exception('Restored database integrity check failed.');
      }

      // 6. If in Hybrid mode, enqueue all restored data into sync_queue for cloud sync
      if (AppConfig.isHybridMode) {
        await enqueueAllLocalDataForSync(_database!);
      }

      // 7. Success - delete safety rollback copy
      if (rollbackBackupPath != null) {
        final bakFile = File(rollbackBackupPath);
        if (await bakFile.exists()) {
          await bakFile.delete();
        }
      }
    } catch (e) {
      // Rollback to original database on error
      if (rollbackBackupPath != null && await File(rollbackBackupPath).exists()) {
        try {
          if (_database != null && _database!.isOpen) {
            await _database!.close();
            _database = null;
          }
          await File(rollbackBackupPath).copy(dbPath);
          final dbName = AppConfig.isHybridMode ? 'dairy_hybrid.db' : 'dairy_offline.db';
          _database = await _initDB(dbName);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Re-queues all local table records into sync_queue so they are pushed to Supabase Cloud
  Future<void> enqueueAllLocalDataForSync(Database db) async {
    final tables = [
      'rate_configs', 'main_dairy_rate_configs', 'app_settings', 'roles',
      'role_permissions', 'products', 'farmers', 'animals', 'main_dairies',
      'suppliers', 'customers', 'employees', 'milk_collections', 'sales',
      'sale_items', 'purchases', 'purchase_items', 'expenses', 'payments',
      'rate_history', 'main_dairy_collections', 'main_dairy_payments',
    ];
    for (var t in tables) {
      try {
        final rows = await db.query(t);
        for (var r in rows) {
          final id = r['id']?.toString();
          if (id != null && id.isNotEmpty) {
            await enqueueSync(
              tableName: t,
              rowId: id,
              action: 'UPSERT',
              payload: jsonEncode(r),
            );
          }
        }
      } catch (_) {}
    }
  }

  /// Legacy restore database helper
  Future<void> restoreDatabase(String sourcePath) async {
    await restoreDatabaseSafely(sourcePath);
  }

  // ==========================================
  // SYNC QUEUE HELPERS (Hybrid Edition)
  // ==========================================

  Future<void> enqueueSync({
    required String tableName,
    required String rowId,
    required String action,
    required String payload,
  }) async {
    final db = await database;
    await db.insert('sync_queue', {
      'table_name': tableName,
      'row_id': rowId,
      'action': action,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final res = await db.rawQuery("SELECT COUNT(*) AS c FROM sync_queue WHERE status = 'pending' OR (status = 'failed' AND (retry_count IS NULL OR retry_count < 5))");
    return (res.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems({int limit = 500}) async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: "status = 'pending' OR (status = 'failed' AND (retry_count IS NULL OR retry_count < 5))",
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<void> markSyncItemCompleted(int id) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {
        'status': 'synced',
        'error_message': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSyncItemsBatchCompleted(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'sync_queue',
        {
          'status': 'synced',
          'error_message': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markSyncItemFailed(int id, String error) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE sync_queue 
      SET status = 'failed', 
          error_message = ?, 
          retry_count = COALESCE(retry_count, 0) + 1 
      WHERE id = ?
    ''', [error, id]);
  }

  Future<void> markSyncItemsBatchFailed(List<int> ids, String error) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.rawUpdate('''
        UPDATE sync_queue 
        SET status = 'failed', 
            error_message = ?, 
            retry_count = COALESCE(retry_count, 0) + 1 
        WHERE id = ?
      ''', [error, id]);
    }
    await batch.commit(noResult: true);
  }

  Future<String?> getLastPulledAt(String table) async {
    final db = await database;
    final res = await db.query(
      'sync_metadata',
      columns: ['last_pulled_at'],
      where: 'table_name = ?',
      whereArgs: [table],
    );
    if (res.isNotEmpty) {
      return res.first['last_pulled_at'] as String?;
    }
    return null;
  }

  Future<void> setLastPulledAt(String table, String timestamp) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'table_name': table,
        'last_pulled_at': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
