import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../services/app_config.dart';
import '../main.dart';
import 'dashboard_screen.dart';
import 'forgot_password_screen.dart';
import 'account_pending_screen.dart';
import '../services/account_status_service.dart';
import '../services/subscription_service.dart';
import '../models/subscription_model.dart';
import 'subscription/choose_plan_screen.dart';
import 'subscription/subscription_expired_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLogin = true; // Toggle between Login and Sign Up
  bool _passwordVisible = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Please fill in all fields'))
       );
       return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      
      if (_isLogin) {
        await repo.login(_emailController.text.trim(), _passwordController.text);
      } else {
        await repo.signUp(_emailController.text.trim(), _passwordController.text);
      }
      
      if (AppConfig.isOfflineMode) {
        await prefs.setBool(AppConfig.prefKey('is_logged_in'), true);
        await prefs.setString(AppConfig.prefKey('logged_in_email'), _emailController.text.trim());
        await prefs.setString(AppConfig.prefKey('admin_pin'), _passwordController.text);
        await ref.read(sessionProvider.notifier).loginAsAdmin(saveSession: true);
      }

      // Check account status for Online and Hybrid editions
      if (!AppConfig.isOfflineMode || AppConfig.isHybridMode) {
        final status = await ref.read(accountStatusProvider.notifier).checkStatus(forceRefresh: true);
        if (status == AccountStatus.pending) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AccountPendingScreen(
                  onReactivated: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    );
                  },
                ),
              ),
            );
            return;
          }
        }
      }

      // Check Subscription Status for Online and Hybrid editions
      if (!AppConfig.isOfflineMode || AppConfig.isHybridMode) {
        final subStatus = await ref.read(subscriptionProvider.notifier).checkSubscription(forceRefresh: true);
        if (subStatus == SubscriptionStatus.pending) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AccountPendingScreen(
                  onReactivated: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    );
                  },
                ),
              ),
            );
            return;
          }
        } else if (subStatus == SubscriptionStatus.none) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ChoosePlanScreen()),
            );
            return;
          }
        } else if (subStatus == SubscriptionStatus.expired) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SubscriptionExpiredScreen()),
            );
            return;
          }
        }
      }

      if (mounted) {
        // Navigate to Dashboard after success
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen())
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'An error occurred. Please try again.';
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('invalid login credentials') || errStr.contains('invalid username or password')) {
          msg = 'Invalid username or password';
        } else if (errStr.contains('user already registered') || errStr.contains('already exists')) {
          msg = 'User already exists. Please log in.';
        } else {
          msg = e.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Custom Dairy Theme Colors
    final primaryColor = const Color(0xFF1565C0); // Professional Blue
    final secondaryColor = const Color(0xFF2E7D32); // Dairy Green
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Dairy-Themed Icon / Logo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.water_drop, // Using a drop for milk
                      size: 80,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Titles
                  Text(
                    _isLogin ? 'Dairy Management' : 'Create Account',
                    style: textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _isLogin ? 'Sign in to continue' : 'Sign up to get started',
                    style: textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Email Field
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: AppConfig.isOfflineMode ? 'Username / Email' : 'Email Address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.person, color: primaryColor),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.lock, color: primaryColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible ? Icons.visibility : Icons.visibility_off,
                          color: primaryColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 8),
                  
                  // Remember Me & Forgot Password Row
                  if (_isLogin)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: primaryColor,
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? false;
                                });
                              },
                            ),
                            const Text('Remember me'),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Main Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isLogin ? 'LOGIN' : 'SIGN UP',
                              style: textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Forgot Password
                  if (_isLogin)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                        );
                      },
                      child: Text('Forgot Password?', style: TextStyle(color: secondaryColor)),
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Toggle Login / Sign Up
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                      });
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isLogin 
                          ? "Don't have an account? Create New Account" 
                          : "Already have an account? Login",
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
