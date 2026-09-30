import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart' as main_file;
import 'services/app_config.dart';
import 'services/offline_db_helper.dart';
import 'providers/session_provider.dart';
import 'screens/login_screen.dart';
import 'screens/sub_login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'widgets/offline_wrapper.dart';
import 'services/translations.dart';
import 'providers/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.isOfflineMode = true;

  main_file.prefs = await SharedPreferences.getInstance();
  final savedLang = main_file.prefs.getString(AppTranslations.keyLanguage) ?? 'en';
  AppTranslations.currentLanguage = savedLang;

  // Initialize offline SQLite database and schema
  await OfflineDbHelper.instance.database;

  runApp(
    const ProviderScope(
      child: DairyManagementOfflineApp(),
    ),
  );
}

class DairyManagementOfflineApp extends ConsumerStatefulWidget {
  const DairyManagementOfflineApp({super.key});

  @override
  ConsumerState<DairyManagementOfflineApp> createState() => _DairyManagementOfflineAppState();
}

class _DairyManagementOfflineAppState extends ConsumerState<DairyManagementOfflineApp> {
  bool _isChecking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final loggedIn = main_file.prefs.getBool(AppConfig.prefKey('is_logged_in')) ?? false;
    if (loggedIn) {
      _isLoggedIn = true;
      final subType = main_file.prefs.getString(AppConfig.prefKey('active_sub_account_type'));
      if (subType == 'employee') {
        final empId = main_file.prefs.getString(AppConfig.prefKey('active_employee_id'));
        final empPin = main_file.prefs.getString(AppConfig.prefKey('active_employee_pin'));
        if (empId != null && empPin != null) {
          try {
            final db = await OfflineDbHelper.instance.database;
            final empRes = await db.rawQuery(
              'SELECT e.*, r.name AS role_name FROM employees e LEFT JOIN roles r ON e.role_id = r.id WHERE e.id = ?',
              [empId],
            );
            if (empRes.isNotEmpty) {
              final emp = Employee.fromJson(empRes.first);
              await ref.read(sessionProvider.notifier).loginAsEmployee(emp, empPin, saveSession: false);
            }
          } catch (_) {}
        }
      } else {
        await ref.read(sessionProvider.notifier).loginAsAdmin(saveSession: true);
      }
    }
    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    Widget homeWidget;
    if (_isChecking) {
      homeWidget = const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (session != null) {
      homeWidget = const DashboardScreen();
    } else if (_isLoggedIn) {
      homeWidget = const SubLoginScreen();
    } else {
      homeWidget = const LoginScreen();
    }

    final lang = ref.watch(languageProvider);

    return MaterialApp(
      key: ValueKey(lang),
      title: AppTranslations.tr('Dairy Management (Offline Edition)', lang),
      locale: Locale(lang),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade900),
        fontFamilyFallback: const ['Nirmala UI', 'Mangal', 'Segoe UI'],
        useMaterial3: true,
      ),
      home: homeWidget,
      builder: (context, child) => GlobalOfflineWrapper(child: child!),
    );
  }
}
