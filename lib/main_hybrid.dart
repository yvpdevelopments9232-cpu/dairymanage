import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart' as main_file;
import 'services/app_config.dart';
import 'services/offline_db_helper.dart';
import 'services/sync_service.dart';
import 'providers/session_provider.dart';
import 'screens/login_screen.dart';
import 'screens/sub_login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/account_pending_screen.dart';
import 'services/account_status_service.dart';
import 'services/subscription_service.dart';
import 'models/subscription_model.dart';
import 'screens/subscription/choose_plan_screen.dart';
import 'screens/subscription/subscription_expired_screen.dart';
import 'widgets/offline_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.isOfflineMode = true;
  AppConfig.isHybridMode = true;

  main_file.prefs = await SharedPreferences.getInstance();

  // Initialize Supabase for background cloud synchronization
  try {
    await Supabase.initialize(
      url: 'https://xlgsccosvlbpgwxuygwj.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhsZ3NjY29zdmxicGd3eHV5Z3dqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2MjMwNzEsImV4cCI6MjEwNDE5OTA3MX0.urTHBTO7pXM4BgpX7aUv03TLXlFqDvxQzLvJayTyjKg',
    );
  } catch (e) {
    debugPrint('Supabase init note: $e');
  }

  // Initialize local SQLite database
  await OfflineDbHelper.instance.database;

  // Start background sync manager
  SyncService.instance.start();

  runApp(
    const ProviderScope(
      child: DairyManagementHybridApp(),
    ),
  );
}

class DairyManagementHybridApp extends ConsumerStatefulWidget {
  const DairyManagementHybridApp({super.key});

  @override
  ConsumerState<DairyManagementHybridApp> createState() => _DairyManagementHybridAppState();
}

class _DairyManagementHybridAppState extends ConsumerState<DairyManagementHybridApp> {
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

    // Check account status if online
    try {
      await ref.read(accountStatusProvider.notifier).checkStatus();
    } catch (_) {}

    // Check subscription if online / hybrid
    try {
      await ref.read(subscriptionProvider.notifier).checkSubscription();
    } catch (_) {}

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final accountStatus = ref.watch(accountStatusProvider);
    final subState = ref.watch(subscriptionProvider);

    Widget homeWidget;
    if (_isChecking || subState.status == SubscriptionStatus.checking) {
      homeWidget = Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Checking subscription...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (!_isLoggedIn && session == null && Supabase.instance.client.auth.currentUser == null) {
      homeWidget = const LoginScreen();
    } else if (subState.status == SubscriptionStatus.none) {
      homeWidget = const ChoosePlanScreen();
    } else if (subState.status == SubscriptionStatus.expired) {
      homeWidget = const SubscriptionExpiredScreen();
    } else if (accountStatus.status == AccountStatus.pending || subState.status == SubscriptionStatus.pending) {
      homeWidget = AccountPendingScreen(
        onReactivated: () {
          ref.read(accountStatusProvider.notifier).checkStatus(forceRefresh: true);
          ref.read(subscriptionProvider.notifier).checkSubscription(forceRefresh: true);
        },
      );
    } else if (session != null) {
      homeWidget = const DashboardScreen();
    } else if (_isLoggedIn) {
      homeWidget = const SubLoginScreen();
    } else {
      homeWidget = const LoginScreen();
    }

    return MaterialApp(
      title: 'Dairy Management (Hybrid Auto-Sync)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal.shade800),
        useMaterial3: true,
      ),
      home: homeWidget,
      builder: (context, child) => GlobalOfflineWrapper(child: child!),
    );
  }
}
