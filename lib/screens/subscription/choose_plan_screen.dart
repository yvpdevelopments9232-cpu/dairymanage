import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';
import '../../providers/auth_provider.dart';
import '../login_screen.dart';
import 'payment_screen.dart';

class ChoosePlanScreen extends ConsumerStatefulWidget {
  final bool isRenewing;
  const ChoosePlanScreen({super.key, this.isRenewing = false});

  @override
  ConsumerState<ChoosePlanScreen> createState() => _ChoosePlanScreenState();
}

class _ChoosePlanScreenState extends ConsumerState<ChoosePlanScreen> {
  String _selectedPlanId = 'premium'; // Default to Most Popular

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionProvider);
    final plans = subState.availablePlans.isNotEmpty 
        ? subState.availablePlans 
        : SubscriptionPlan.defaultPlans;

    final primaryColor = const Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.isRenewing ? 'Renew Subscription' : 'Please Subscribe',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        automaticallyImplyLeading: widget.isRenewing,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to log out of Dairy Management?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(authRepositoryProvider).logOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          )
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // 1. Header Banner
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium, size: 48, color: Color(0xFFD4AF37)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Dairy Management',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select the best plan for your dairy business',
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Text(
                          '⚡ 1 Year Complete License with Cloud Sync & Updates',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1565C0)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Plans Cards
                ...plans.map((plan) {
                  final isSelected = _selectedPlanId == plan.id;
                  final isPopular = plan.badge != null && plan.badge!.isNotEmpty;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedPlanId = plan.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? primaryColor : (isPopular ? Colors.orange.shade300 : Colors.grey.shade300),
                          width: isSelected ? 2.5 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected 
                                ? primaryColor.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.04),
                            blurRadius: isSelected ? 12 : 6,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Popular Badge
                          if (isPopular)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  topRight: Radius.circular(14),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  '★ MOST POPULAR ★',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),

                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: _getPlanColor(plan.id).withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(_getPlanIcon(plan.id), color: _getPlanColor(plan.id), size: 28),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              plan.name,
                                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Billed Annually (365 Days)',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Radio<String>(
                                      value: plan.id,
                                      groupValue: _selectedPlanId,
                                      activeColor: primaryColor,
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedPlanId = val);
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Price Display
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '₹${plan.price.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                    Text(
                                      ' / ${plan.billingCycle}',
                                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 14),

                                // Features List
                                ...plan.features.map((feature) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle, size: 18, color: Color(0xFF2E7D32)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          feature,
                                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 12),

                // 3. Continue / Subscribe Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      final chosenPlan = plans.firstWhere(
                        (p) => p.id == _selectedPlanId,
                        orElse: () => plans.first,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(plan: chosenPlan),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'CONTINUE TO PAYMENT',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Security Note
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '100% Secure Payment • Instant Activation • 24/7 Support',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPlanColor(String id) {
    switch (id.toLowerCase()) {
      case 'basic':
        return Colors.orange.shade700;
      case 'premium':
        return const Color(0xFF1565C0);
      case 'enterprise':
        return Colors.purple.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getPlanIcon(String id) {
    switch (id.toLowerCase()) {
      case 'basic':
        return Icons.eco;
      case 'premium':
        return Icons.star;
      case 'enterprise':
        return Icons.apartment;
      default:
        return Icons.card_membership;
    }
  }
}
