# Dairy Management Application

A cross-platform Dairy Management Solution built with Flutter and Dart, supporting Windows, Android, macOS, and iOS with Supabase PostgreSQL cloud syncing and SQLite offline caching.

---

## 🚀 Available Editions

1. **Online Edition** (`lib/main.dart`): Direct real-time cloud sync with Supabase PostgreSQL.
2. **Hybrid Edition** (`lib/main_hybrid.dart`): Offline-first SQLite local caching with automatic background synchronization to Supabase cloud.
3. **Offline Edition** (`lib/main_offline.dart`): 100% standalone local SQLite database requiring no internet connection.

---

## 🍎 iOS & macOS Automated Builds (GitHub Actions)

This repository includes an automated GitHub Actions CI/CD workflow located at [`.github/workflows/build_apple.yml`](.github/workflows/build_apple.yml).

### What It Builds:
1. **iOS (`.ipa`)**:
   - `DairyManagement_hybrid.ipa`
   - `DairyManagement_offline.ipa`
   - `DairyManagement_online.ipa`
   *(Packaged Payload ready for sideloading with AltStore, Sideloadly, TrollStore, or enterprise/MDM signing)*

2. **macOS (`.zip` containing `.app`)**:
   - `DairyManagement_hybrid_macOS.zip`
   - `DairyManagement_offline_macOS.zip`
   - `DairyManagement_online_macOS.zip`
   *(Ad-hoc signed ready to run on any Mac with macOS 12 Monterey or newer)*

### How to Trigger a Build Manually:
1. Go to the **Actions** tab in GitHub: `https://github.com/yvpdevelopments9232-cpu/dairymanage/actions`
2. Select **Build iOS IPA & macOS Application** on the left.
3. Click **Run workflow**, choose your branch (`main`) and choose your edition (`all`, `hybrid`, `offline`, or `online`).
4. Once completed (approx. 5-7 minutes), download the artifacts under the run summary!
