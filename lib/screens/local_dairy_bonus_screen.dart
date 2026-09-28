import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/flutter_models.dart';
import '../providers/bonus_provider.dart';
import '../providers/settings_provider.dart';
import '../services/bonus_pdf_service.dart';

class LocalDairyBonusScreen extends ConsumerStatefulWidget {
  const LocalDairyBonusScreen({super.key});

  @override
  ConsumerState<LocalDairyBonusScreen> createState() => _LocalDairyBonusScreenState();
}

class _LocalDairyBonusScreenState extends ConsumerState<LocalDairyBonusScreen> {
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

  void _printFarmerBonusSlip(BonusFarmerSummary farmer) {
    final dateRange = ref.read(bonusDateRangeProvider);
    final settings = ref.read(settingsProvider).value;

    final txn = BonusTransaction(
      id: 'slip_${farmer.farmerId}',
      farmerId: farmer.farmerId,
      farmerName: farmer.farmerName,
      farmerNo: farmer.farmerNo,
      animalType: farmer.animalType,
      fromDate: dateRange.fromDate,
      toDate: dateRange.toDate,
      milkQuantity: farmer.totalMilk,
      bonusRate: farmer.displayRate,
      totalBonus: farmer.totalBonus,
      previousPaid: 0.0,
      paidAmount: farmer.paidAmount,
      totalPaid: farmer.paidAmount,
      remainingBonus: farmer.remainingBonus,
      paymentDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      paymentMode: 'Main Dairy Distribution',
      transactionNumber: null,
      remarks: 'Local Dairy Bonus Slip',
      createdAt: DateTime.now().toIso8601String(),
    );

    BonusPdfService.printReceipt(txn: txn, settings: settings);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(bonusCalculationProvider);
    final settingsAsync = ref.watch(bonusSettingsProvider);
    final rates = settingsAsync.value ?? BonusSettings(id: 'default_settings', cowRate: 0.40, buffaloRate: 0.50);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Synchronized Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sync, color: Color(0xFF2563EB), size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Main Dairy Synchronized Bonus',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rates issued by Main Dairy: Cow Milk: ₹ ${rates.cowRate.toStringAsFixed(2)} / L | Buffalo Milk: ₹ ${rates.buffaloRate.toStringAsFixed(2)} / L. Amounts are centrally managed.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Date Range & Search Card
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

            // Metrics & Table
            summaryAsync.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()),
              ),
              error: (err, st) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
              data: (summary) {
                var farmers = summary.farmersSummary;
                if (_searchQuery.isNotEmpty) {
                  farmers = farmers.where((f) =>
                      f.farmerName.toLowerCase().contains(_searchQuery) ||
                      (f.farmerNo?.toLowerCase().contains(_searchQuery) ?? false)).toList();
                }

                return Column(
                  children: [
                    // Metric row
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 750;
                        return GridView.count(
                          crossAxisCount: isNarrow ? 2 : 4,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 2.2,
                          children: [
                            _buildSummaryPill('Total Milk', '${NumberFormat('#,##0.0').format(summary.totalCollection)} L', const Color(0xFF2563EB)),
                            _buildSummaryPill('Total Bonus', '₹ ${NumberFormat('#,##0.00').format(summary.totalBonus)}', const Color(0xFF16A34A)),
                            _buildSummaryPill('Paid Bonus', '₹ ${NumberFormat('#,##0.00').format(summary.paidBonus)}', const Color(0xFF7E22CE)),
                            _buildSummaryPill('Remaining', '₹ ${NumberFormat('#,##0.00').format(summary.remainingBonus)}', const Color(0xFFEA580C)),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Table
                    Container(
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Farmer Bonus Directory (${farmers.length})',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (farmers.isEmpty)
                            Container(
                              height: 160,
                              alignment: Alignment.center,
                              child: const Text('No bonus records found for this period.', style: TextStyle(color: Colors.grey)),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                                columnSpacing: 22,
                                horizontalMargin: 12,
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                                dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                                columns: const [
                                  DataColumn(label: Text('Sr.')),
                                  DataColumn(label: Text('Farmer Name')),
                                  DataColumn(label: Text('Milk (L)')),
                                  DataColumn(label: Text('Animal Type')),
                                  DataColumn(label: Text('Total Bonus')),
                                  DataColumn(label: Text('Paid')),
                                  DataColumn(label: Text('Remaining')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Receipt')),
                                ],
                                rows: farmers.asMap().entries.map((entry) {
                                  final idx = entry.key + 1;
                                  final item = entry.value;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text('$idx')),
                                      DataCell(
                                        Text(
                                          item.farmerName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                      DataCell(Text(item.totalMilk.toStringAsFixed(1))),
                                      DataCell(Text(item.animalType)),
                                      DataCell(Text('₹ ${item.totalBonus.toStringAsFixed(2)}')),
                                      DataCell(Text('₹ ${item.paidAmount.toStringAsFixed(2)}')),
                                      DataCell(
                                        Text(
                                          '₹ ${item.remainingBonus.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: item.remainingBonus > 0 ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: item.status == 'Paid' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: item.status == 'Paid' ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                                          ),
                                          child: Text(
                                            item.status,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: item.status == 'Paid' ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFF2563EB)),
                                          tooltip: 'Print Bonus Slip',
                                          onPressed: () => _printFarmerBonusSlip(item),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
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
}
