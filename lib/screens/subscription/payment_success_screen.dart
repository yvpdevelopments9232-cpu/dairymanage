import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../providers/settings_provider.dart';
import '../dashboard_screen.dart';

class PaymentSuccessScreen extends ConsumerWidget {
  final UserSubscription subscription;
  final SubscriptionPlan plan;
  final String transactionId;
  final String paymentMethod;

  const PaymentSuccessScreen({
    super.key,
    required this.subscription,
    required this.plan,
    required this.transactionId,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = const Color(0xFF1565C0);
    final settingsAsync = ref.watch(settingsProvider);
    final dairyName = settingsAsync.value?.dairyName ?? 'My Dairy Farm';
    final customerEmail = ref.watch(subscriptionProvider).currentSubscription?.userId ?? 'Dairy Owner';

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Success Circle Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green.shade300, width: 2),
                  ),
                  child: const Icon(Icons.check_circle, size: 72, color: Color(0xFF2E7D32)),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Payment Successful!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Your 1-Year subscription license has been activated.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // 2. Receipt Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildReceiptRow('Plan', plan.name, isBold: true),
                      const Divider(height: 20),
                      _buildReceiptRow('Amount Paid', '₹${plan.price.toStringAsFixed(0)}', isBold: true, valueColor: primaryColor),
                      const Divider(height: 20),
                      _buildReceiptRow('Transaction ID', transactionId),
                      const Divider(height: 20),
                      _buildReceiptRow('Subscription ID', subscription.subscriptionId),
                      const Divider(height: 20),
                      _buildReceiptRow('Date & Time', dateFormat.format(DateTime.now())),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 3. Go to Dashboard Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      // Trigger state check to guarantee ACTIVE status
                      ref.read(subscriptionProvider.notifier).checkSubscription(forceRefresh: true);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const DashboardScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: const Text(
                      'GO TO DASHBOARD',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 4. Download Invoice Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await InvoicePdfService.generateAndPrintInvoice(
                        dairyName: dairyName,
                        customerEmail: customerEmail,
                        planName: plan.name,
                        amount: plan.price,
                        transactionId: transactionId,
                        subscriptionId: subscription.subscriptionId,
                        paymentDate: DateTime.now(),
                        startDate: subscription.startDate,
                        endDate: subscription.endDate,
                        paymentMethod: paymentMethod,
                      );
                    },
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Download Invoice (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
