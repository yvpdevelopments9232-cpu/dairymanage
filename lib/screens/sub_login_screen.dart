
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_config.dart';
import '../services/offline_db_helper.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'forgot_password_screen.dart';
import '../main.dart';

class SubLoginScreen extends ConsumerStatefulWidget {
  const SubLoginScreen({super.key});

  @override
  ConsumerState<SubLoginScreen> createState() => _SubLoginScreenState();
}

class _SubLoginScreenState extends ConsumerState<SubLoginScreen> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedUserId = 'admin'; 
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _submitLogin(List<Employee> employees) async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      if (_selectedUserId == 'admin') {
        if (AppConfig.isOfflineMode) {
          final savedPin = prefs.getString(AppConfig.prefKey('admin_pin')) ?? prefs.getString('offline_admin_pin');
          final entered = _pinController.text.trim();
          bool isValid = (savedPin != null && entered == savedPin);
          if (!isValid) {
            final db = await OfflineDbHelper.instance.database;
            final users = await db.query('offline_users', where: 'password = ?', whereArgs: [entered]);
            if (users.isNotEmpty) isValid = true;
          }

          if (isValid) {
            await ref.read(sessionProvider.notifier).loginAsAdmin(saveSession: false);
          } else {
            throw Exception("Incorrect Password / PIN");
          }
        } else {
          final supabase = ref.read(supabaseClientProvider);
          final email = supabase.auth.currentUser?.email;
          if (email == null) throw Exception("No admin email found");
          
          await supabase.auth.signInWithPassword(email: email, password: _pinController.text);
          await ref.read(sessionProvider.notifier).loginAsAdmin();
        }
      } else {
        final emp = employees.firstWhere((e) => e.id == _selectedUserId);
        final pin = _pinController.text.trim();
        
        if (emp.pin == pin && emp.isActive) {
          await ref.read(sessionProvider.notifier).loginAsEmployee(emp, pin, saveSession: !AppConfig.isOfflineMode);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Invalid PIN or Inactive Account"), backgroundColor: Colors.red)
            );
          }
          return;
        }
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Incorrect Password / PIN"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesListProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("User Login"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout to Main Login",
            onPressed: () async {
              if (AppConfig.isOfflineMode) {
                await prefs.setBool(AppConfig.prefKey('is_logged_in'), false);
                await prefs.remove(AppConfig.prefKey('active_sub_account_type'));
                ref.read(sessionProvider.notifier).logoutSubAccount();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } else {
                await ref.read(authRepositoryProvider).logOut();
              }
            },
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4)
                )
              ]
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  const Text("Welcome Back", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Please select your account and login", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 32),
                  
                  employeesAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, st) => Text("Error loading users: $e"),
                    data: (employees) {
                      return DropdownButtonFormField<String>(
                        value: _selectedUserId,
                        decoration: InputDecoration(
                          labelText: 'Select Username',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (val) => val == null ? 'Please select a user' : null,
                        items: [
                          const DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin (Owner)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ...employees.map((emp) => DropdownMenuItem(
                            value: emp.id,
                            child: Text(emp.name),
                          )).toList(),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedUserId = val);
                        },
                      );
                    }
                  ),
                  
                  const SizedBox(height: 20),
                  
                  TextFormField(
                    controller: _pinController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password / PIN',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Please enter password' : null,
                    onFieldSubmitted: (_) {
                      if (employeesAsync.hasValue) {
                        _submitLogin(employeesAsync.value!);
                      }
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading || !employeesAsync.hasValue ? null : () => _submitLogin(employeesAsync.value!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                      );
                    },
                    child: const Text('Forgot Password / PIN?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

