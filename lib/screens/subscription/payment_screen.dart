import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';
import 'payment_success_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final SubscriptionPlan plan;

  const PaymentScreen({super.key, required this.plan});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _selectedMethod = 'UPI';
  bool _isProcessing = false;

  final _upiController = TextEditingController(text: 'dairyfarm@okhdfcbank');
  final _cardNumberController = TextEditingController(text: '4532 8765 9012 3456');
  final _cardExpiryController = TextEditingController(text: '12/28');
  final _cardCvvController = TextEditingController(text: '345');
  String _selectedBank = 'State Bank of India';

  @override
  void dispose() {
    _upiController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      // Simulate secure payment gateway handshake (1.5 seconds)
      await Future.delayed(const Duration(milliseconds: 1500));

      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final randomNum = (Random().nextInt(900000) + 100000).toString();
      final txnId = 'TXN$dateStr$randomNum';

      // Record in Supabase and activate subscription
      final activatedSub = await ref.read(subscriptionProvider.notifier).activateSubscription(
        plan: widget.plan,
        paymentMethod: _selectedMethod,
        transactionId: txnId,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              subscription: activatedSub,
              plan: widget.plan,
              transactionId: txnId,
              paymentMethod: _selectedMethod,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment activation error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. Selected Plan Summary Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade200, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SELECTED PLAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.workspace_premium, color: primaryColor, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.plan.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('1 Year License (${widget.plan.durationDays} Days)', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                        Text(
                          '₹${widget.plan.price.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Payment Method Selector
              const Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              _buildPaymentOption(
                title: 'UPI',
                subtitle: 'Google Pay, PhonePe, Paytm, BHIM',
                icon: Icons.flash_on,
                iconColor: Colors.deepPurple,
                value: 'UPI',
                customContent: _selectedMethod == 'UPI' ? _buildUpiInput() : null,
              ),

              _buildPaymentOption(
                title: 'Credit / Debit Card',
                subtitle: 'Visa, MasterCard, RuPay, Maestro',
                icon: Icons.credit_card,
                iconColor: Colors.blue.shade700,
                value: 'Credit / Debit Card',
                customContent: _selectedMethod == 'Credit / Debit Card' ? _buildCardInput() : null,
              ),

              _buildPaymentOption(
                title: 'Net Banking',
                subtitle: 'SBI, HDFC, ICICI, Axis & all major banks',
                icon: Icons.account_balance,
                iconColor: Colors.indigo,
                value: 'Net Banking',
                customContent: _selectedMethod == 'Net Banking' ? _buildNetBankingInput() : null,
              ),

              _buildPaymentOption(
                title: 'Wallet',
                subtitle: 'Paytm, Amazon Pay, Mobikwik',
                icon: Icons.account_balance_wallet,
                iconColor: Colors.teal,
                value: 'Wallet',
              ),

              const SizedBox(height: 20),

              // 3. Price Breakdown Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Subscription Fee:', '₹${widget.plan.price.toStringAsFixed(2)}'),
                    const SizedBox(height: 6),
                    _buildSummaryRow('GST / Platform Tax (0%):', '₹0.00'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount Payable:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(
                          '₹${widget.plan.price.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Pay Now Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isProcessing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                            SizedBox(width: 14),
                            Text('Processing Payment...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : Text(
                          'PAY NOW  •  ₹${widget.plan.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // 5. Trust badge
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.green),
                  SizedBox(width: 6),
                  Text('100% Secure Payment • 256-Bit SSL Encrypted', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String value,
    Widget? customContent,
  }) {
    final isSelected = _selectedMethod == value;
    final primaryColor = const Color(0xFF1565C0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? primaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            value: value,
            groupValue: _selectedMethod,
            activeColor: primaryColor,
            onChanged: (val) {
              if (val != null) setState(() => _selectedMethod = val);
            },
            title: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(left: 32, top: 2),
              child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
          ),
          if (customContent != null)
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 4),
              child: customContent,
            ),
        ],
      ),
    );
  }

  Widget _buildUpiInput() {
    return TextField(
      controller: _upiController,
      decoration: InputDecoration(
        labelText: 'Enter UPI ID / VPA',
        hintText: 'yourname@bank',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.alternate_email, size: 20),
        suffixText: '@verified',
        suffixStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
        isDense: true,
      ),
    );
  }

  Widget _buildCardInput() {
    return Column(
      children: [
        TextField(
          controller: _cardNumberController,
          decoration: InputDecoration(
            labelText: 'Card Number',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.credit_card, size: 20),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cardExpiryController,
                decoration: InputDecoration(
                  labelText: 'Expiry (MM/YY)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _cardCvvController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'CVV',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNetBankingInput() {
    return DropdownButtonFormField<String>(
      value: _selectedBank,
      decoration: InputDecoration(
        labelText: 'Select Bank',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      items: [
        'State Bank of India',
        'HDFC Bank',
        'ICICI Bank',
        'Axis Bank',
        'Punjab National Bank',
        'Bank of Baroda',
        'Kotak Mahindra Bank',
      ].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedBank = val);
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
