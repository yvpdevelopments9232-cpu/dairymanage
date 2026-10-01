import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  /// Set to true when running in local-first database mode (Offline or Hybrid).
  static bool isOfflineMode = false;

  /// Set to true when running the Hybrid Auto-Sync Edition.
  static bool isHybridMode = false;

  /// Human-friendly edition name
  static String get editionName {
    if (isHybridMode) return 'Hybrid (Cloud + Offline)';
    if (isOfflineMode) return '100% Offline (Standalone)';
    return '100% Cloud Online';
  }

  /// Platform name
  static String get platformName {
    if (kIsWeb) return 'Web Portal';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows Desktop';
    if (Platform.isIOS) return 'Apple iOS';
    if (Platform.isMacOS) return 'Apple macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Cross-Platform';
  }

  /// Full descriptive title for diagnostics and logs
  static String get fullEditionDescription {
    return '$platformName - $editionName';
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

