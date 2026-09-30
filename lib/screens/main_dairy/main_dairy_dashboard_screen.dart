import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/main_dairy_dashboard_provider.dart';
import '../../services/translations.dart';
import '../../providers/language_provider.dart';

class MainDairyDashboardScreen extends ConsumerWidget {
  final Function(int)? onNavigate;

  const MainDairyDashboardScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final statsAsync = ref.watch(mainDairyDashboardProvider);
    final notifier = ref.watch(mainDairyDashboardProvider.notifier);
    final primaryColor = Colors.indigo.shade800;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.indigo.shade50.withOpacity(0.3),
      body: Column(
        children: [
          // Top Bar with Calendar Date Selector
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: isMobile ? 12 : 16),
            color: Colors.white,
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
                      child: Icon(Icons.domain, color: primaryColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Main Dairy Daily Overview'.tr,
                          style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                        Text(
                          'Outward milk dispatches and collection tracking'.tr,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month, color: Colors.indigo),
                  label: Text(
                    DateFormat('dd MMMM yyyy').format(DateTime.parse(notifier.selectedDate)),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    side: BorderSide(color: Colors.indigo.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Colors.indigo.shade50.withOpacity(0.5),
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.parse(notifier.selectedDate),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      notifier.setDate(DateFormat('yyyy-MM-dd').format(date));
                    }
                  },
                ),
              ],
            ),
          ),

          // Main Dashboard Content
          Expanded(
            child: statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error loading stats: $e')),
              data: (stats) {
                final dateFormatted = DateFormat('dd MMMM yyyy').format(DateTime.parse(stats.selectedDate));

                return SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 14 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HERO CARD: TOTAL MILK COLLECTION AMOUNT (Requested Feature)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.indigo.shade900, Colors.indigo.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.payments, color: Colors.amberAccent, size: 28),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TOTAL MILK COLLECTION AMOUNT'.tr,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.1,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        Text(
                                          'Dispatched to Main Dairies on $dateFormatted',
                                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (onNavigate != null)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: Text('Add Dispatch'.tr),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade700,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => onNavigate!(2), // Index 2 is Milk Collection
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '₹ ${stats.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total: ${stats.totalQuantity.toStringAsFixed(2)} L (Avg Rate: ₹${stats.avgRate.toStringAsFixed(2)}/L)\n'
                              '🐄 Cow Milk: Avg Fat ${stats.cowAvgFat.toStringAsFixed(1)}% | Avg SNF ${stats.cowAvgSnf.toStringAsFixed(1)}%   •   '
                              '🐃 Buffalo Milk: Avg Fat ${stats.buffaloAvgFat.toStringAsFixed(1)}% | Avg SNF ${stats.buffaloAvgSnf.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // METRIC CARDS ROW
                      if (isMobile)
                        Column(
                          children: [
                            _buildMetricCard(
                              'Total Litres Dispatched'.tr,
                              '${stats.totalQuantity.toStringAsFixed(2)} L',
                              Icons.water_drop,
                              Colors.blue,
                              subtitle: 'Overall Avg Rate: ₹${stats.avgRate.toStringAsFixed(2)}/L',
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              'Cow Milk'.tr,
                              '${stats.cowQuantity.toStringAsFixed(2)} L (₹${stats.cowAmount.toStringAsFixed(2)})',
                              Icons.pets,
                              Colors.green.shade700,
                              subtitle: 'Avg Fat: ${stats.cowAvgFat.toStringAsFixed(1)}%  |  Avg SNF: ${stats.cowAvgSnf.toStringAsFixed(1)}%',
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              'Buffalo Milk'.tr,
                              '${stats.buffaloQuantity.toStringAsFixed(2)} L (₹${stats.buffaloAmount.toStringAsFixed(2)})',
                              Icons.cruelty_free,
                              Colors.deepOrange.shade700,
                              subtitle: 'Avg Fat: ${stats.buffaloAvgFat.toStringAsFixed(1)}%  |  Avg SNF: ${stats.buffaloAvgSnf.toStringAsFixed(1)}%',
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              'Main Dairies Supplied'.tr,
                              '${stats.dairiesCount} Dairy Center(s)',
                              Icons.business,
                              Colors.purple,
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                'Total Litres Dispatched'.tr,
                                '${stats.totalQuantity.toStringAsFixed(2)} L',
                                Icons.water_drop,
                                Colors.blue,
                                subtitle: 'Overall Avg Rate: ₹${stats.avgRate.toStringAsFixed(2)}/L',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                'Cow Milk'.tr,
                                '${stats.cowQuantity.toStringAsFixed(2)} L (₹${stats.cowAmount.toStringAsFixed(2)})',
                                Icons.pets,
                                Colors.green.shade700,
                                subtitle: 'Avg Fat: ${stats.cowAvgFat.toStringAsFixed(1)}%  |  Avg SNF: ${stats.cowAvgSnf.toStringAsFixed(1)}%',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                'Buffalo Milk'.tr,
                                '${stats.buffaloQuantity.toStringAsFixed(2)} L (₹${stats.buffaloAmount.toStringAsFixed(2)})',
                                Icons.cruelty_free,
                                Colors.deepOrange.shade700,
                                subtitle: 'Avg Fat: ${stats.buffaloAvgFat.toStringAsFixed(1)}%  |  Avg SNF: ${stats.buffaloAvgSnf.toStringAsFixed(1)}%',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                'Main Dairies Supplied'.tr,
                                '${stats.dairiesCount} Dairy Center(s)',
                                Icons.business,
                                Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),

                      // SHIFTS BREAKDOWN CARDS
                      if (isMobile)
                        Column(
                          children: [
                            _buildShiftCard(
                              shiftName: 'Morning Shift'.tr,
                              icon: Icons.wb_sunny,
                              iconColor: Colors.amber.shade700,
                              quantity: stats.morningQuantity,
                              amount: stats.morningAmount,
                              isMobile: true,
                            ),
                            const SizedBox(height: 14),
                            _buildShiftCard(
                              shiftName: 'Evening Shift'.tr,
                              icon: Icons.nights_stay,
                              iconColor: Colors.indigo.shade600,
                              quantity: stats.eveningQuantity,
                              amount: stats.eveningAmount,
                              isMobile: true,
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _buildShiftCard(
                                shiftName: 'Morning Shift'.tr,
                                icon: Icons.wb_sunny,
                                iconColor: Colors.amber.shade700,
                                quantity: stats.morningQuantity,
                                amount: stats.morningAmount,
                                isMobile: false,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildShiftCard(
                                shiftName: 'Evening Shift'.tr,
                                icon: Icons.nights_stay,
                                iconColor: Colors.indigo.shade600,
                                quantity: stats.eveningQuantity,
                                amount: stats.eveningAmount,
                                isMobile: false,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 28),

                      // DISPATCH DETAILS TABLE FOR SELECTED DATE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dispatches on $dateFormatted',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                          if (onNavigate != null)
                            TextButton.icon(
                              icon: const Icon(Icons.receipt_long, size: 18),
                              label: Text('View Full Reports'.tr),
                              onPressed: () => onNavigate!(4), // Index 4 is Reports
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (stats.collections.isEmpty)
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inbox, size: 60, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No outward milk dispatches recorded on $dateFormatted.',
                                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                                  ),
                                  const SizedBox(height: 12),
                                  if (onNavigate != null)
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: Text('Record Dispatch Now'.tr),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => onNavigate!(2),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
                                columns: [
                                  DataColumn(label: Text('D. ID / Dairy Name'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Shift'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Milk Type'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Qty (L)'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Fat %'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('SNF %'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Rate (₹)'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Total Amount (₹)'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: stats.collections.map((c) {
                                  final dairyNoStr = c.dairyNo != null ? '#${c.dairyNo.toString().padLeft(3, '0')} ' : '';
                                  final dairyName = '$dairyNoStr${c.dairyName ?? "Main Dairy"}';

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(dairyName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(
                                        Chip(
                                          label: Text(c.shift, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                          backgroundColor: c.shift.toLowerCase() == 'morning' ? Colors.orange.shade700 : Colors.indigo.shade700,
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                      DataCell(Text(c.milkType)),
                                      DataCell(Text(c.quantity.toStringAsFixed(2))),
                                      DataCell(Text(c.fat.toStringAsFixed(1))),
                                      DataCell(Text(c.snf.toStringAsFixed(1))),
                                      DataCell(Text('₹${c.rate.toStringAsFixed(2)}')),
                                      DataCell(
                                        Text(
                                          '₹${c.totalAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
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
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard({
    required String shiftName,
    required IconData icon,
    required Color iconColor,
    required double quantity,
    required double amount,
    bool isMobile = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shiftName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quantity'.tr,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${quantity.toStringAsFixed(2)} L',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Amount'.tr,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹ ${amount.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo.shade800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
