import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/main_dairy_dashboard_provider.dart';

class MainDairyDashboardScreen extends ConsumerWidget {
  final Function(int)? onNavigate;

  const MainDairyDashboardScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                          'Main Dairy Daily Overview',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                        const Text(
                          'Outward milk dispatches and collection tracking',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HERO CARD: TOTAL MILK COLLECTION AMOUNT (Requested Feature)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
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
                                        const Text(
                                          'TOTAL MILK COLLECTION AMOUNT',
                                          style: TextStyle(
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
                                    label: const Text('Add Dispatch'),
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
                              'Total Litres Dispatched',
                              '${stats.totalQuantity.toStringAsFixed(2)} L',
                              Icons.water_drop,
                              Colors.blue,
                              subtitle: 'Overall Avg Rate: ₹${stats.avgRate.toStringAsFixed(2)}/L',
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              'Cow Milk',
                              '${stats.cowQuantity.toStringAsFixed(2)} L (₹${stats.cowAmount.toStringAsFixed(2)})',
                              Icons.pets,
                              Colors.green.shade700,
                              subtitle: 'Avg Fat: ${stats.cowAvgFat.toStringAsFixed(1)}%  |  Avg SNF: ${stats.cowAvgSnf.toStringAsFixed(1)}%',
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              'Buffalo Milk',
                              '${stats.buffaloQuantity.toStringAsFixed(2)} L (₹${stats.buffaloAmount.toStringAsFixed(2)})',
                              Icons.cruelty_free,
                              Colors.deepOrange.shade700,
                              subtitle: 'Avg Fat: ${stats.buffaloAvgFat.toStringAsFixed(1)}%  |  Avg SNF: ${stats.buffaloAvgSnf.toStringAsFixed(1)}%',
                            ),
                            const SizedBox(height: 16),
                            _buildMetricCard(
                              'Main Dairies Supplied',
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
                                'Total Litres Dispatched',
                                '${stats.totalQuantity.toStringAsFixed(2)} L',
                                Icons.water_drop,
                                Colors.blue,
                                subtitle: 'Overall Avg Rate: ₹${stats.avgRate.toStringAsFixed(2)}/L',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                'Cow Milk',
                                '${stats.cowQuantity.toStringAsFixed(2)} L (₹${stats.cowAmount.toStringAsFixed(2)})',
                                Icons.pets,
                                Colors.green.shade700,
                                subtitle: 'Avg Fat: ${stats.cowAvgFat.toStringAsFixed(1)}%  |  Avg SNF: ${stats.cowAvgSnf.toStringAsFixed(1)}%',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                'Buffalo Milk',
                                '${stats.buffaloQuantity.toStringAsFixed(2)} L (₹${stats.buffaloAmount.toStringAsFixed(2)})',
                                Icons.cruelty_free,
                                Colors.deepOrange.shade700,
                                subtitle: 'Avg Fat: ${stats.buffaloAvgFat.toStringAsFixed(1)}%  |  Avg SNF: ${stats.buffaloAvgSnf.toStringAsFixed(1)}%',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildMetricCard(
                                'Main Dairies Supplied',
                                '${stats.dairiesCount} Dairy Center(s)',
                                Icons.business,
                                Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),

                      // SHIFTS BREAKDOWN CARDS
                      Row(
                        children: [
                          Expanded(
                            child: _buildShiftCard(
                              shiftName: 'Morning Shift',
                              icon: Icons.wb_sunny,
                              iconColor: Colors.amber.shade700,
                              quantity: stats.morningQuantity,
                              amount: stats.morningAmount,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildShiftCard(
                              shiftName: 'Evening Shift',
                              icon: Icons.nights_stay,
                              iconColor: Colors.indigo.shade600,
                              quantity: stats.eveningQuantity,
                              amount: stats.eveningAmount,
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
                              label: const Text('View Full Reports'),
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
                                      label: const Text('Record Dispatch Now'),
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
                                columns: const [
                                  DataColumn(label: Text('D. ID / Dairy Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Shift', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Milk Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Qty (L)', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Fat %', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('SNF %', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Total Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
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
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Text(shiftName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quantity', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text('${quantity.toStringAsFixed(2)} L', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      '₹ ${amount.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo.shade800),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
