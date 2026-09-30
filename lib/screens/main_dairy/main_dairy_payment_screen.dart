import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/flutter_models.dart';
import '../../providers/main_dairy_provider.dart';
import '../../providers/main_dairy_payment_provider.dart';
import '../../services/translations.dart';
import '../../providers/language_provider.dart';

class MainDairyPaymentScreen extends ConsumerStatefulWidget {
  const MainDairyPaymentScreen({super.key});

  @override
  ConsumerState<MainDairyPaymentScreen> createState() => _MainDairyPaymentScreenState();
}

class _MainDairyPaymentScreenState extends ConsumerState<MainDairyPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dairyNoCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _searchHistoryCtrl = TextEditingController();
  TextEditingController? _autocompleteCtrl;

  final _dairyNoFocus = FocusNode();
  final _amountFocus = FocusNode();

  String _paymentType = 'In';
  String _paymentMode = 'Bank Transfer';
  MainDairy? _selectedDairy;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  String _historyQuery = '';
  DateTime? _historyDateFilter;
  String? _editingId;
  double _editingOldAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _dairyNoFocus.addListener(() {
      if (!_dairyNoFocus.hasFocus && _dairyNoCtrl.text.isNotEmpty) {
        ref.read(mainDairyProvider.future).then((dairies) {
          if (mounted) _onDairyNoEntered(_dairyNoCtrl.text, dairies);
        });
      }
    });
  }

  @override
  void dispose() {
    _dairyNoCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _remarksCtrl.dispose();
    _searchHistoryCtrl.dispose();
    _dairyNoFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _onDairyNoEntered(String noStr, List<MainDairy> dairies) {
    final clean = noStr.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final no = int.tryParse(clean);
    if (no == null) return;

    try {
      final dairy = dairies.firstWhere((d) => d.dairyNo == no);
      _selectDairy(dairy);
      _amountFocus.requestFocus();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Main Dairy ID not found')),
      );
      _dairyNoCtrl.clear();
      _dairyNoFocus.requestFocus();
    }
  }

  void _selectDairy(MainDairy dairy) {
    setState(() {
      _selectedDairy = dairy;
      final formattedNo = dairy.dairyNo != null ? dairy.dairyNo.toString().padLeft(3, '0') : '';
      _dairyNoCtrl.text = formattedNo;
      _autocompleteCtrl?.text = '#$formattedNo - ${dairy.name}';
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickHistoryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _historyDateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _historyDateFilter = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedDairy == null) {
      if (_selectedDairy == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Main Dairy')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final amt = double.parse(_amountCtrl.text.trim());
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      if (_editingId != null) {
        await ref.read(mainDairyPaymentProvider.notifier).updatePayment(
          id: _editingId!,
          mainDairyId: _selectedDairy!.id,
          oldAmount: _editingOldAmount,
          newAmount: amt,
          paymentMode: _paymentMode,
          paymentDate: dateStr,
          referenceNo: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Main Dairy payment updated successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        await ref.read(mainDairyPaymentProvider.notifier).addPayment(
          mainDairyId: _selectedDairy!.id,
          amount: amt,
          paymentMode: _paymentMode,
          paymentDate: dateStr,
          referenceNo: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Main Dairy payment recorded successfully!'), backgroundColor: Colors.green),
          );
        }
      }

      _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    _amountCtrl.clear();
    _refCtrl.clear();
    _remarksCtrl.clear();
    _dairyNoCtrl.clear();
    _autocompleteCtrl?.clear();
    setState(() {
      _selectedDairy = null;
      _paymentType = 'In';
      _editingId = null;
      _editingOldAmount = 0.0;
    });
  }

  void _editPayment(MainDairyPayment p, List<MainDairy> dairies) {
    setState(() {
      _editingId = p.id;
      _editingOldAmount = p.amount;
      _amountCtrl.text = p.amount.toStringAsFixed(2);
      _refCtrl.text = p.referenceNo ?? '';
      _remarksCtrl.text = p.remarks ?? '';
      _paymentMode = p.paymentMode;

      try {
        _selectedDate = DateTime.parse(p.paymentDate);
      } catch (_) {
        _selectedDate = DateTime.now();
      }

      try {
        _selectedDairy = dairies.firstWhere((d) => d.id == p.mainDairyId);
      } catch (_) {
        _selectedDairy = MainDairy(
          id: p.mainDairyId,
          name: p.dairyName ?? 'Main Dairy',
          dairyNo: p.dairyNo,
        );
      }

      final formattedNo = _selectedDairy?.dairyNo != null ? _selectedDairy!.dairyNo.toString().padLeft(3, '0') : '';
      _dairyNoCtrl.text = formattedNo;
      _autocompleteCtrl?.text = '#$formattedNo - ${_selectedDairy?.name ?? ""}';
    });
    _amountFocus.requestFocus();
  }

  Future<void> _deletePayment(MainDairyPayment p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Record'),
        content: Text('Are you sure you want to delete payment of ₹${p.amount.toStringAsFixed(2)} for ${p.dairyName ?? "Main Dairy"}?\n\nThis will restore their receivable balance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(mainDairyPaymentProvider.notifier).deletePayment(p.id, p.mainDairyId, p.amount);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment deleted and receivable balance updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final paymentsAsync = ref.watch(mainDairyPaymentProvider);
    final dairiesAsync = ref.watch(mainDairyProvider);
    final dairies = dairiesAsync.value ?? [];

    final isNarrow = MediaQuery.of(context).size.width < 900;

    final formCard = _buildFormCard(context, isNarrow, dairies);
    final historyCard = _buildHistorySection(context, isNarrow, paymentsAsync, dairies);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Main Dairy Payments & Ledgers'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.indigo),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(mainDairyPaymentProvider);
              ref.invalidate(mainDairyProvider);
            },
          ),
        ],
      ),
      body: isNarrow
          ? SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: formCard,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: historyCard,
                  ),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: formCard,
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: historyCard,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFormCard(BuildContext context, bool isNarrow, List<MainDairy> dairies) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.indigo.shade50,
                                  child: Icon(
                                    _editingId == null ? Icons.payments : Icons.edit,
                                    color: Colors.indigo,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _editingId == null ? 'Record Main Dairy Payment'.tr : 'Edit Main Dairy Payment'.tr,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                                ),
                              ],
                            ),
                            if (_editingId != null)
                              TextButton.icon(
                                onPressed: _resetForm,
                                icon: const Icon(Icons.close, size: 16),
                                label: Text('Cancel Edit'.tr),
                              )
                          ],
                        ),
                        const Divider(height: 24),

                        // Main Dairy Selection (D. ID + Search Autocomplete)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 90,
                              child: TextFormField(
                                controller: _dairyNoCtrl,
                                focusNode: _dairyNoFocus,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'D. ID'.tr,
                                  hintText: '001',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                onFieldSubmitted: (val) => _onDairyNoEntered(val, dairies),
                              ),
                            ),
                            SizedBox(
                              width: isNarrow ? double.infinity : 320,
                              child: Autocomplete<MainDairy>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) return const Iterable<MainDairy>.empty();
                                  final q = textEditingValue.text.toLowerCase();
                                  return dairies.where((d) {
                                    final noStr = d.dairyNo != null ? d.dairyNo.toString().padLeft(3, '0') : '';
                                    return d.name.toLowerCase().contains(q) || noStr.contains(q);
                                  });
                                },
                                displayStringForOption: (MainDairy d) {
                                  final noStr = d.dairyNo != null ? '#${d.dairyNo.toString().padLeft(3, '0')} - ' : '';
                                  return '$noStr${d.name}';
                                },
                                onSelected: (MainDairy selection) => _selectDairy(selection),
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  _autocompleteCtrl = controller;
                                  if (_selectedDairy != null && controller.text.isEmpty) {
                                    final noStr = _selectedDairy!.dairyNo != null ? '#${_selectedDairy!.dairyNo.toString().padLeft(3, '0')} - ' : '';
                                    controller.text = '$noStr${_selectedDairy!.name}';
                                  }
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Search Main Dairy (Name/No) *'.tr,
                                      hintText: 'Type 001 or Sonai...',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      suffixIcon: const Icon(Icons.search),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    validator: (v) => _selectedDairy == null ? 'Please select a Main Dairy'.tr : null,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        // Selected Main Dairy Info Card
                        if (_selectedDairy != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.indigo.shade100),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.indigo.shade100,
                                  child: const Icon(Icons.business, color: Colors.indigo),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '#${_selectedDairy!.dairyNo != null ? _selectedDairy!.dairyNo.toString().padLeft(3, '0') : '---'} ${_selectedDairy!.name}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_selectedDairy!.village != null && _selectedDairy!.village!.isNotEmpty ? _selectedDairy!.village : (_selectedDairy!.address ?? "No Village")} | 📞 ${_selectedDairy!.mobile ?? "N/A"}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Receivable Bal'.tr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹ ${_selectedDairy!.currentBalance.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _selectedDairy!.currentBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Date Picker & Payment Type
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isNarrow ? double.infinity : 220,
                              child: InkWell(
                                onTap: _pickDate,
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Payment Date *'.tr,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.calendar_today, size: 20),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: isNarrow ? double.infinity : 220,
                              child: DropdownButtonFormField<String>(
                                value: _paymentType,
                                decoration: InputDecoration(
                                  labelText: 'Payment Type *'.tr,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'In',
                                    child: Text('Payment In (Received)'.tr, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Out',
                                    child: Text('Payment Out (Adjustment)'.tr, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                                onChanged: (v) => setState(() => _paymentType = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Amount & Payment Mode
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isNarrow ? double.infinity : 220,
                              child: TextFormField(
                                controller: _amountCtrl,
                                focusNode: _amountFocus,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Amount Received (₹) *'.tr,
                                  hintText: '0.00',
                                  prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Enter amount'.tr;
                                  final val = double.tryParse(v.trim());
                                  if (val == null || val <= 0) return 'Valid amount required'.tr;
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(
                              width: isNarrow ? double.infinity : 220,
                              child: DropdownButtonFormField<String>(
                                value: _paymentMode,
                                decoration: InputDecoration(
                                  labelText: 'Payment Mode *'.tr,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                items: ['Bank Transfer', 'NEFT/RTGS', 'Cheque', 'Cash', 'UPI']
                                    .map((m) => DropdownMenuItem(value: m, child: Text(m.tr)))
                                    .toList(),
                                onChanged: (v) => setState(() => _paymentMode = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Reference No & Remarks
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isNarrow ? double.infinity : 220,
                              child: TextFormField(
                                controller: _refCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Reference / UTR / Cheque No'.tr,
                                  hintText: 'e.g. UTR12345678',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: isNarrow ? double.infinity : 220,
                              child: TextFormField(
                                controller: _remarksCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Remarks / Notes'.tr,
                                  hintText: 'e.g. Milk bill payment for cycle 1',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                            icon: _isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              _editingId == null ? 'RECORD PAYMENT RECEIVED'.tr : 'UPDATE PAYMENT RECORD'.tr,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  List<MainDairyPayment> _filterPayments(List<MainDairyPayment> payments) {
    return payments.where((p) {
      if (_historyDateFilter != null) {
        final filterStr = DateFormat('yyyy-MM-dd').format(_historyDateFilter!);
        if (p.paymentDate != filterStr) return false;
      }
      if (_historyQuery.isNotEmpty) {
        final name = (p.dairyName ?? '').toLowerCase();
        final noStr = p.dairyNo != null ? p.dairyNo.toString().padLeft(3, '0') : '';
        final ref = (p.referenceNo ?? '').toLowerCase();
        final mode = p.paymentMode.toLowerCase();
        if (!name.contains(_historyQuery) && !noStr.contains(_historyQuery) && !ref.contains(_historyQuery) && !mode.contains(_historyQuery)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildSummaryBanner(int count, double totalReceived) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count Record(s) Found',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade900, fontSize: 13),
          ),
          Text(
            'Total Received: ₹ ${totalReceived.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(
    BuildContext context,
    bool isNarrow,
    AsyncValue<List<MainDairyPayment>> paymentsAsync,
    List<MainDairy> dairies,
  ) {
    Widget buildList(List<MainDairyPayment> filtered) {
      if (filtered.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No Main Dairy transactions found'.tr,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }
      return ListView.builder(
        shrinkWrap: isNarrow,
        physics: isNarrow ? const NeverScrollableScrollPhysics() : null,
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final p = filtered[index];
          final dairyNoStr = p.dairyNo != null ? '#${p.dairyNo.toString().padLeft(3, '0')} ' : '';
          final dairyTitle = '$dairyNoStr${p.dairyName ?? "Main Dairy"}';

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.green.shade50,
                child: const Icon(Icons.arrow_downward, color: Colors.green, size: 20),
              ),
              title: Text(
                dairyTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    '${p.paymentDate} | ${p.paymentMode}${p.referenceNo != null && p.referenceNo!.isNotEmpty ? " | Ref: ${p.referenceNo}" : ""}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  if (p.remarks != null && p.remarks!.isNotEmpty)
                    Text(
                      p.remarks!,
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '₹ ${p.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                    tooltip: 'Edit Payment',
                    onPressed: () => _editPayment(p, dairies),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    tooltip: 'Delete Payment',
                    onPressed: () => _deletePayment(p),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: isNarrow ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Main Dairy Transactions'.tr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            if (_historyDateFilter != null)
              TextButton.icon(
                onPressed: () => setState(() => _historyDateFilter = null),
                icon: const Icon(Icons.clear, size: 16),
                label: Text('Clear Date Filter'.tr),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Search & Date Filter Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchHistoryCtrl,
                decoration: InputDecoration(
                  hintText: 'Search History by Dairy Name / D. ID...'.tr,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchHistoryCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchHistoryCtrl.clear();
                            setState(() => _historyQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (v) => setState(() => _historyQuery = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: _pickHistoryDate,
              tooltip: 'Filter by Date',
              style: IconButton.styleFrom(
                backgroundColor: _historyDateFilter != null ? Colors.indigo.shade100 : Colors.grey.shade100,
              ),
              icon: Icon(
                Icons.calendar_month,
                color: _historyDateFilter != null ? Colors.indigo : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Transactions List
        if (isNarrow)
          paymentsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (err, st) => Center(child: Text('Error loading payments: $err')),
            data: (payments) {
              final filtered = _filterPayments(payments);
              final totalReceived = filtered.fold<double>(0.0, (sum, item) => sum + item.amount);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSummaryBanner(filtered.length, totalReceived),
                  buildList(filtered),
                ],
              );
            },
          )
        else
          Expanded(
            child: paymentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error loading payments: $err')),
              data: (payments) {
                final filtered = _filterPayments(payments);
                final totalReceived = filtered.fold<double>(0.0, (sum, item) => sum + item.amount);
                return Column(
                  children: [
                    _buildSummaryBanner(filtered.length, totalReceived),
                    Expanded(child: buildList(filtered)),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
