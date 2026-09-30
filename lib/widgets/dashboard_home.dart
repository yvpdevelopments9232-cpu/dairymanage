import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../providers/customer_provider.dart';
import '../models/flutter_models.dart';
import '../providers/settings_provider.dart';
import '../providers/product_provider.dart';
import '../services/app_config.dart';
import '../services/subscription_service.dart';
import '../models/subscription_model.dart';
import '../screens/subscription/subscription_status_screen.dart';

import '../services/translations.dart';
import '../providers/language_provider.dart';
import '../providers/display_mode_provider.dart';

class DashboardHome extends ConsumerWidget {
  final VoidCallback? onNavigateToProducts;
  const DashboardHome({super.key, this.onNavigateToProducts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final notifier = ref.watch(dashboardStatsProvider.notifier);
    final outOfStockProducts = ref.watch(outOfStockProductsProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final lang = ref.watch(languageProvider);
    final displayMode = ref.watch(displayModeProvider);
    final isMobile = displayMode == DisplayMode.mobile || MediaQuery.of(context).size.width < 800;

    return Column(
      children: [
        // Top Bar with Date Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: Colors.white,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Daily Overview'.tr, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(notifier.currentDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
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
            ],
          ),
        ),
        
        // Subscription Status Banner
        _buildSubscriptionBanner(context, ref),

        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final settingsAsync = ref.watch(settingsProvider);
              final logoBytes = settingsAsync.value?.logoBytes;
              
              DecorationImage? bgImage;
              if (logoBytes != null) {
                try {
                  bgImage = DecorationImage(
                    image: MemoryImage(logoBytes),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.85), BlendMode.dstATop),
                  );
                } catch (e) {
                  // ignore bad base64
                }
              }

