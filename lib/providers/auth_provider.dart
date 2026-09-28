import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../services/app_config.dart';
import '../services/offline_db_client.dart';
import '../services/offline_db_helper.dart';
import '../services/sync_service.dart';
import '../main.dart';

// Provides the Supabase Client in online mode, or OfflineDbClient in offline mode
final supabaseClientProvider = Provider<dynamic>((ref) {
  if (AppConfig.isOfflineMode) {
    return OfflineDbClient.instance;
  }
  return Supabase.instance.client;
});

// Provides the AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return AuthRepository(supabase);
});

// Provides the current user authentication state (User? or null)
final authStateProvider = StreamProvider<dynamic>((ref) {
  if (AppConfig.isOfflineMode) {
    return const Stream.empty();
  }
  final supabase = ref.read(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
});

class AuthRepository {
  final dynamic _supabase;

  AuthRepository(this._supabase);

  // Login with Email and Password
  Future<void> login(String email, String password) async {
    final cleanEmail = email.trim();
    final pwd = password.trim();

    // 1. In Hybrid Mode: attempt Supabase Cloud first if online
    if (AppConfig.isHybridMode) {
      try {
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: cleanEmail,
          password: pwd,
        ).timeout(const Duration(seconds: 10));

        if (res.user != null) {
          final db = await OfflineDbHelper.instance.database;
          final existing = await db.query(
            'offline_users',
            where: 'LOWER(email) = ?',
            whereArgs: [cleanEmail.toLowerCase()],
          );

          if (existing.isEmpty) {
            await db.insert('offline_users', {
              'id': res.user!.id,
              'email': cleanEmail.toLowerCase(),
              'password': pwd,
              'name': res.user!.userMetadata?['name'] ?? 'Admin',
              'role': 'Admin',
              'created_at': DateTime.now().toIso8601String(),
            });
          } else {
            await db.update(
              'offline_users',
              {'password': pwd},
              where: 'LOWER(email) = ?',
              whereArgs: [cleanEmail.toLowerCase()],
            );
          }

          await prefs.setBool(AppConfig.prefKey('is_logged_in'), true);
          await prefs.setString(AppConfig.prefKey('logged_in_email'), cleanEmail.toLowerCase());
          await prefs.setString(AppConfig.prefKey('active_offline_user_email'), cleanEmail.toLowerCase());
          await prefs.setString(AppConfig.prefKey('admin_pin'), pwd);

          // Await full pull from Supabase Cloud to populate local SQLite before navigating
          try {
            await SyncService.instance.syncAll(forceFull: true);
          } catch (_) {}
          return;
        }
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('invalid login credentials') ||
            errStr.contains('invalid username or password') ||
            errStr.contains('wrong password') ||
            errStr.contains('email not confirmed')) {
          throw Exception('Invalid email or password');
        }
        // If network error (offline, timeout), continue down to check local SQLite database!
      }
    }

    // 2. Pure Offline Mode or Hybrid Fallback (when offline)
    if (AppConfig.isOfflineMode || AppConfig.isHybridMode) {
      final input = cleanEmail.toLowerCase();
      final db = await OfflineDbHelper.instance.database;

      // 1. Check in offline_users table
      final userRows = await db.query(
        'offline_users',
        where: 'LOWER(email) = ?',
        whereArgs: [input],
      );

      if (userRows.isNotEmpty) {
        final user = userRows.first;
        if (user['password'] == pwd) {
          await prefs.setBool(AppConfig.prefKey('is_logged_in'), true);
          await prefs.setString(AppConfig.prefKey('logged_in_email'), input);
          await prefs.setString(AppConfig.prefKey('active_offline_user_email'), input);
          await prefs.setString(AppConfig.prefKey('admin_pin'), pwd);
          return;
        } else {
          throw Exception('Invalid username or password');
        }
      }

      // 2. Check in employees table
      final empRows = await db.query(
        'employees',
        where: 'LOWER(username) = ? OR LOWER(name) = ?',
        whereArgs: [input, input],
      );
      if (empRows.isNotEmpty) {
        final emp = empRows.first;
        if (emp['pin'] == pwd) {
          await prefs.setBool(AppConfig.prefKey('is_logged_in'), true);
          await prefs.setString(AppConfig.prefKey('active_offline_user_email'), input);
          return;
        }
      }

      throw Exception('Invalid username or password');
    }

    // 3. Pure Online Cloud Mode
    await _supabase.auth.signInWithPassword(
      email: cleanEmail,
      password: pwd,
    );
  }

  // Sign up with Email and Password
  Future<void> signUp(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPwd = password.trim();

    if (AppConfig.isHybridMode) {
      String newUserId = OfflineDbHelper.generateId();
      try {
        final res = await Supabase.instance.client.auth.signUp(
          email: cleanEmail,
          password: cleanPwd,
        ).timeout(const Duration(seconds: 10));
        if (res.user != null) {
          newUserId = res.user!.id;
        }
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('already registered') || errStr.contains('already exists')) {
          throw Exception('User already registered in cloud. Please log in.');
        }
      }

      final db = await OfflineDbHelper.instance.database;
      await db.insert('offline_users', {
        'id': newUserId,
        'email': cleanEmail,
        'password': cleanPwd,
        'name': cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail,
        'role': 'Admin',
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await prefs.setBool(AppConfig.prefKey('is_logged_in'), true);
      await prefs.setString(AppConfig.prefKey('logged_in_email'), cleanEmail);
      await prefs.setString(AppConfig.prefKey('active_offline_user_email'), cleanEmail);
      await prefs.setString(AppConfig.prefKey('admin_pin'), cleanPwd);
      return;
    }

    if (AppConfig.isOfflineMode) {
      final db = await OfflineDbHelper.instance.database;

      final existing = await db.query(
        'offline_users',
        where: 'LOWER(email) = ?',
        whereArgs: [cleanEmail],
      );

      if (existing.isNotEmpty) {
        throw Exception('User already registered. Please log in.');
      }

      await db.insert('offline_users', {
        'id': OfflineDbHelper.generateId(),
        'email': cleanEmail,
        'password': cleanPwd,
        'name': cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail,
        'role': 'Admin',
        'created_at': DateTime.now().toIso8601String(),
      });

      await prefs.setString(AppConfig.prefKey('active_offline_user_email'), cleanEmail);
      await prefs.setString(AppConfig.prefKey('admin_pin'), cleanPwd);
      return;
    }

    await _supabase.auth.signUp(
      email: cleanEmail,
      password: cleanPwd,
    );
  }

  // Log out the user
  Future<void> logOut() async {
    if (AppConfig.isOfflineMode) {
      await prefs.remove(AppConfig.prefKey('active_offline_user_email'));
      return;
    }
    await _supabase.auth.signOut();
  }
}
