import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/payment_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/farmer_provider.dart';
import '../providers/supplier_provider.dart';
import '../models/flutter_models.dart';
import '../services/translations.dart';
import '../providers/language_provider.dart';
import '../providers/display_mode_provider.dart';

class PaymentParty {
  final String id;
  final String name;
  final String type;
  final double balance;
  PaymentParty({required this.id, required this.name, required this.type, required this.balance});
  
  @override
  String toString() => '$name (${type.tr}) - ${"Bal:".tr} ₹$balance';
}

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _searchHistoryCtrl = TextEditingController();
  
  String _paymentType = 'In';
  String _paymentMode = 'Cash';
  PaymentParty? _selectedParty;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  
  String _searchQuery = '';
  DateTime? _historyDateFilter;
  String? _editingId;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _remarksCtrl.dispose();
    _searchHistoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedParty == null) {
      if (_selectedParty == null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a party'.tr)));
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final amt = double.parse(_amountCtrl.text);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      if (_editingId != null) {
        await ref.read(paymentProvider.notifier).updatePayment(
          _editingId!,
          amt,
          _remarksCtrl.text,
          dateStr,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment updated successfully'.tr)));
      } else {
        await ref.read(paymentProvider.notifier).addPayment(
          partyType: _selectedParty!.type,
          partyId: _selectedParty!.id,
          paymentType: _paymentType,
          amount: amt,
          paymentMode: _paymentMode,
          referenceNo: _refCtrl.text.isEmpty ? null : _refCtrl.text,
          remarks: _remarksCtrl.text.isEmpty ? null : _remarksCtrl.text,
          paymentDate: dateStr,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment recorded successfully'.tr)));
      }
      
      // Reset Form
      _amountCtrl.clear();
      _refCtrl.clear();
      _remarksCtrl.clear();
      setState(() {
        _selectedParty = null;
        _paymentType = 'In';
        _editingId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _editPayment(Payment p) {
    setState(() {
      _editingId = p.id;
      _amountCtrl.text = p.amount.toString();
      _remarksCtrl.text = p.remarks ?? '';
      _paymentMode = p.paymentMode;
      _paymentType = p.paymentType;
      
      // Reconstruct the selected party so the UI can display their name
      _selectedParty = PaymentParty(
        id: p.farmerId ?? p.customerId ?? p.supplierId ?? '',
        name: p.partyName ?? 'Unknown'.tr,
        type: p.partyType,
        balance: 0.0,
      );
      try {
        _selectedDate = DateTime.parse(p.paymentDate);
      } catch (e) {
        _selectedDate = DateTime.now();
      }
    });
  }

  Future<void> _deletePayment(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Payment'.tr),
        content: Text('Are you sure you want to delete this payment?'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL'.tr)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('DELETE'.tr, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await ref.read(paymentProvider.notifier).deletePayment(id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment deleted'.tr)));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final displayMode = ref.watch(displayModeProvider);
    final paymentsAsync = ref.watch(paymentProvider);
    final customersAsync = ref.watch(customersProvider);
    final farmersAsync = ref.watch(farmersProvider);
    final suppliersAsync = ref.watch(supplierProvider);
    
    final isMobile = displayMode == DisplayMode.mobile || MediaQuery.of(context).size.width < 800;

    List<PaymentParty> allParties = [];
    if (customersAsync.value != null) {
      allParties.addAll(customersAsync.value!.map((c) => PaymentParty(id: c.id, name: c.name, type: 'Customer', balance: c.currentBalance)));
    }
    if (farmersAsync.value != null) {
      allParties.addAll(farmersAsync.value!.map((f) => PaymentParty(id: f.id, name: f.name, type: 'Farmer', balance: f.currentBalance)));
    }
    if (suppliersAsync.value != null) {
      allParties.addAll(suppliersAsync.value!.map((s) => PaymentParty(id: s.id, name: s.name, type: 'Supplier', balance: s.currentBalance)));
    }

    Widget formCard = Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_editingId == null ? 'Record New Payment'.tr : 'Edit Payment'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  if (_editingId != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _editingId = null;
                          _amountCtrl.clear();
                          _remarksCtrl.clear();
                        });
                      },
                      child: Text('Cancel Edit'.tr),
                    )
                ],
              ),
              const Divider(height: 32),
              
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 350,
                    child: _editingId != null 
                      ? TextFormField(
                          initialValue: '${_selectedParty?.name} (${_selectedParty?.type.tr})',
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Search Party (Name) *'.tr,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      : Autocomplete<PaymentParty>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable<PaymentParty>.empty();
                            return allParties.where((party) => party.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          displayStringForOption: (PaymentParty option) => '${option.name} (${option.type.tr})',
                          onSelected: (PaymentParty selection) {
                            setState(() {
                              _selectedParty = selection;
                              if (selection.type == 'Farmer' || selection.type == 'Supplier') _paymentType = 'Out';
                            });
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Search Party (Name) *'.tr,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                suffixIcon: const Icon(Icons.search),
                              ),
                              validator: (v) => _selectedParty == null ? 'Required'.tr : null,
                            );
                          },
                        ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _paymentType,
                      decoration: InputDecoration(labelText: 'Type (In/Out) *'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      items: [
                        DropdownMenuItem(value: 'In', child: Text('Payment In (Received)'.tr, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'Out', child: Text('Payment Out (Paid)'.tr, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      ],
                      onChanged: _editingId == null ? (val) => setState(() => _paymentType = val!) : null,
                    ),
                  ),
                ],
              ),
              if (_selectedParty != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text('${'Selected:'.tr} ${_selectedParty!.name} (${_selectedParty!.type.tr})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${'Current Ledger Balance:'.tr} ₹${_selectedParty!.balance.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: _selectedParty!.balance > 0 ? Colors.red : Colors.green)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date'.tr,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 250,
                    child: TextFormField(
                      controller: _amountCtrl,
                      decoration: InputDecoration(labelText: 'Amount (₹) *'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v!.isEmpty ? 'Required'.tr : null,
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _paymentMode,
                      decoration: InputDecoration(labelText: 'Payment Mode'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      items: ['Cash', 'UPI', 'Bank', 'Cheque'].map((m) => DropdownMenuItem(value: m, child: Text(m.tr))).toList(),
                      onChanged: (val) => setState(() => _paymentMode = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 250,
                    child: TextFormField(
                      controller: _refCtrl,
                      enabled: _editingId == null,
                      decoration: InputDecoration(labelText: 'Reference Number (e.g. UTR)'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 250,
                    child: TextFormField(
                      controller: _remarksCtrl,
                      decoration: InputDecoration(labelText: 'Remarks'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _editingId != null ? Colors.orange : (_paymentType == 'In' ? Colors.green : Colors.red.shade600), 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.account_balance_wallet),
                  label: Text(_isSaving ? 'SAVING...'.tr : (_editingId != null ? 'UPDATE PAYMENT'.tr : 'RECORD PAYMENT'.tr), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget historyWidget({bool isScrollable = true}) {
      return Container(
        color: Colors.grey.shade50,
        height: isScrollable ? double.infinity : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: isScrollable ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.all(16.0), child: Text('Recent Transactions'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchHistoryCtrl,
                      decoration: InputDecoration(
                        labelText: 'Search History by Name'.tr,
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _historyDateFilter ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _historyDateFilter = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: _historyDateFilter != null ? Colors.blue : Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: _historyDateFilter != null ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                      ),
                      child: Icon(Icons.calendar_today, color: _historyDateFilter != null ? Colors.blue : Colors.grey.shade700),
                    ),
                  ),
                  if (_historyDateFilter != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: () => setState(() => _historyDateFilter = null),
                    )
                  ]
                ],
              ),
            ),
            const SizedBox(height: 8),
            paymentsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator())),
              error: (e, s) => Center(child: Text('Error: $e')),
              data: (payments) {
                final filtered = payments.where((p) {
                  final name = (p.partyName ?? '').toLowerCase();
                  final matchesName = name.contains(_searchQuery.toLowerCase());
                  
                  bool matchesDate = true;
                  if (_historyDateFilter != null) {
                    final filterStr = DateFormat('yyyy-MM-dd').format(_historyDateFilter!);
                    matchesDate = p.paymentDate == filterStr;
                  }
                  
                  return matchesName && matchesDate;
                }).toList();
                
                if (filtered.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No recent payments'.tr)));
                return ListView.builder(
                  shrinkWrap: !isScrollable,
                  physics: isScrollable ? null : const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    final isPaymentIn = p.paymentType == 'In';
                    final color = isPaymentIn ? Colors.green : Colors.red;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: color.withOpacity(0.12),
                                  child: Icon(
                                    isPaymentIn ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    p.partyName ?? 'Unknown (${p.partyType.tr})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${p.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 46.0),
                                  child: Text(
                                    '${p.paymentDate} • ${p.paymentMode.tr}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                      tooltip: 'Edit'.tr,
                                      onPressed: () {
                                        _editPayment(p);
                                        if (isMobile) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Editing payment for ${p.partyName}'.tr),
                                              duration: const Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                      tooltip: 'Delete'.tr,
                                      onPressed: () => _deletePayment(p.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Payments & Ledgers'.tr, style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: isMobile
          ? SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: formCard,
                  ),
                  const SizedBox(height: 16),
                  historyWidget(isScrollable: false),
                ],
              ),
            )
          : Flex(
              direction: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: formCard,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: historyWidget(isScrollable: true),
                ),
              ],
            ),
    );
  }
}