              return Container(
                decoration: BoxDecoration(
                  image: bgImage,
                ),
                child: statsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                  data: (stats) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // OUT OF STOCK REMINDER BANNER
                          if (outOfStockProducts.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade400, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '⚠️ Stock Alert: ${outOfStockProducts.length} Product(s) Out of Stock!',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade900,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Stock is unavailable (0 units). Please replenish stock to continue sales.',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (onNavigateToProducts != null)
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.arrow_forward, size: 16),
                                          label: const Text('Go to Products'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: onNavigateToProducts,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: Colors.redAccent),
                                  const SizedBox(height: 8),
                                  ...outOfStockProducts.map((p) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.red, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Reminder: your ${p.name} stock is out of stock (Available: ${p.currentStock.toStringAsFixed(1)} ${p.unit})',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red.shade900,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),

                          // TOP METRICS CARDS
                          if (isMobile)
                            Column(
                              children: [
                                _buildMetricCard('Milk Collected', '₹${stats.collectionAmount.toStringAsFixed(2)}', Icons.local_drink, Colors.blue),
                                const SizedBox(height: 16),
                                _buildMetricCard('Total Sales', '₹${stats.salesAmount.toStringAsFixed(2)}', Icons.storefront, Colors.purple),
                                const SizedBox(height: 16),
                                _buildMetricCard('Est. Profit', '₹${stats.profit.toStringAsFixed(2)}', Icons.trending_up, stats.profit >= 0 ? Colors.green : Colors.red),
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () => _showRemainingCustomers(context, ref.read(customersProvider).value ?? []),
                                  child: _buildMetricCard('Remaining Amount', '₹${(ref.watch(customersProvider).value ?? []).where((c) => c.currentBalance > 0).fold(0.0, (s, c) => s + c.currentBalance).toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.orange),
                                ),
                                // ('Est. Profit', '₹${stats.profit.toStringAsFixed(2)}', Icons.trending_up, stats.profit >= 0 ? Colors.green : Colors.red),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(child: _buildMetricCard('Milk Collected', '₹${stats.collectionAmount.toStringAsFixed(2)}', Icons.local_drink, Colors.blue)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildMetricCard('Total Sales', '₹${stats.salesAmount.toStringAsFixed(2)}', Icons.storefront, Colors.purple)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildMetricCard('Est. Profit (Sales)', '₹${stats.profit.toStringAsFixed(2)}', Icons.trending_up, stats.profit >= 0 ? Colors.green : Colors.red)),
                                const SizedBox(width: 16),
                                Expanded(child: InkWell(
                                  onTap: () => _showRemainingCustomers(context, ref.read(customersProvider).value ?? []),
                                  child: _buildMetricCard('Remaining', '₹${(ref.watch(customersProvider).value ?? []).where((c) => c.currentBalance > 0).fold(0.0, (s, c) => s + c.currentBalance).toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.orange),
                                )),
                                // , '₹${stats.profit.toStringAsFixed(2)}', Icons.trending_up, stats.profit >= 0 ? Colors.green : Colors.red)),
                              ],
                            ),
                          const SizedBox(height: 24),
                          
                          // MILK DETAILS
                          if (isMobile)
                            Column(
                              children: [
                                _buildMilkMetricsCard(stats),
                                const SizedBox(height: 24),
                                _buildLiveStockCard(stats, primaryColor),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 1, child: _buildMilkMetricsCard(stats)),
                                const SizedBox(width: 24),
                                Expanded(flex: 2, child: _buildLiveStockCard(stats, primaryColor)),
                              ],
                            ),
                        ],
                      ),
                    );
                  }
                ),
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildMilkMetricsCard(DashboardStats stats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Milk Metrics (Liters & Averages)'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            _buildListTileWithSubtitle(
              'Cow Milk Collected'.tr, 
              '${'Avg Fat'.tr}: ${stats.cowAvgFat.toStringAsFixed(1)} | ${'Avg SNF'.tr}: ${stats.cowAvgSnf.toStringAsFixed(1)}',
              '${stats.cowMilk.toStringAsFixed(1)} ${'Qty (L)'.tr}', 
              Icons.pets
            ),
            _buildListTileWithSubtitle(
              'Buffalo Milk Collected'.tr, 
              '${'Avg Fat'.tr}: ${stats.buffaloAvgFat.toStringAsFixed(1)} | ${'Avg SNF'.tr}: ${stats.buffaloAvgSnf.toStringAsFixed(1)}',
              '${stats.buffaloMilk.toStringAsFixed(1)} ${'Qty (L)'.tr}', 
              Icons.pets
            ),
            const Divider(height: 24),
            _buildListTile('Total Sales'.tr, '${stats.milkSoldLtr.toStringAsFixed(1)} ${'Qty (L)'.tr}', Icons.shopping_cart),
          ],
        ),
      ),
    );
  }

  Widget _buildListTileWithSubtitle(String title, String subtitle, String trailing, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600), overflow: TextOverflow.visible),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(trailing, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLiveStockCard(DashboardStats stats, Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Live Stock'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text('${'Total ₹'.tr}: ₹${stats.totalStockValue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 32),
            if (stats.stockDetails.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('No products in stock.'.tr, style: const TextStyle(color: Colors.grey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stats.stockDetails.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = stats.stockDetails[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(flex: 2, child: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 1, child: Text('${'Rate'.tr}: ₹${item['rate']}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                        Expanded(flex: 1, child: Text('${'Stock'.tr}: ${item['stock']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 1, child: Text('₹${item['value'].toStringAsFixed(2)}', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 12))),
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


  void _showRemainingCustomers(BuildContext context, List<Customer> customers) {
    final oweCustomers = customers.where((c) => c.currentBalance > 0).toList();
    oweCustomers.sort((a, b) => b.currentBalance.compareTo(a.currentBalance));
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remaining Amount'.tr),
        content: SizedBox(
          width: 400,
          height: 300,
          child: oweCustomers.isEmpty
            ? Center(child: Text('No pending balances!'.tr))
            : ListView.builder(
                itemCount: oweCustomers.length,
                itemBuilder: (ctx, idx) {
                  final c = oweCustomers[idx];
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.person, color: Colors.white)),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(c.mobile ?? 'No phone'.tr),
                    trailing: Text('₹${c.currentBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                  );
                },
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close'.tr)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(radius: 28, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 32, color: color)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.tr, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(String title, String trailing, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(trailing, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBanner(BuildContext context, WidgetRef ref) {
    if (AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
      return const SizedBox.shrink();
    }

    final subState = ref.watch(subscriptionProvider);
    final sub = subState.currentSubscription;

    if (subState.status == SubscriptionStatus.checking) {
      return const SizedBox.shrink();
    }

    final daysLeft = sub?.daysRemaining ?? 0;
    final planName = sub?.planName ?? 'Subscription';
    final isExpired = subState.status == SubscriptionStatus.expired || (sub != null && daysLeft <= 0);
    final isExpiringSoon = daysLeft > 0 && daysLeft <= 30;

    Color bgColor;
    Color textColor;
    Color borderColor;
    IconData icon;
    String text;
    String actionText;

    if (isExpired) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade900;
      borderColor = Colors.red.shade300;
      icon = Icons.error_outline;
      text = '$planName - Expired! Please renew to continue access.';
      actionText = 'Renew Now';
    } else if (isExpiringSoon) {
      bgColor = Colors.amber.shade50;
      textColor = Colors.amber.shade900;
      borderColor = Colors.amber.shade300;
      icon = Icons.warning_amber_rounded;
      text = '$planName - $daysLeft Days Left (Expires ${sub != null ? DateFormat('dd MMM yyyy').format(sub.endDate) : ''})';
      actionText = 'Extend';
    } else {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade900;
      borderColor = Colors.green.shade200;
      icon = Icons.verified_user_outlined;
      text = '$planName - Active • $daysLeft Days Remaining';
      actionText = 'Details';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: textColor.withOpacity(0.12),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionStatusScreen()),
              );
            },
            child: Text(
              actionText,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
