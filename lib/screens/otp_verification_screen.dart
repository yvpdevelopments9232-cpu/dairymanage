import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _passwordVisible = false;

  Future<void> _verifyAndResetPassword() async {
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    
    if (otp.isEmpty || otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the 6-digit OTP')));
      return;
    }
    
    if (newPassword.isEmpty || newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Verify the OTP (This logs the user in if successful)
      await supabase.auth.verifyOTP(
        type: OtpType.recovery,
        email: widget.email,
        token: otp,
      );

      // 2. Update the password to the new one
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      // 3. Log out so they can log in normally (optional, but good practice after reset)
      await supabase.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully! You can now log in.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          )
        );
        
        // Navigate all the way back to Login Screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Invalid OTP or expired. Please try again.';
        if (e.toString().toLowerCase().contains('password')) {
           msg = e.toString(); // Show specific password requirement errors
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
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
        title: const Text('Enter OTP', style: TextStyle(color: Colors.black87)),
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
                Icon(Icons.mark_email_read, size: 80, color: primaryColor),
                const SizedBox(height: 24),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'We sent a 6-digit OTP code to\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 16),
                ),
                const SizedBox(height: 32),
                
                // OTP Field
                TextField(
                  controller: _otpController,
                  decoration: InputDecoration(
                    labelText: '6-Digit OTP Code',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.pin, color: primaryColor),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                // New Password Field
                TextField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock, color: primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
                        color: primaryColor,
                      ),
                      onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                    ),
                  ),
                  obscureText: !_passwordVisible,
                ),
                const SizedBox(height: 32),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyAndResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('VERIFY & SET PASSWORD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
