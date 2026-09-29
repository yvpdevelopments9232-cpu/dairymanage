import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/account_status_service.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../services/subscription_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'subscription/choose_plan_screen.dart';
import 'help_center_screen.dart';

class AccountPendingScreen extends ConsumerStatefulWidget {
  final VoidCallback? onReactivated;

  const AccountPendingScreen({super.key, this.onReactivated});

  @override
  ConsumerState<AccountPendingScreen> createState() => _AccountPendingScreenState();
}

class _AccountPendingScreenState extends ConsumerState<AccountPendingScreen> {
  bool _isChecking = false;
  String? _feedbackMessage;

  Future<void> _makePhoneCall() async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: AccountStatusNotifier.contactPhone,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open phone dialer. Dial 6361782144 directly.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dial 6361782144 directly to contact support.')),
        );
      }
    }
  }

  Future<void> _checkStatusAgain() async {
    setState(() {
      _isChecking = true;
      _feedbackMessage = null;
    });

    final status = await ref.read(accountStatusProvider.notifier).checkStatus(forceRefresh: true);

    if (mounted) {
      setState(() {
        _isChecking = false;
      });

      if (status == AccountStatus.active) {
        await ref.read(subscriptionProvider.notifier).checkSubscription(forceRefresh: true);
        if (mounted) {
          if (widget.onReactivated != null) {
            widget.onReactivated!();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          }
        }
      } else if (status == AccountStatus.pending) {
        setState(() {
          _feedbackMessage = 'Account status is still pending. Please contact Yu_Vi Development.';
        });
      } else if (status == AccountStatus.networkError) {
        setState(() {
          _feedbackMessage = 'Unable to verify your account. Please check your internet connection.';
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      ref.read(sessionProvider.notifier).logoutSubAccount();
    } catch (_) {}
    try {
      await ref.read(authRepositoryProvider).logOut();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Lock Icon Badge
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber.shade300, width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          '🔒',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'ACCOUNT PENDING',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Main Message
                    const Text(
                      'Your application account is currently pending.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Payment Pending Notice
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.info_outline, size: 16, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Due to your payment pending',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Secondary Message
                    const Text(
                      'Please contact Yu_Vi Development to activate your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Contact Developer Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Yu_Vi Development',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.phone, size: 16, color: Color(0xFF0284C7)),
                              SizedBox(width: 6),
                              Text(
                                'Mobile: 6361782144',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    if (_feedbackMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          _feedbackMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    // Action Button: Contact Yu_Vi Development
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text(
                          'Contact Yu_Vi Development',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _makePhoneCall,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Button: Retry / Check Again
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: _isChecking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: Text(
                          _isChecking ? 'Checking...' : 'Check Again / Retry',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isChecking ? null : _checkStatusAgain,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // View Plans & QR Scanner
                    TextButton.icon(
                      icon: const Icon(Icons.qr_code, size: 16, color: Color(0xFF0284C7)),
                      label: const Text(
                        'View Plans & QR Payment Scanner',
                        style: TextStyle(color: Color(0xFF0284C7), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChoosePlanScreen()),
                        );
                      },
                    ),
                    // Help Center Button
                    TextButton.icon(
                      icon: const Icon(Icons.support_agent, size: 16, color: Color(0xFF0284C7)),
                      label: const Text(
                        'Help Center & Support Details',
                        style: TextStyle(color: Color(0xFF0284C7), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // Logout Button
                    TextButton.icon(
                      icon: const Icon(Icons.logout, size: 16, color: Colors.grey),
                      label: const Text('Log Out', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
