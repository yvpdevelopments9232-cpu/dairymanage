import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/payment_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/farmer_provider.dart';
import '../providers/supplier_provider.dart';
import '../models/flutter_models.dart';

class PaymentParty {
  final String id;
  final String name;
  final String type;
  final double balance;
  PaymentParty({required this.id, required this.name, required this.type, required this.balance});
  
  @override
  String toString() => '$name ($type) - Bal: ₹$balance';
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
      if (_selectedParty == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a party')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment updated successfully')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully')));
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
        name: p.partyName ?? 'Unknown',
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
        title: const Text('Delete Payment'),
        content: const Text('Are you sure you want to delete this payment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await ref.read(paymentProvider.notifier).deletePayment(id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment deleted')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentProvider);
    final customersAsync = ref.watch(customersProvider);
    final farmersAsync = ref.watch(farmersProvider);
    final suppliersAsync = ref.watch(supplierProvider);
    
    final isMobile = false; // Forced desktop layout as per user request

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments & Ledgers', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Flex(
        direction: isMobile ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE: Form
          Expanded(
            flex: isMobile ? 0 : 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
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
                            Text(_editingId == null ? 'Record New Payment' : 'Edit Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                            if (_editingId != null)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _editingId = null;
                                    _amountCtrl.clear();
                                    _remarksCtrl.clear();
                                  });
                                },
                                child: const Text('Cancel Edit'),
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
                                    initialValue: '${_selectedParty?.name} (${_selectedParty?.type})',
                                    enabled: false,
                                    decoration: InputDecoration(
                                      labelText: 'Search Party (Name) *',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  )
                                : Autocomplete<PaymentParty>(
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) return const Iterable<PaymentParty>.empty();
                                      return allParties.where((party) => party.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                    },
                                    displayStringForOption: (PaymentParty option) => '${option.name} (${option.type})',
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
                                          labelText: 'Search Party (Name) *',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          suffixIcon: const Icon(Icons.search),
                                        ),
                                        validator: (v) => _selectedParty == null ? 'Required' : null,
                                      );
                                    },
                                  ),
                            ),
                            SizedBox(
                              width: isMobile ? double.infinity : 200,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _paymentType,
                                decoration: InputDecoration(labelText: 'Type (In/Out) *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                items: const [
                                  DropdownMenuItem(value: 'In', child: Text('Payment In (Received)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                  DropdownMenuItem(value: 'Out', child: Text('Payment Out (Paid)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
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
                                Text('Selected: ${_selectedParty!.name} (${_selectedParty!.type})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Current Ledger Balance: ₹${_selectedParty!.balance.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: _selectedParty!.balance > 0 ? Colors.red : Colors.green)),
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
                                    labelText: 'Date',
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
                                decoration: InputDecoration(labelText: 'Amount (₹) *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            SizedBox(
                              width: isMobile ? double.infinity : 200,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _paymentMode,
                                decoration: InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                items: ['Cash', 'UPI', 'Bank', 'Cheque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
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
                                decoration: InputDecoration(labelText: 'Reference Number (e.g. UTR)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                              ),
                            ),
                            SizedBox(
                              width: isMobile ? double.infinity : 250,
                              child: TextFormField(
                                controller: _remarksCtrl,
                                decoration: InputDecoration(labelText: 'Remarks', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
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
                            label: Text(_isSaving ? 'SAVING...' : 'RECORD PAYMENT', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // RIGHT SIDE: History
          Expanded(
            flex: isMobile ? 1 : 1,
            child: Container(
              color: Colors.grey.shade50,
              height: isMobile ? 500 : double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.all(16.0), child: Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchHistoryCtrl,
                            decoration: InputDecoration(
                              labelText: 'Search History by Name',
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
                  Expanded(
                    child: paymentsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
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
                        
                        if (filtered.isEmpty) return const Center(child: Text('No recent payments'));
                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            final isPaymentIn = p.paymentType == 'In';
                            final color = isPaymentIn ? Colors.green : Colors.red;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.1),
                                child: Icon(isPaymentIn ? Icons.arrow_downward : Icons.arrow_upward, color: color),
                              ),
                              title: Text(p.partyName ?? 'Unknown (${p.partyType})', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${p.paymentDate} | ${p.paymentMode}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('₹${p.amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(width: 8),
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editPayment(p)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deletePayment(p.id)),
                                ],
                              ),
                            );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
