import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/flutter_models.dart';
import '../providers/staff_provider.dart';
import '../services/translations.dart';
import '../providers/language_provider.dart';
import '../providers/display_mode_provider.dart';

class StaffLedgerScreen extends ConsumerStatefulWidget {
  final Staff staff;
  const StaffLedgerScreen({super.key, required this.staff});

  @override
  ConsumerState<StaffLedgerScreen> createState() => _StaffLedgerScreenState();
}

class _StaffLedgerScreenState extends ConsumerState<StaffLedgerScreen> {
  final _amountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String _transactionType = 'Payment';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(staffTransactionProvider.notifier).loadTransactions(widget.staff.id));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    if (_amountCtrl.text.isEmpty) return;
    
    setState(() => _isSaving = true);
    try {
      await ref.read(staffTransactionProvider.notifier).addTransaction(
        staffId: widget.staff.id,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        type: _transactionType,
        amount: double.parse(_amountCtrl.text),
        remarks: _remarksCtrl.text.isEmpty ? null : _remarksCtrl.text,
      );
      
      _amountCtrl.clear();
      _remarksCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction recorded successfully')));
        Navigator.pop(context); // Close bottom sheet
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddTransactionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Column(
                 mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Transaction'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Type'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    value: _transactionType,
                    items: [
                      DropdownMenuItem(value: 'Salary Credit', child: Text('Salary Credit'.tr)),
                      DropdownMenuItem(value: 'Advance', child: Text('Advance'.tr)),
                      DropdownMenuItem(value: 'Payment', child: Text('Payment'.tr)),
                    ],
                    onChanged: (v) => setModalState(() => _transactionType = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: InputDecoration(labelText: 'Amount (₹) *'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _remarksCtrl,
                    decoration: InputDecoration(labelText: 'Remarks'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submitTransaction,
                      style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: Text(_isSaving ? 'SAVING...'.tr : 'RECORD'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final displayMode = ref.watch(displayModeProvider);
    final isMobile = displayMode == DisplayMode.mobile;
    final txAsync = ref.watch(staffTransactionProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    // We fetch updated staff to show live balance
    final staffListAsync = ref.watch(staffProvider);
    final updatedStaff = staffListAsync.value?.firstWhere((s) => s.id == widget.staff.id, orElse: () => widget.staff) ?? widget.staff;

    return Scaffold(
      appBar: AppBar(
        title: Text('${updatedStaff.name} - ${"Staff Ledger".tr}'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionModal,
        icon: const Icon(Icons.add),
        label: Text('Add Entry'.tr),
      ),
      body: Column(
        children: [
          // Header Stats
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            color: primaryColor.withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(updatedStaff.name, style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${updatedStaff.role ?? "Staff".tr} | ${updatedStaff.salaryType}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Current Balance'.tr, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('₹${updatedStaff.balance.toStringAsFixed(2)}', style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold, color: updatedStaff.balance < 0 ? Colors.red : Colors.green)),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Transaction List
          Expanded(
            child: txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('${"Error".tr}: $e')),
              data: (transactions) {
                if (transactions.isEmpty) return Center(child: Text('No transactions found.'.tr));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isCredit = tx.type == 'Salary Credit';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCredit ? Colors.green.shade50 : Colors.red.shade50,
                          child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? Colors.green : Colors.red),
                        ),
                        title: Text(tx.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${DateFormat('dd-MMM-yyyy').format(DateTime.parse(tx.transactionDate))}${tx.remarks != null && tx.remarks!.isNotEmpty ? ' | ${tx.remarks}' : ''}'),
                        trailing: Text(
                          '${isCredit ? '+' : '-'} ₹${tx.amount.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCredit ? Colors.green : Colors.red),
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}
