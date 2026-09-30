import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/flutter_models.dart';
import '../../../providers/bonus_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../services/translations.dart';
import 'bonus_payment_screen.dart';

class PaidBonusScreen extends ConsumerStatefulWidget {
  const PaidBonusScreen({super.key});

  @override
  ConsumerState<PaidBonusScreen> createState() => _PaidBonusScreenState();
}

class _PaidBonusScreenState extends ConsumerState<PaidBonusScreen> {
  late TextEditingController _fromDateController;
  late TextEditingController _toDateController;
  DateTime? _fromDate;
  DateTime? _toDate;

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

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final summaryAsync = ref.watch(bonusCalculationProvider);

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
                Text('Bonus'.tr, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text('Paid Bonus'.tr, style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Paid Bonus'.tr,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),

            // Date Range Filter Card
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
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildDateField('From Date'.tr, _fromDateController, () => _selectDate(context, true)),
                  _buildDateField('To Date'.tr, _toDateController, () => _selectDate(context, false)),
                  Padding(
                    padding: const EdgeInsets.only(top: 18.0),
                    child: ElevatedButton(
                      onPressed: _applyFilter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Filter'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Table of Paid Farmers
            summaryAsync.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()),
              ),
              error: (err, st) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
              data: (summary) {
                final paidFarmers = summary.farmersSummary.where((f) => f.paidAmount > 0).toList();

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${"Paid Farmers".tr} (${paidFarmers.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '${"Total Paid".tr}: ₹ ${NumberFormat('#,##0.00').format(summary.paidBonus)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (paidFarmers.isEmpty)
                        Container(
                          height: 160,
                          alignment: Alignment.center,
                          child: Text(
                            'No paid bonus records found for this period.'.tr,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                            columnSpacing: 28,
                            horizontalMargin: 12,
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                            dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                            columns: [
                              DataColumn(label: Text('Sr.'.tr)),
                              DataColumn(label: Text('Farmer Name'.tr)),
                              DataColumn(label: Text('Milk (L)'.tr)),
                              DataColumn(label: Text('Animal Type'.tr)),
                              DataColumn(label: Text('Total Bonus'.tr)),
                              DataColumn(label: Text('Paid Amount'.tr)),
                              DataColumn(label: Text('Status'.tr)),
                            ],
                            rows: paidFarmers.asMap().entries.map((entry) {
                              final idx = entry.key + 1;
                              final item = entry.value;
                              return DataRow(
                                cells: [
                                  DataCell(Text('$idx')),
                                  DataCell(
                                    InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(MaterialPageRoute(
                                          builder: (_) => BonusPaymentScreen(preSelectedFarmerId: item.farmerId),
                                        ));
                                      },
                                      child: Text(
                                        item.farmerName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(item.totalMilk.toStringAsFixed(1))),
                                  DataCell(Text(item.animalType.tr)),
                                  DataCell(Text('₹ ${item.totalBonus.toStringAsFixed(2)}')),
                                  DataCell(
                                    Text(
                                      '₹ ${item.paidAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF86EFAC)),
                                      ),
                                      child: Text(
                                        item.status.tr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
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
      width: 150,
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
