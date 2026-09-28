import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/stock_provider.dart';
import '../providers/product_provider.dart';
import '../models/flutter_models.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  DateTime? _fromDate = DateTime.now();
  DateTime? _toDate = DateTime.now();

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialStart = _fromDate ?? now;
    final initialEnd = _toDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: initialStart.isAfter(DateTime(2035)) ? DateTime(2035) : initialStart,
        end: initialEnd.isAfter(DateTime(2035)) ? DateTime(2035) : initialEnd,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  Future<void> _selectSingleDate({required bool isFrom}) async {
    final initialDate = (isFrom ? _fromDate : _toDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(picked)) {
            _toDate = picked;
          }
        } else {
          _toDate = picked;
          if (_fromDate != null && _fromDate!.isAfter(picked)) {
            _fromDate = picked;
          }
        }
      });
    }
  }

  List<StockTransaction> _filterTransactions(List<StockTransaction> list) {
    if (_fromDate == null || _toDate == null) return list;

    final startDay = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final endDay = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);

    return list.where((tx) {
      final dt = DateTime.tryParse(tx.transactionDate);
      if (dt == null) return true;
      final txDay = DateTime(dt.year, dt.month, dt.day);
      return !txDay.isBefore(startDay) && !txDay.isAfter(endDay);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Transactions Ledger', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Stock Adjustment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => _showAddAdjustmentDialog(context, ref),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            tooltip: 'Refresh Ledger',
            onPressed: () {
              ref.read(stockProvider.notifier).refresh();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading stock history: $e')),
        data: (transactions) {
          final filteredTransactions = _filterTransactions(transactions);

          return Column(
            children: [
              // 1. Date Range Calendar Filter Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // From Date Selector
                    InkWell(
                      onTap: () => _selectSingleDate(isFrom: true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 15, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              _fromDate != null ? 'From: ${DateFormat('dd MMM yyyy').format(_fromDate!)}' : 'From: All',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // To Date Selector
                    InkWell(
                      onTap: () => _selectSingleDate(isFrom: false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_outlined, size: 15, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              _toDate != null ? 'To: ${DateFormat('dd MMM yyyy').format(_toDate!)}' : 'To: All',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Calendar Range Picker Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 16),
                      label: const Text('Calendar Range'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _selectDateRange,
                    ),

                    // Today Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: (_fromDate != null &&
                                _toDate != null &&
                                DateFormat('yyyy-MM-dd').format(_fromDate!) == DateFormat('yyyy-MM-dd').format(DateTime.now()) &&
                                DateFormat('yyyy-MM-dd').format(_toDate!) == DateFormat('yyyy-MM-dd').format(DateTime.now()))
                            ? Colors.white
                            : Colors.grey.shade800,
                        backgroundColor: (_fromDate != null &&
                                _toDate != null &&
                                DateFormat('yyyy-MM-dd').format(_fromDate!) == DateFormat('yyyy-MM-dd').format(DateTime.now()) &&
                                DateFormat('yyyy-MM-dd').format(_toDate!) == DateFormat('yyyy-MM-dd').format(DateTime.now()))
                            ? Colors.blue.shade700
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        setState(() {
                          _fromDate = DateTime.now();
                          _toDate = DateTime.now();
                        });
                      },
                      child: const Text('Today'),
                    ),

                    // All Dates Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: (_fromDate == null && _toDate == null) ? Colors.white : Colors.grey.shade800,
                        backgroundColor: (_fromDate == null && _toDate == null) ? Colors.blue.shade700 : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        setState(() {
                          _fromDate = null;
                          _toDate = null;
                        });
                      },
                      child: const Text('All Dates'),
                    ),

                    const Spacer(),

                    // Counter Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${filteredTransactions.length} of ${transactions.length} entries',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Main Table Area
              if (transactions.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('No stock transactions found.', style: TextStyle(fontSize: 16, color: Colors.black54)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Initial / Adjustment Entry'),
                          onPressed: () => _showAddAdjustmentDialog(context, ref),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filteredTransactions.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _fromDate != null && _toDate != null
                              ? 'No stock transactions found between ${DateFormat('dd MMM yyyy').format(_fromDate!)} and ${DateFormat('dd MMM yyyy').format(_toDate!)}.'
                              : 'No stock transactions found for this date range.',
                          style: const TextStyle(fontSize: 15, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.all_inclusive, size: 16),
                              label: const Text('Show All Dates'),
                              onPressed: () {
                                setState(() {
                                  _fromDate = null;
                                  _toDate = null;
                                });
                              },
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Stock Adjustment'),
                              onPressed: () => _showAddAdjustmentDialog(context, ref),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        color: Colors.grey.shade100,
                        child: Row(
                          children: const [
                            Expanded(flex: 2, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 3, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 3, child: Text('Party / Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 2, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 2, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                            SizedBox(width: 110, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          ],
                        ),
                      ),

                      // Table Rows
                      Expanded(
                        child: ListView.separated(
                          itemCount: filteredTransactions.length,
                          separatorBuilder: (c, i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tx = filteredTransactions[index];
                            DateTime dt = DateTime.tryParse(tx.transactionDate) ?? DateTime.now();
                            String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);

                            final transTypeUpper = tx.transType.toUpperCase();
                            bool isPositive = transTypeUpper == 'IN' ||
                                tx.transType.toLowerCase() == 'purchase' ||
                                tx.transType.toLowerCase() == 'opening';

                            Color typeColor = isPositive ? Colors.green.shade700 : Colors.red.shade700;
                            Color typeBgColor = isPositive ? Colors.green.shade50 : Colors.red.shade50;

                            // Format Party Name
                            final partyText = tx.partyName ?? (tx.referenceType == 'Adjustment' ? 'Manual Adjustment' : '-');
                            final isFarmer = partyText.toLowerCase().startsWith('farmer:');
                            final isDealer = partyText.toLowerCase().startsWith('dealer:') || partyText.toLowerCase().startsWith('supplier:');
                            final isCustomer = partyText.toLowerCase().startsWith('customer:');

                            Color partyColor = Colors.grey.shade700;
                            Color partyBg = Colors.grey.shade100;
                            if (isFarmer) {
                              partyColor = Colors.teal.shade800;
                              partyBg = Colors.teal.shade50;
                            } else if (isDealer) {
                              partyColor = Colors.blue.shade800;
                              partyBg = Colors.blue.shade50;
                            } else if (isCustomer) {
                              partyColor = Colors.purple.shade800;
                              partyBg = Colors.purple.shade50;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              child: Row(
                                children: [
                                  // Date & Time
                                  Expanded(
                                    flex: 2,
                                    child: Text(formattedDate, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                  ),

                                  // Product
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      tx.productName ?? 'Unknown',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),

                                  // Party / Name (Farmer / Dealer)
                                  Expanded(
                                    flex: 3,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: partyBg,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: partyColor.withValues(alpha: 0.25)),
                                        ),
                                        child: Text(
                                          partyText,
                                          style: TextStyle(
                                            color: partyColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Type
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: typeBgColor,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          tx.transType,
                                          style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Quantity
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${isPositive ? '+' : '-'}${tx.quantity}',
                                      style: TextStyle(
                                        color: typeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),

                                  // Actions
                                  SizedBox(
                                    width: 110,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                          tooltip: 'Edit Stock Entry',
                                          splashRadius: 18,
                                          onPressed: () => _showEditDialog(context, ref, tx),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          tooltip: 'Delete Stock Entry',
                                          splashRadius: 18,
                                          onPressed: () => _confirmDelete(context, ref, tx),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, StockTransaction tx) {
    final qtyController = TextEditingController(text: tx.quantity.toString());
    String selectedType = (tx.transType.toUpperCase() == 'IN' || tx.transType.toLowerCase() == 'purchase' || tx.transType.toLowerCase() == 'opening') ? 'IN' : 'OUT';
    DateTime selectedDate = DateTime.tryParse(tx.transactionDate) ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Edit Stock Entry (${tx.productName ?? "Product"})', style: const TextStyle(fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaction Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'IN', child: Text('IN (Stock Addition / Purchase)')),
                      DropdownMenuItem(value: 'OUT', child: Text('OUT (Stock Deduction / Sale)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      hintText: 'Enter quantity',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                onPressed: () async {
                  final qty = double.tryParse(qtyController.text.trim());
                  if (qty == null || qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid positive quantity')),
                    );
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await ref.read(stockProvider.notifier).updateTransaction(
                      tx,
                      newQuantity: qty,
                      newTransType: selectedType,
                      newDate: selectedDate.toIso8601String().split('T')[0],
                    );
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Stock entry updated successfully'), backgroundColor: Colors.green),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error updating stock entry: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, StockTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Stock Entry'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this stock transaction for "${tx.productName ?? "Product"}"?\n\n'
          'Type: ${tx.transType}\n'
          'Quantity: ${tx.quantity}\n\n'
          'Deleting this will automatically adjust the product current stock balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await ref.read(stockProvider.notifier).deleteTransaction(tx);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Stock transaction deleted and stock adjusted'), backgroundColor: Colors.orange),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error deleting stock entry: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddAdjustmentDialog(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.read(productsProvider);
    final products = productsAsync.value ?? [];
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available to adjust stock')),
      );
      return;
    }

    String selectedProductId = products.first.id;
    String selectedType = 'IN';
    final qtyController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.add_box_outlined, color: Colors.blue),
                SizedBox(width: 8),
                Text('Add Stock Adjustment', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedProductId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (Stock: ${p.currentStock})'))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedProductId = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Adjustment Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'IN', child: Text('IN (+ Add to Stock / Found / Opening)')),
                      DropdownMenuItem(value: 'OUT', child: Text('OUT (- Deduct from Stock / Damage / Lost)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      hintText: 'Enter quantity to adjust',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                onPressed: () async {
                  final qty = double.tryParse(qtyController.text.trim());
                  if (qty == null || qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid positive quantity')),
                    );
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await ref.read(stockProvider.notifier).addTransaction(
                      productId: selectedProductId,
                      transType: selectedType,
                      quantity: qty,
                      transactionDate: selectedDate.toIso8601String().split('T')[0],
                    );
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Stock adjustment added successfully'), backgroundColor: Colors.green),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error adding stock adjustment: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('Add Adjustment'),
              ),
            ],
          );
        },
      ),
    );
  }
}
