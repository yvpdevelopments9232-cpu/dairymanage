import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/flutter_models.dart';
import '../../../providers/bonus_provider.dart';
import 'bonus_payment_screen.dart';

class BonusDashboardScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateSubTab;

  const BonusDashboardScreen({super.key, this.onNavigateSubTab});

  @override
  ConsumerState<BonusDashboardScreen> createState() => _BonusDashboardScreenState();
}

class _BonusDashboardScreenState extends ConsumerState<BonusDashboardScreen> {
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
    _fromDateController.disposeOrder();
    _toDateController.disposeOrder();
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
    final summaryAsync = ref.watch(bonusCalculationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Title & Filter
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.workspace_premium, color: Color(0xFF1E40AF), size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonus Dashboard',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Farmer bonus calculations and distribution overview',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _buildDateField('From Date', _fromDateController, () => _selectDate(context, true)),
                      _buildDateField('To Date', _toDateController, () => _selectDate(context, false)),
                      ElevatedButton(
                        onPressed: _applyFilter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 1,
                        ),
                        child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Content
            summaryAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(60.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, st) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text('Error loading bonus data: $err', style: const TextStyle(color: Colors.red)),
                ),
              ),
              data: (summary) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 4 Hero Metric Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 900;
                        return GridView.count(
                          crossAxisCount: isNarrow ? (constraints.maxWidth < 600 ? 1 : 2) : 4,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: isNarrow ? 2.5 : 2.0,
                          children: [
                            _buildMetricCard(
                              title: 'Total Collection',
                              value: '${NumberFormat('#,##0.00').format(summary.totalCollection)} L',
                              icon: Icons.water_drop,
                              bgColor: const Color(0xFFEFF6FF),
                              iconColor: const Color(0xFF3B82F6),
                              textColor: const Color(0xFF1E40AF),
                            ),
                            _buildMetricCard(
                              title: 'Total Bonus',
                              value: '₹ ${NumberFormat('#,##0.00').format(summary.totalBonus)}',
                              icon: Icons.currency_rupee,
                              bgColor: const Color(0xFFF0FDF4),
                              iconColor: const Color(0xFF22C55E),
                              textColor: const Color(0xFF15803D),
                            ),
                            _buildMetricCard(
                              title: 'Paid Bonus',
                              value: '₹ ${NumberFormat('#,##0.00').format(summary.paidBonus)}',
                              icon: Icons.check_circle_outline,
                              bgColor: const Color(0xFFFAF5FF),
                              iconColor: const Color(0xFFA855F7),
                              textColor: const Color(0xFF7E22CE),
                            ),
                            _buildMetricCard(
                              title: 'Remaining Bonus',
                              value: '₹ ${NumberFormat('#,##0.00').format(summary.remainingBonus)}',
                              icon: Icons.schedule,
                              bgColor: const Color(0xFFFFF7ED),
                              iconColor: const Color(0xFFF97316),
                              textColor: const Color(0xFFC2410C),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Farmers Summary Table & Bonus Overview Donut Chart
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isLarge = constraints.maxWidth >= 950;
                        if (isLarge) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: _buildFarmersSummaryTable(summary.farmersSummary)),
                              const SizedBox(width: 20),
                              Expanded(flex: 4, child: _buildBonusOverviewCard(summary)),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildBonusOverviewCard(summary),
                              const SizedBox(height: 20),
                              _buildFarmersSummaryTable(summary.farmersSummary),
                            ],
                          );
                        }
                      },
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

  Widget _buildDateField(String label, TextEditingController controller, VoidCallback onTap) {
    return SizedBox(
      width: 145,
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.2), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.85)),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmersSummaryTable(List<BonusFarmerSummary> summaries) {
    return Container(
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
              const Text(
                'Farmers Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                '${summaries.length} Farmers',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (summaries.isEmpty)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: const Text('No milk collections found for the selected period.', style: TextStyle(color: Colors.grey)),
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
                  DataColumn(label: Text('Farmer Name')),
                  DataColumn(label: Text('Milk (L)')),
                  DataColumn(label: Text('Animal Type')),
                  DataColumn(label: Text('Total Bonus')),
                  DataColumn(label: Text('Paid')),
                  DataColumn(label: Text('Remaining')),
                ],
                rows: summaries.asMap().entries.map((entry) {
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
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.animalType == 'Cow' ? Colors.amber.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: item.animalType == 'Cow' ? Colors.amber.shade200 : Colors.blue.shade200),
                          ),
                          child: Text(
                            item.animalType,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: item.animalType == 'Cow' ? Colors.brown.shade800 : Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ),
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
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBonusOverviewCard(BonusCalculationSummary summary) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Bonus Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: CustomPaint(
                painter: _DonutChartPainter(
                  paidRatio: summary.totalBonus > 0 ? summary.paidBonus / summary.totalBonus : 0.0,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹ ${NumberFormat('#,##0').format(summary.totalBonus)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Total Bonus',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(
                color: const Color(0xFF22C55E),
                label: 'Paid Bonus',
                value: '${summary.paidPercentage.toStringAsFixed(1)}%',
              ),
              _buildLegendItem(
                color: const Color(0xFFF97316),
                label: 'Remaining Bonus',
                value: '${summary.remainingPercentage.toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label, required String value}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ],
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double paidRatio;

  _DonutChartPainter({required this.paidRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 18.0;

    final bgPaint = Paint()
      ..color = const Color(0xFFFFF7ED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final remainingPaint = Paint()
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paidPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background track
    canvas.drawCircle(center, radius, bgPaint);

    // Draw remaining arc (full or partial)
    final sweepAngleRemaining = 2 * math.pi * (1.0 - paidRatio);
    final sweepAnglePaid = 2 * math.pi * paidRatio;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw remaining (orange)
    canvas.drawArc(rect, -math.pi / 2, sweepAngleRemaining, false, remainingPaint);

    // Draw paid (green)
    if (paidRatio > 0.001) {
      canvas.drawArc(rect, -math.pi / 2 + sweepAngleRemaining, sweepAnglePaid, false, paidPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.paidRatio != paidRatio;
  }
}

extension on TextEditingController {
  void disposeOrder() {
    dispose();
  }
}
