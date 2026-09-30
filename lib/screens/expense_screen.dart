import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/language_provider.dart';
import '../providers/display_mode_provider.dart';
import '../services/translations.dart';

class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});

  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  
  String _category = 'Operations';
  String _paymentMode = 'Cash';
  bool _isSaving = false;

  final List<String> _categories = ['Operations', 'Maintenance', 'Salaries', 'Transport', 'Utilities', 'Other'];
  final List<String> _paymentModes = ['Cash', 'Bank Transfer', 'UPI', 'Cheque'];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    try {
      await ref.read(expenseProvider.notifier).addExpense(
        category: _category,
        description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
        amount: double.parse(_amountCtrl.text),
        paymentMode: _paymentMode,
        remarks: _remarksCtrl.text.isEmpty ? null : _remarksCtrl.text,
      );
      
      _amountCtrl.clear();
      _descCtrl.clear();
      _remarksCtrl.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expense Saved'.tr)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final displayMode = ref.watch(displayModeProvider);
    final isMobile = displayMode == DisplayMode.mobile || MediaQuery.of(context).size.width < 800;
    final notifier = ref.watch(expenseProvider.notifier);
    final expensesAsync = ref.watch(expenseProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Expenses'.tr, style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, color: Colors.blue),
            label: Text(notifier.currentDate, style: const TextStyle(color: Colors.blue)),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(notifier.currentDate),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                notifier.setDate(DateFormat('yyyy-MM-dd').format(date));
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Flex(
        direction: isMobile ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: isMobile ? 0 : 2,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add Expense'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                        const Divider(height: 32),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isMobile ? double.infinity : (MediaQuery.of(context).size.width / 2 - 40),
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(labelText: 'Category *'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                value: _category,
                                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.tr))).toList(),
                                onChanged: (val) => setState(() => _category = val!),
                              ),
                            ),
                            SizedBox(
                              width: isMobile ? double.infinity : (MediaQuery.of(context).size.width / 2 - 60),
                              child: TextFormField(
                                controller: _amountCtrl,
                                decoration: InputDecoration(labelText: 'Amount (₹) *'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: TextInputType.number,
                                validator: (v) => v!.isEmpty ? 'Required'.tr : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descCtrl,
                          decoration: InputDecoration(labelText: 'Description / Purpose'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isMobile ? double.infinity : (MediaQuery.of(context).size.width / 2 - 40),
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(labelText: 'Payment Mode'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                value: _paymentMode,
                                items: _paymentModes.map((c) => DropdownMenuItem(value: c, child: Text(c.tr))).toList(),
                                onChanged: (val) => setState(() => _paymentMode = val!),
                              ),
                            ),
                            SizedBox(
                              width: isMobile ? double.infinity : (MediaQuery.of(context).size.width / 2 - 60),
                              child: TextFormField(
                                controller: _remarksCtrl,
                                decoration: InputDecoration(labelText: 'Remarks / Ref No.'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
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
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check_circle),
                            label: Text(_isSaving ? 'SAVING...'.tr : 'SAVE EXPENSE'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          Expanded(
            flex: isMobile ? 1 : 1,
            child: Container(
              color: Colors.grey.shade50,
              height: isMobile ? 400 : double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.all(16.0), child: Text('Today\'s Expenses'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  Expanded(
                    child: expensesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Error: $e')),
                      data: (expenses) {
                        if (expenses.isEmpty) return Center(child: Text('No expenses recorded today'.tr));
                        return ListView.builder(
                          itemCount: expenses.length,
                          itemBuilder: (context, index) {
                            final e = expenses[index];
                            return ListTile(
                              leading: CircleAvatar(backgroundColor: Colors.red.shade50, child: const Icon(Icons.money_off, color: Colors.red)),
                              title: Text(e.category.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(e.description ?? e.paymentMode.tr),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${e.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.delete, color: Colors.grey, size: 18),
                                    onPressed: () => notifier.deleteExpense(e.id),
                                  ),
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
