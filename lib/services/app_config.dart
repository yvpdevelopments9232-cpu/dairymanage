class AppConfig {
  /// Set to true when running in local-first database mode (Offline or Hybrid).
  static bool isOfflineMode = false;

  /// Set to true when running the Hybrid Auto-Sync Edition.
  static bool isHybridMode = false;

  /// Human-friendly edition name
  static String get editionName {
    if (isHybridMode) return 'Hybrid Auto-Sync';
    if (isOfflineMode) return 'Offline Standalone';
    return 'Cloud Online';
  }

  /// Prefix for shared preferences keys to isolate sessions between editions
  static String get sessionPrefix {
    if (isHybridMode) return 'hybrid_';
    if (isOfflineMode) return 'offline_';
    return '';
  }

  /// Returns an edition-isolated key for SharedPreferences
  static String prefKey(String key) => '$sessionPrefix$key';
}
