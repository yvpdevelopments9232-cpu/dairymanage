
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/offline_wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/session_provider.dart';
import 'services/app_config.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/sub_login_screen.dart';
import 'screens/account_pending_screen.dart';
import 'services/account_status_service.dart';
import 'services/subscription_service.dart';
import 'models/subscription_model.dart';
import 'screens/subscription/choose_plan_screen.dart';
import 'screens/subscription/subscription_expired_screen.dart';

late SharedPreferences prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.isOfflineMode = false;
  
  prefs = await SharedPreferences.getInstance();

  await Supabase.initialize(
    url: 'https://xlgsccosvlbpgwxuygwj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhsZ3NjY29zdmxicGd3eHV5Z3dqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2MjMwNzEsImV4cCI6MjEwNDE5OTA3MX0.urTHBTO7pXM4BgpX7aUv03TLXlFqDvxQzLvJayTyjKg',
  );
  
  runApp(
    const ProviderScope(
      child: DairyManagementApp(),
    ),
  );
}

class DairyManagementApp extends StatelessWidget {
  const DairyManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dairy Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade900),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      builder: (context, child) => GlobalOfflineWrapper(child: child!),
 
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    final session = Supabase.instance.client.auth.currentSession;
    _loggedIn = session != null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) {
        if (state.session != null) {
          return const SubAuthGate();
        }
        return const LoginScreen();
      },
      loading: () {
        if (_loggedIn) return const SubAuthGate();
        return const LoginScreen();
      },
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
    );
  }
}


class SubAuthGate extends ConsumerStatefulWidget {
  const SubAuthGate({super.key});

  @override
  ConsumerState<SubAuthGate> createState() => _SubAuthGateState();
}

class _SubAuthGateState extends ConsumerState<SubAuthGate> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final type = prefs.getString('active_sub_account_type');
    if (type == 'admin') {
      await ref.read(sessionProvider.notifier).loginAsAdmin(saveSession: false);
    } else if (type == 'employee') {
      final empId = prefs.getString('active_employee_id');
      final empPin = prefs.getString('active_employee_pin');
      if (empId != null && empPin != null) {
        try {
          final supabase = ref.read(supabaseClientProvider);
          final res = await supabase.from('employees').select('*, roles(name)').eq('id', empId).single().timeout(const Duration(seconds: 5));
          final emp = Employee.fromJson(res);
          await ref.read(sessionProvider.notifier).loginAsEmployee(emp, empPin, saveSession: false);
        } catch (_) {}
      }
    }

    // Check account status from Supabase
    try {
      await ref.read(accountStatusProvider.notifier).checkStatus();
    } catch (_) {}

    // Check subscription status from Supabase
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
    
    if (_isChecking || subState.status == SubscriptionStatus.checking) {
      return Scaffold(
        backgroundColor: Colors.white,
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
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If no active subscription, immediately open Please Subscribe
    if (subState.status == SubscriptionStatus.none) {
      return const ChoosePlanScreen();
    }

    // If subscription expired, immediately open Subscription Expired
    if (subState.status == SubscriptionStatus.expired) {
      return const SubscriptionExpiredScreen();
    }

    // If account is marked pending or subscription is pending, block dashboard access and show Admin Approval screen
    if (accountStatus.status == AccountStatus.pending || subState.status == SubscriptionStatus.pending) {
      return AccountPendingScreen(
        onReactivated: () {
          ref.read(accountStatusProvider.notifier).checkStatus(forceRefresh: true);
          ref.read(subscriptionProvider.notifier).checkSubscription(forceRefresh: true);
        },
      );
    }
    
    if (session == null) {
      return const SubLoginScreen();
    }
    return const DashboardScreen();
  }
}

