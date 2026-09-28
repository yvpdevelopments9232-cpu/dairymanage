import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email address')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Check if the user exists using our secure RPC function
      final userExists = await supabase.rpc('check_user_exists', params: {'lookup_email': email});

      if (userExists == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('User does not exist in the system!'),
              backgroundColor: Colors.red.shade600,
            )
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
            content: Text('Password reset link sent to your email! Please check your inbox.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          )
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
          )
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
                const Text(
                  'Enter the email address associated with your account. We will check if it exists and send you a password reset link.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
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
                        : const Text('SEND RESET LINK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
