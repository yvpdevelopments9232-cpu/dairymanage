import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'otp_verification_screen.dart';
import '../services/app_config.dart';
import '../services/offline_db_helper.dart';
import '../main.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  void _showOfflineResetDialog(String email) {
    final newPassCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: Colors.blue),
            SizedBox(width: 8),
            Text('Reset Offline PIN'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: $email', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password / PIN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPass = newPassCtrl.text.trim();
              if (newPass.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password/PIN must be at least 4 characters')),
                );
                return;
              }
              await prefs.setString(AppConfig.prefKey('admin_pin'), newPass);
              try {
                final db = await OfflineDbHelper.instance.database;
                await db.update('offline_users', {'password': newPass}, where: 'username = ? OR email = ?', whereArgs: [email, email]);
              } catch (_) {}

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated successfully! Please login with your new PIN.'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save New Password'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email address')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
        // Offline Standalone Edition: verify against local SQLite and shared preferences
        final savedEmail = prefs.getString(AppConfig.prefKey('logged_in_email')) ?? prefs.getString('offline_logged_in_email') ?? '';
        final db = await OfflineDbHelper.instance.database;
        final users = await db.query('offline_users', where: 'username = ? OR email = ?', whereArgs: [email, email]);

        if (savedEmail.toLowerCase() != email.toLowerCase() && users.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('User does not exist in local offline database!'),
                backgroundColor: Colors.red.shade600,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Show dialog to reset local password
        if (mounted) {
          _showOfflineResetDialog(email);
        }
        setState(() => _isLoading = false);
        return;
      }

      // Online and Hybrid Editions: use Supabase
      final supabase = Supabase.instance.client;

      // 1. Check if the user exists using secure RPC function (with graceful fallback)
      bool? userExists;
      try {
        final res = await supabase.rpc('check_user_exists', params: {'lookup_email': email});
        if (res is bool) userExists = res;
      } catch (rpcErr) {
        debugPrint('check_user_exists note (proceeding with standard auth): $rpcErr');
      }

      if (userExists == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('User does not exist in the system!'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 2. User exists, send the password reset email/OTP
      await supabase.auth.resetPasswordForEmail(email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset OTP sent to your email! Please check your inbox.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        // Navigate to the OTP verification screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => OtpVerificationScreen(email: email)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 1,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_reset, size: 80, color: primaryColor),
                const SizedBox(height: 24),
                const Text(
                  'Reset Your Password',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  (AppConfig.isOfflineMode && !AppConfig.isHybridMode)
                      ? 'Enter your offline username or email to reset your admin PIN.'
                      : 'Enter the email address associated with your account. We will check if it exists and send you a password reset link.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: (AppConfig.isOfflineMode && !AppConfig.isHybridMode) ? 'Username / Email' : 'Email Address',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.email, color: primaryColor),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendResetLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            (AppConfig.isOfflineMode && !AppConfig.isHybridMode) ? 'RESET PIN' : 'SEND RESET LINK',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
