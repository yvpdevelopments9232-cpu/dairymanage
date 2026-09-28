import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import 'offline_db_client.dart';

class AppDb {
  /// Returns either the local SQLite [OfflineDbClient] or the Cloud [SupabaseClient]
  static dynamic get client {
    if (AppConfig.isOfflineMode) {
      return OfflineDbClient.instance;
    }
    return Supabase.instance.client;
  }

  /// Convenience accessor for from(table)
  static dynamic from(String table) => client.from(table);
}
