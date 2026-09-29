import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/subscription_service.dart';
import 'choose_plan_screen.dart';
import 'payment_history_screen.dart';

class SubscriptionStatusScreen extends ConsumerWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(subscriptionProvider);
    final sub = subState.currentSubscription;

    final primaryColor = const Color(0xFF1565C0);
    final dateFormat = DateFormat('dd MMM yyyy');

    final planName = sub?.planName ?? 'Premium Plan';
    final startDate = sub?.startDate ?? DateTime.now();
    final endDate = sub?.endDate ?? DateTime.now().add(const Duration(days: 365));
    final daysRemaining = sub?.daysRemaining ?? 365;
    final subId = sub?.subscriptionId ?? 'DM-${DateTime.now().year}0101-001';
    final autoRenewal = sub?.autoRenewal ?? true;

    Color daysColor = const Color(0xFF2E7D32); // Green
    if (daysRemaining <= 7) {
      daysColor = Colors.red.shade700;
    } else if (daysRemaining <= 30) {
      daysColor = Colors.orange.shade800;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Payment History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: () {
              ref.read(subscriptionProvider.notifier).checkSubscription(forceRefresh: true);
            },
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. Hero License Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade900, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 36),
                            const SizedBox(width: 10),
                            Text(
                              planName,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Get all premium features and manage your dairy business efficiently with real-time sync.',
                      style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.3),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Metrics & License Specs Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSpecRow('Plan Name', planName, isBold: true),
                    const Divider(height: 22),
                    _buildSpecRow('Start Date', dateFormat.format(startDate)),
                    const Divider(height: 22),
                    _buildSpecRow('Expiry Date', dateFormat.format(endDate)),
                    const Divider(height: 22),
                    _buildSpecRow(
                      'Days Remaining',
                      '$daysRemaining Days',
                      valueColor: daysColor,
                      isBold: true,
                    ),
                    const Divider(height: 22),
                    _buildSpecRow('Auto Renewal', autoRenewal ? 'ON' : 'OFF'),
                    const Divider(height: 22),
                    _buildSpecRow('Subscription ID', subId, isMonospace: true),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Actions
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showPlanDetailsModal(context, planName);
                  },
                  icon: const Icon(Icons.list_alt, size: 20),
                  label: const Text('View Plan Features & Rights', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChoosePlanScreen(isRenewing: true)),
                    );
                  },
                  icon: const Icon(Icons.upgrade, size: 20),
                  label: const Text('Upgrade / Renew Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
                    );
                  },
                  icon: const Icon(Icons.receipt_long, size: 20),
                  label: const Text('Payment History & Invoices', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade800,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, {bool isBold = false, Color? valueColor, bool isMonospace = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.black87,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }

  void _showPlanDetailsModal(BuildContext context, String currentPlan) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$currentPlan Features', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView(
                  children: const [
                    _FeatureTile('Farmer Management', 'Add, edit, and organize farmer accounts', true),
                    _FeatureTile('Milk Collection', 'Morning/evening buffalo & cow collection entries', true),
                    _FeatureTile('Payment Management', 'Track bills, settlements, and advance deductions', true),
                    _FeatureTile('Bonus Module', 'Calculate annual/seasonal milk bonuses', true),
                    _FeatureTile('Bank Management', 'Bank transactions and account ledgers', true),
                    _FeatureTile('Advanced Reports', 'Periodical statements, bills, and summary analytics', true),
                    _FeatureTile('PDF Reports & Export', 'Print receipts and export professional PDFs', true),
                    _FeatureTile('Multi-Device Cloud Sync', 'Real-time synchronization across devices', true),
                    _FeatureTile('Animal Management', 'Track breeds, tagging, and cattle records', true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool included;

  const _FeatureTile(this.title, this.subtitle, this.included);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(included ? Icons.check_circle : Icons.cancel, color: included ? const Color(0xFF2E7D32) : Colors.grey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
