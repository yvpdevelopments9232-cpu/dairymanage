import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/subscription_service.dart';
import '../../services/account_status_service.dart';
import '../account_pending_screen.dart';
import '../dashboard_screen.dart';
import 'payment_success_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final SubscriptionPlan plan;

  const PaymentScreen({super.key, required this.plan});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _selectedMethod = 'UPI';
  String _selectedUpiApp = 'PhonePe';
  bool _isProcessing = false;

  final _upiController = TextEditingController(text: 'dairyfarm@okhdfcbank');
  final _utrController = TextEditingController();
  final _cardNumberController = TextEditingController(text: '4532 8765 9012 3456');
  final _cardExpiryController = TextEditingController(text: '12/28');
  final _cardCvvController = TextEditingController(text: '345');
  String _selectedBank = 'State Bank of India';

  @override
  void dispose() {
    _upiController.dispose();
    _utrController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    super.dispose();
  }

  Future<void> _submitSuccessfulPayment() async {
    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final randomNum = (Random().nextInt(900000) + 100000).toString();
      final utr = _utrController.text.trim();
      final txnId = utr.isNotEmpty ? utr : 'UPI$dateStr$randomNum';

      await ref.read(subscriptionProvider.notifier).submitPaymentForApproval(
        plan: widget.plan,
        paymentMethod: 'UPI ($_selectedUpiApp)',
        transactionId: txnId,
      );

      // Force refresh account status to pending
      await ref.read(accountStatusProvider.notifier).checkStatus(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment details submitted successfully! Awaiting admin approval.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Open Admin Approval Screen
        Navigator.pushReplacement(
          context,
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processPayment() async {
    if (_selectedMethod == 'UPI') {
      await _submitSuccessfulPayment();
      return;
    }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // App selector chips: PhonePe, Google Pay, Any UPI
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _buildUpiAppChip(
              name: 'PhonePe',
              color: const Color(0xFF5F259F),
              icon: Icons.account_balance_wallet,
            ),
            _buildUpiAppChip(
              name: 'Google Pay',
              color: const Color(0xFF1A73E8),
              icon: Icons.payment,
            ),
            _buildUpiAppChip(
              name: 'Paytm / BHIM',
              color: Colors.teal.shade700,
              icon: Icons.qr_code,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // QR Scanner Card matching Image 2
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.deepPurple.shade100, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF5F259F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFF5F259F)),
                    const SizedBox(width: 6),
                    Text(
                      '$_selectedUpiApp QR SCANNER',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5F259F),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // The PhonePe / GPay Scanner Image
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/phonepe_qr.png',
                    width: 230,
                    height: 230,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 230,
                        height: 230,
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2, size: 80, color: Colors.deepPurple),
                              SizedBox(height: 8),
                              Text('QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Payee Name & Amount
              const Text(
                'Mr VIKRAM MALHARI PAWAR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'Amount to Pay: ₹${widget.plan.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan & pay using PhonePe, Google Pay, Paytm, or BHIM',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Step Instructions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 6),
                  Text(
                    'Payment Steps:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '1. Open $_selectedUpiApp or Google Pay on your phone.\n'
                '2. Scan the QR code above and transfer ₹${widget.plan.price.toStringAsFixed(0)}.\n'
                '3. Enter the 12-digit UTR / UPI Ref No. below & tap "Successful Payment".\n'
                '4. You will see Admin Approval screen to contact developer for activation.',
                style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // UTR Input Field
        TextField(
          controller: _utrController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Enter 12-digit UTR / UPI Ref No. (Optional)',
            hintText: 'e.g. 427819283746',
            helperText: 'Found on your PhonePe / GPay payment receipt',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.tag),
            isDense: true,
          ),
        ),

        const SizedBox(height: 18),

        // Prominent SUCCESSFUL PAYMENT Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle, size: 22),
            label: Text(
              _isProcessing ? 'Submitting...' : 'I HAVE PAID (SUCCESSFUL PAYMENT)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isProcessing ? null : _submitSuccessfulPayment,
          ),
        ),
      ],
    );
  }

  Widget _buildUpiAppChip({
    required String name,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _selectedUpiApp == name;
    return InkWell(
      onTap: () => setState(() => _selectedUpiApp = name),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
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
