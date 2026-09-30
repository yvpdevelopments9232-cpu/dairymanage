import 'package:flutter/material.dart';
import '../widgets/desktop_wrapper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ledger_report_screen.dart';
import 'milk_report_screen.dart';
import 'farmer_report_screen.dart';
import 'sales_report_screen.dart';
import 'stock_report_screen.dart';
import 'expense_report_screen.dart';
import 'staff_report_screen.dart';
import '../services/translations.dart';
import '../providers/language_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports Center'.tr, style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Report Type'.tr,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate detailed insights and ledgers for your dairy business.'.tr,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : (MediaQuery.of(context).size.width > 500 ? 2 : 1),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: MediaQuery.of(context).size.width < 500 ? 2.5 : 1.5,
                children: [
                  _buildReportCard(
                    context,
                    title: 'Annual Milk Collection'.tr,
                    icon: Icons.calendar_month,
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DesktopWrapper(child: MilkReportScreen()))),
                  ),
                  _buildReportCard(
                    context,
                    title: 'Farmer Collection Details'.tr,
                    icon: Icons.agriculture,
                    color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DesktopWrapper(child: FarmerReportScreen()))),
                  ),
                  _buildReportCard(
                    context,
                    title: 'Stock Report'.tr,
                    icon: Icons.warehouse,
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DesktopWrapper(child: StockReportScreen()))),
                  ),
                  _buildReportCard(
                    context,
                    title: 'Customer Ledger'.tr,
                    icon: Icons.groups,
                    color: Colors.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DesktopWrapper(child: LedgerReportScreen(partyType: 'Customer')))),
                  ),
                  _buildReportCard(
                    context,
                    title: 'Product Sales Report'.tr,
                    icon: Icons.shopping_cart,
                    color: Colors.red,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DesktopWrapper(child: SalesReportScreen()))),
                  ),
                  _buildReportCard(
                    context,
                    title: 'Dealer (Supplier) Ledger'.tr,
                    icon: Icons.local_shipping,
                    color: Colors.teal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DesktopWrapper(child: LedgerReportScreen(partyType: 'Dealer')))),
                  ),
                  _buildReportCard(
                    context,
                    title: 'Profit & Expense Report'.tr,
                    icon: Icons.account_balance,
                    color: Colors.indigo,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DesktopWrapper(child: ExpenseReportScreen()))),
                  ),
                  _buildReportCard(
                    context,
                    title: 'Staff Salary Report'.tr,
                    icon: Icons.badge,
                    color: Colors.blueGrey,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DesktopWrapper(child: StaffReportScreen()))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
