import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/flutter_models.dart';
import '../../../providers/bonus_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/bonus_pdf_service.dart';
import '../../../services/offline_db_helper.dart';
import '../../../services/translations.dart';

class BonusPaymentScreen extends ConsumerStatefulWidget {
  final String? preSelectedFarmerId;

  const BonusPaymentScreen({super.key, this.preSelectedFarmerId});

  @override
  ConsumerState<BonusPaymentScreen> createState() => _BonusPaymentScreenState();
}

class _BonusPaymentScreenState extends ConsumerState<BonusPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedFarmerId;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _txnNoController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController(text: 'Bonus Payment');
  final TextEditingController _farmerSearchController = TextEditingController();

  String _paymentMode = 'Cash';
  DateTime _paymentDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedFarmerId = widget.preSelectedFarmerId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _txnNoController.dispose();
    _remarksController.dispose();
    _farmerSearchController.dispose();
    super.dispose();
  }

  void _onFarmerSelected(BonusFarmerSummary farmer) {
    setState(() {
      _selectedFarmerId = farmer.farmerId;
      _farmerSearchController.text = farmer.farmerName;
      _amountController.text = farmer.remainingBonus > 0 ? farmer.remainingBonus.toStringAsFixed(2) : '0.00';
    });
  }

  Future<void> _submitPayment({bool printPdf = false}) async {
    if (_selectedFarmerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a farmer.'.tr), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final summary = ref.read(bonusCalculationProvider).value;
    final farmer = summary?.farmersSummary.firstWhere(
      (f) => f.farmerId == _selectedFarmerId,
      orElse: () => throw Exception('Farmer summary not found'),
    );
    if (farmer == null) return;

    final payAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (payAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment amount must be greater than zero.'.tr), backgroundColor: Colors.red),
      );
      return;
    }

    if (payAmount > (farmer.remainingBonus + 0.01)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${"Cannot pay more than remaining bonus".tr} (₹ ${farmer.remainingBonus.toStringAsFixed(2)}).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final dateRange = ref.read(bonusDateRangeProvider);
    final previousPaid = farmer.paidAmount;
    final totalPaidNew = previousPaid + payAmount;
    final newRemaining = (farmer.totalBonus - totalPaidNew).clamp(0.0, double.infinity);

    final txn = BonusTransaction(
      id: OfflineDbHelper.generateId(),
      farmerId: farmer.farmerId,
      farmerName: farmer.farmerName,
      farmerNo: farmer.farmerNo,
      animalType: farmer.animalType,
      fromDate: dateRange.fromDate,
      toDate: dateRange.toDate,
      milkQuantity: farmer.totalMilk,
      bonusRate: farmer.displayRate,
      totalBonus: farmer.totalBonus,
      previousPaid: previousPaid,
      paidAmount: payAmount,
      totalPaid: totalPaidNew,
      remainingBonus: newRemaining,
      paymentDate: DateFormat('yyyy-MM-dd').format(_paymentDate),
      paymentMode: _paymentMode,
      transactionNumber: _txnNoController.text.trim().isEmpty ? null : _txnNoController.text.trim(),
      remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    setState(() => _isSaving = true);
    try {
      await ref.read(bonusTransactionsProvider.notifier).recordPayment(txn);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('${"Bonus payment".tr} (₹ ${payAmount.toStringAsFixed(2)}) ${"recorded!".tr}'),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }

      if (printPdf) {
        final settings = ref.read(settingsProvider).value;
        await BonusPdfService.printReceipt(txn: txn, settings: settings);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save payment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final summaryAsync = ref.watch(bonusCalculationProvider);
    final dateRange = ref.watch(bonusDateRangeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Pay Bonus'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (summary) {
          final farmers = summary.farmersSummary;

          // Auto-select if requested and not yet populated
          if (_selectedFarmerId != null && _amountController.text.isEmpty) {
            final f = farmers.where((x) => x.farmerId == _selectedFarmerId).firstOrNull;
            if (f != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _onFarmerSelected(f);
              });
            }
          }

          final currentFarmer = farmers.where((f) => f.farmerId == _selectedFarmerId).firstOrNull;
          final payAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
          final prevPaid = currentFarmer?.paidAmount ?? 0.0;
          final totalBonus = currentFarmer?.totalBonus ?? 0.0;
          final newPaid = prevPaid + payAmount;
          final afterRemaining = (totalBonus - newPaid).clamp(0.0, double.infinity);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Filter & Search Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bonus Period: '.tr,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                '${dateRange.fromFormatted} to ${dateRange.toFormatted}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                              ),
                            ),
                          ],
                        ),
                        // Search Farmer dropdown / autocomplete
                        SizedBox(
                          width: 320,
                          child: Autocomplete<BonusFarmerSummary>(
                            displayStringForOption: (option) => option.farmerName,
                            initialValue: TextEditingValue(text: currentFarmer?.farmerName ?? ''),
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return farmers;
                              }
                              return farmers.where((f) =>
                                  f.farmerName.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                  (f.farmerNo?.toLowerCase().contains(textEditingValue.text.toLowerCase()) ?? false));
                            },
                            onSelected: _onFarmerSelected,
                            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  hintText: 'Search Farmer...'.tr,
                                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF2563EB)),
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (currentFarmer == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Search and select a farmer to view the report.'.tr,
                            style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Two Cards Row: Farmer Details & Milk/Bonus Details
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 750;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _buildFarmerDetailsCard(currentFarmer),
                              const SizedBox(height: 16),
                              _buildMilkBonusDetailsCard(currentFarmer),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildFarmerDetailsCard(currentFarmer)),
                            const SizedBox(width: 20),
                            Expanded(child: _buildMilkBonusDetailsCard(currentFarmer)),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Bottom Section: Payment Details Form & After Payment Summary
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 750;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _buildPaymentDetailsForm(currentFarmer),
                              const SizedBox(height: 16),
                              _buildAfterPaymentCard(totalBonus, newPaid, afterRemaining),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: _buildPaymentDetailsForm(currentFarmer)),
                            const SizedBox(width: 20),
                            Expanded(flex: 4, child: _buildAfterPaymentCard(totalBonus, newPaid, afterRemaining)),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons Row
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 18),
                          label: _isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Save Payment'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isSaving ? null : () => _submitPayment(printPdf: false),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: Text('Save & Generate PDF'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isSaving ? null : () => _submitPayment(printPdf: true),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Cancel'.tr),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFarmerDetailsCard(BonusFarmerSummary farmer) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Farmer Details'.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.person, size: 30, color: Color(0xFF1E40AF)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmer.farmerName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      farmer.farmerNo ?? 'ID: --',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: farmer.animalType == 'Cow' ? Colors.amber.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: farmer.animalType == 'Cow' ? Colors.amber.shade200 : Colors.blue.shade200),
                      ),
                      child: Text(
                        farmer.animalType.tr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: farmer.animalType == 'Cow' ? Colors.brown.shade800 : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          if (farmer.mobile != null && farmer.mobile!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(farmer.mobile!, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                ],
              ),
            ),
          if (farmer.address != null && farmer.address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      farmer.address!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMilkBonusDetailsCard(BonusFarmerSummary farmer) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details'.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          _buildDetailRow('Milk (L)'.tr, '${farmer.totalMilk.toStringAsFixed(1)} L'),
          _buildDetailRow('Bonus Per Liter (₹)'.tr, '₹ ${farmer.displayRate.toStringAsFixed(2)} / L'),
          _buildDetailRow('Total Bonus'.tr, '₹ ${farmer.totalBonus.toStringAsFixed(2)}', isBold: true),
          _buildDetailRow('Paid Amount'.tr, '₹ ${farmer.paidAmount.toStringAsFixed(2)}', color: const Color(0xFF16A34A)),
          const Divider(height: 12, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            'Remaining'.tr,
            '₹ ${farmer.remainingBonus.toStringAsFixed(2)}',
            isBold: true,
            color: farmer.remainingBonus > 0 ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsForm(BonusFarmerSummary farmer) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bonus Payment'.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),

          // Bonus Amount to Pay
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${"Bonus Amount".tr} *', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  helperText: '${"Remaining".tr}: ₹ ${farmer.remainingBonus.toStringAsFixed(2)}',
                  helperStyle: const TextStyle(color: Color(0xFF64748B)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount to pay';
                  final amt = double.tryParse(val.trim());
                  if (amt == null || amt <= 0) return 'Amount must be > 0';
                  if (amt > (farmer.remainingBonus + 0.01)) return 'Cannot exceed remaining bonus';
                  return null;
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Payment Mode & Payment Date Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Mode'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _paymentMode,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                        DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMode = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _paymentDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFF8FAFC),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd-MM-yyyy').format(_paymentDate), style: const TextStyle(fontSize: 13)),
                            const Icon(Icons.calendar_month, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Transaction No & Remarks
          TextFormField(
            controller: _txnNoController,
            decoration: InputDecoration(
              labelText: 'Transaction No / Ref'.tr,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _remarksController,
            decoration: InputDecoration(
              labelText: 'Remarks'.tr,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAfterPaymentCard(double totalBonus, double newPaid, double afterRemaining) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details'.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          _buildDetailRow('Total Bonus'.tr, '₹ ${totalBonus.toStringAsFixed(2)}'),
          _buildDetailRow('Paid Amount'.tr, '₹ ${newPaid.toStringAsFixed(2)}', isBold: true, color: const Color(0xFF16A34A)),
          const Divider(height: 16, color: Color(0xFFCBD5E1)),
          _buildDetailRow(
            'Remaining'.tr,
            '₹ ${afterRemaining.toStringAsFixed(2)}',
            isBold: true,
            color: afterRemaining > 0 ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
