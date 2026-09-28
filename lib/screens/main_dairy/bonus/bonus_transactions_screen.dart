import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/flutter_models.dart';
import '../../../providers/bonus_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/bonus_pdf_service.dart';

class BonusTransactionsScreen extends ConsumerStatefulWidget {
  const BonusTransactionsScreen({super.key});

  @override
  ConsumerState<BonusTransactionsScreen> createState() => _BonusTransactionsScreenState();
}

class _BonusTransactionsScreenState extends ConsumerState<BonusTransactionsScreen> {
  late TextEditingController _fromDateController;
  late TextEditingController _toDateController;
  final TextEditingController _searchController = TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final range = ref.read(bonusDateRangeProvider);
    _fromDate = DateTime.tryParse(range.fromDate) ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    _toDate = DateTime.tryParse(range.toDate) ?? DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
    _fromDateController = TextEditingController(text: DateFormat('dd-MM-yyyy').format(_fromDate!));
    _toDateController = TextEditingController(text: DateFormat('dd-MM-yyyy').format(_toDate!));
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          _fromDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        } else {
          _toDate = picked;
          _toDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        }
      });
    }
  }

  void _applyFilter() {
    if (_fromDate != null && _toDate != null) {
      final f = DateFormat('yyyy-MM-dd').format(_fromDate!);
      final t = DateFormat('yyyy-MM-dd').format(_toDate!);
      ref.read(bonusDateRangeProvider.notifier).setRange(f, t);
    }
  }

  Future<void> _confirmDelete(BonusTransaction txn) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Transaction'),
          ],
        ),
        content: Text('Are you sure you want to delete the payment of ₹ ${txn.paidAmount.toStringAsFixed(2)} for ${txn.farmerName}?\nThis will restore the remaining bonus balance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(bonusTransactionsProvider.notifier).deletePayment(txn.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bonus transaction deleted.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editTransaction(BonusTransaction txn) async {
    final amountController = TextEditingController(text: txn.paidAmount.toStringAsFixed(2));
    final remarksController = TextEditingController(text: txn.remarks ?? '');
    String selectedMode = txn.paymentMode;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Payment - ${txn.farmerName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Paid Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedMode,
                decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedMode = val);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      final newAmt = double.tryParse(amountController.text.trim()) ?? txn.paidAmount;
      final newTotalPaid = txn.previousPaid + newAmt;
      final newRemaining = (txn.totalBonus - newTotalPaid).clamp(0.0, double.infinity);

      final updatedTxn = BonusTransaction(
        id: txn.id,
        farmerId: txn.farmerId,
        farmerName: txn.farmerName,
        farmerNo: txn.farmerNo,
        animalType: txn.animalType,
        fromDate: txn.fromDate,
        toDate: txn.toDate,
        milkQuantity: txn.milkQuantity,
        bonusRate: txn.bonusRate,
        totalBonus: txn.totalBonus,
        previousPaid: txn.previousPaid,
        paidAmount: newAmt,
        totalPaid: newTotalPaid,
        remainingBonus: newRemaining,
        paymentDate: txn.paymentDate,
        paymentMode: selectedMode,
        transactionNumber: txn.transactionNumber,
        remarks: remarksController.text.trim(),
        createdAt: txn.createdAt,
      );

      await ref.read(bonusTransactionsProvider.notifier).updatePayment(updatedTxn);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated!'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(bonusTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb
            Row(
              children: [
                const Icon(Icons.workspace_premium, size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text('Bonus', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                const Text('Bonus Transactions', style: TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Bonus Transactions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),

            // Filter Card
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
                spacing: 14,
                runSpacing: 10,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _buildDateField('From Date', _fromDateController, () => _selectDate(context, true)),
                      _buildDateField('To Date', _toDateController, () => _selectDate(context, false)),
                      Padding(
                        padding: const EdgeInsets.only(top: 18.0),
                        child: ElevatedButton(
                          onPressed: _applyFilter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 220,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 18.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search Farmer...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Transactions Table
            transactionsAsync.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()),
              ),
              error: (err, st) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
              data: (transactions) {
                var filtered = transactions;
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((t) =>
                      t.farmerName.toLowerCase().contains(_searchQuery) ||
                      (t.farmerNo?.toLowerCase().contains(_searchQuery) ?? false)).toList();
                }

                return Container(
                  width: double.infinity,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (filtered.isEmpty)
                        Container(
                          height: 160,
                          alignment: Alignment.center,
                          child: const Text('No bonus transactions recorded yet for this date range.', style: TextStyle(color: Colors.grey)),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                            columnSpacing: 20,
                            horizontalMargin: 12,
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                            dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                            columns: const [
                              DataColumn(label: Text('Sr.')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Farmer Name')),
                              DataColumn(label: Text('Animal Type')),
                              DataColumn(label: Text('Milk (L)')),
                              DataColumn(label: Text('Bonus Amount')),
                              DataColumn(label: Text('Paid Amount')),
                              DataColumn(label: Text('Remaining')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: filtered.asMap().entries.map((entry) {
                              final idx = entry.key + 1;
                              final txn = entry.value;
                              return DataRow(
                                cells: [
                                  DataCell(Text('$idx')),
                                  DataCell(Text(_formatDate(txn.paymentDate))),
                                  DataCell(
                                    Text(
                                      txn.farmerName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  DataCell(Text(txn.animalType)),
                                  DataCell(Text(txn.milkQuantity.toStringAsFixed(1))),
                                  DataCell(Text('₹ ${txn.totalBonus.toStringAsFixed(2)}')),
                                  DataCell(
                                    Text(
                                      '₹ ${txn.paidAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '₹ ${txn.remainingBonus.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: txn.remainingBonus > 0 ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // View / Print Receipt
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFF2563EB)),
                                          tooltip: 'Print Receipt',
                                          onPressed: () {
                                            final settings = ref.read(settingsProvider).value;
                                            BonusPdfService.printReceipt(txn: txn, settings: settings);
                                          },
                                        ),
                                        // Edit
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18, color: Color(0xFF0284C7)),
                                          tooltip: 'Edit Transaction',
                                          onPressed: () => _editTransaction(txn),
                                        ),
                                        // Delete
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                                          tooltip: 'Delete Transaction',
                                          onPressed: () => _confirmDelete(txn),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),

                      const SizedBox(height: 14),
                      // Footer info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing 1 to ${filtered.length} of ${filtered.length} entries',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: null,
                                child: const Icon(Icons.chevron_left, size: 16),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: null,
                                child: const Icon(Icons.chevron_right, size: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, VoidCallback onTap) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.text,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Icon(Icons.calendar_month, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd-MM-yyyy').format(dt);
    } catch (_) {
      return iso;
    }
  }
}
