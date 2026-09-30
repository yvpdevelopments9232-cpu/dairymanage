import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_config.dart';
import '../widgets/sync_status_badge.dart';
import 'login_screen.dart';
import 'sub_login_screen.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/translations.dart';
import '../providers/display_mode_provider.dart';
import '../widgets/desktop_wrapper.dart';
import 'farmer_screen.dart';
import 'milk_collection_screen.dart';
import 'rate_management_screen.dart';
import 'customer_screen.dart';
import 'sales_screen.dart';
import 'product_screen.dart';
import 'supplier_screen.dart';
import 'purchase_screen.dart';
import 'payment_screen.dart';
import 'stock_screen.dart';
import 'reports_screen.dart';
import 'staff_screen.dart';
import 'advance_screen.dart';
import 'animal_screen.dart';
import 'settings_screen.dart';
import 'employee_management_screen.dart';
import 'employee_rights_screen.dart';
import 'backup_restore_screen.dart';
import 'expense_screen.dart';
import '../providers/settings_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/sync_service.dart';
import '../widgets/dashboard_home.dart';
import '../providers/session_provider.dart';
import 'subscription/subscription_status_screen.dart';
import 'help_center_screen.dart';

import '../models/flutter_models.dart';
import '../providers/product_provider.dart';

// Main Dairy Module screens
import 'main_dairy/main_dairy_dashboard_screen.dart';
import 'main_dairy/main_dairy_list_screen.dart';
import 'main_dairy/main_dairy_collection_screen.dart';
import 'main_dairy/main_dairy_rate_screen.dart';
import 'main_dairy/main_dairy_reports_screen.dart';
import 'main_dairy/main_dairy_payment_screen.dart';
import 'main_dairy/bonus/bonus_dashboard_screen.dart';
import 'main_dairy/bonus/bonus_settings_screen.dart';
import 'main_dairy/bonus/paid_bonus_screen.dart';
import 'main_dairy/bonus/remaining_bonus_screen.dart';
import 'main_dairy/bonus/bonus_transactions_screen.dart';
import 'local_dairy_bonus_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // To keep track of the currently selected menu item
  int _selectedIndex = 0;

  // Main Dairy sub-portal mode
  bool _isMainDairyMode = false;
  int _mainDairySelectedIndex = 0;
  String _mainDairySelectedMenu = 'Dashboard';
  bool _isBonusExpanded = false;
  bool _isLocalDairyBonusExpanded = false;
  String _localDairyBonusSelectedSub = 'Bonus Dashboard';

  // Track if stock alert was shown this session
  bool _hasShownStockAlert = false;

  @override
  void initState() {
    super.initState();
    SyncService.instance.syncVersion.addListener(_onSyncUpdate);
  }

  @override
  void dispose() {
    SyncService.instance.syncVersion.removeListener(_onSyncUpdate);
    super.dispose();
  }

  void _onSyncUpdate() {
    if (mounted) {
      ref.invalidate(settingsProvider);
      ref.invalidate(dashboardStatsProvider);
    }
  }

  final List<String> _menuItems = [
    'Dashboard',
    'Farmers',
    'Animals',
    'Milk Collection',
    'Sales',
    'Customers',
    'Products',
    'Stock',
    'Suppliers',
    'Purchases',
    'Payments',
    'Expenses',
    'Staff',
    'Advances',
    'Reports',
    'Rate Management',
    'Bonus',
    'Main Dairy', // <--- Dedicated Entry Point
    'Employee Management',
    'Employee Rights',
    'Backup & Restore',
    'Subscription',
    'Help Center',
    'Settings',
    'Switch Account'
  ];

  final List<String> _mainDairyMenuItems = [
    'Dashboard',
    'Milk Collection',
    'Farmers / Members',
    'Milk Purchase',
    'Milk Sale',
    'Payments',
    'Rate Management',
    'Bonus',
    'Bank',
    'Reports',
    'Help Center',
    '⬅ Back to Local Dairy',
  ];

  Future<void> _confirmLogout(BuildContext context) async {
    final lang = ref.read(languageProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.power_settings_new, color: Colors.red),
            const SizedBox(width: 8),
            Text(AppTranslations.tr('Logout Confirmation', lang)),
          ],
        ),
        content: Text(AppTranslations.tr('Are you sure you want to log out of your account?', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppTranslations.tr('CANCEL', lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppTranslations.tr('LOGOUT', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(sessionProvider.notifier).logoutSubAccount();
      await prefs.setBool(AppConfig.prefKey('is_logged_in'), false);
      await prefs.remove(AppConfig.prefKey('active_sub_account_type'));
      try {
        await ref.read(authRepositoryProvider).logOut();
      } catch (_) {}
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showDisplayModeDialog(BuildContext context) {
    final lang = ref.read(languageProvider);

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final activeMode = ref.watch(displayModeProvider);
          final primaryColor = Theme.of(context).colorScheme.primary;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.tune, color: primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppTranslations.tr('Select Display Mode', lang),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Option 1: Previous / Desktop Mode
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        ref.read(displayModeProvider.notifier).setDisplayMode(DisplayMode.previous);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppTranslations.tr('Previous / Desktop Mode', lang)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: activeMode == DisplayMode.previous ? Colors.blue.shade50 : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: activeMode == DisplayMode.previous ? Colors.blue.shade400 : Colors.grey.shade300,
                            width: activeMode == DisplayMode.previous ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<DisplayMode>(
                              value: DisplayMode.previous,
                              groupValue: activeMode,
                              activeColor: primaryColor,
                              onChanged: (mode) {
                                if (mode != null) {
                                  ref.read(displayModeProvider.notifier).setDisplayMode(mode);
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(AppTranslations.tr('Previous / Desktop Mode', lang)),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppTranslations.tr('Previous / Desktop Mode', lang),
                                    style: TextStyle(
                                      fontWeight: activeMode == DisplayMode.previous ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 15,
                                      color: activeMode == DisplayMode.previous ? Colors.blue.shade900 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppTranslations.tr('Preserves original desktop layout and zoom controls', lang),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.desktop_windows, color: Colors.blue, size: 22),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Option 2: Mobile Mode
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        ref.read(displayModeProvider.notifier).setDisplayMode(DisplayMode.mobile);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppTranslations.tr('Mobile Mode', lang)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: activeMode == DisplayMode.mobile ? Colors.green.shade50 : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: activeMode == DisplayMode.mobile ? Colors.green.shade400 : Colors.grey.shade300,
                            width: activeMode == DisplayMode.mobile ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<DisplayMode>(
                              value: DisplayMode.mobile,
                              groupValue: activeMode,
                              activeColor: Colors.green.shade700,
                              onChanged: (mode) {
                                if (mode != null) {
                                  ref.read(displayModeProvider.notifier).setDisplayMode(mode);
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(AppTranslations.tr('Mobile Mode', lang)),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppTranslations.tr('Mobile Mode', lang),
                                    style: TextStyle(
                                      fontWeight: activeMode == DisplayMode.mobile ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 15,
                                      color: activeMode == DisplayMode.mobile ? Colors.green.shade900 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppTranslations.tr('Responsive touch-friendly layout optimized for mobile', lang),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.smartphone, color: Colors.green.shade800, size: 22),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppTranslations.tr('CANCEL', lang)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final lang = ref.read(languageProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final activeLang = ref.watch(languageProvider);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.translate, color: primaryColor),
                const SizedBox(width: 10),
                Text(
                  AppTranslations.tr('Select Language', activeLang),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // English
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: activeLang == 'en' ? Colors.blue.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: activeLang == 'en' ? Colors.blue.shade400 : Colors.grey.shade300,
                        width: activeLang == 'en' ? 2 : 1,
                      ),
                    ),
                    child: RadioListTile<String>(
                      value: 'en',
                      groupValue: activeLang,
                      activeColor: primaryColor,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('EN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ),
                      title: const Text('English', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: const Text('Default English display', style: TextStyle(fontSize: 12)),
                      onChanged: (val) async {
                        if (val != null) {
                          Navigator.pop(ctx);
                          await ref.read(languageProvider.notifier).setLanguage(val);
                        }
                      },
                    ),
                  ),

                  // Marathi
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: activeLang == 'mr' ? Colors.orange.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: activeLang == 'mr' ? Colors.orange.shade400 : Colors.grey.shade300,
                        width: activeLang == 'mr' ? 2 : 1,
                      ),
                    ),
                    child: RadioListTile<String>(
                      value: 'mr',
                      groupValue: activeLang,
                      activeColor: Colors.deepOrange,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('म', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ),
                      title: const Text('मराठी (Marathi)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: const Text('संपूर्ण सॉफ्टवेअर शुद्ध मराठीत भाषांतरित करा', style: TextStyle(fontSize: 12)),
                      onChanged: (val) async {
                        if (val != null) {
                          Navigator.pop(ctx);
                          await ref.read(languageProvider.notifier).setLanguage(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppTranslations.tr('CANCEL', activeLang)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context, List<Product> outOfStockProducts) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: outOfStockProducts.isNotEmpty ? Colors.red.shade50 : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                outOfStockProducts.isNotEmpty ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: outOfStockProducts.isNotEmpty ? Colors.red.shade700 : Colors.green.shade700,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(
                    outOfStockProducts.isNotEmpty
                        ? '${outOfStockProducts.length} product stock alert(s)'
                        : 'All product stocks are available',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: outOfStockProducts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 60, color: Colors.green.shade300),
                      const SizedBox(height: 12),
                      const Text(
                        'All Products In Stock',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'None of your products are currently out of stock.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: outOfStockProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = outOfStockProducts[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2.0),
                              child: Icon(Icons.error_outline, color: Colors.red, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reminder: your ${p.name} stock is out of stock',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Available: ${p.currentStock.toStringAsFixed(1)} ${p.unit} | Category: ${p.category ?? "General"}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _isMainDairyMode = false;
                                  _selectedIndex = _menuItems.indexOf('Products');
                                });
                              },
                              child: const Text('Restock'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          if (outOfStockProducts.isNotEmpty)
            OutlinedButton.icon(
              icon: const Icon(Icons.inventory_2, size: 16),
              label: const Text('Go to Products'),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isMainDairyMode = false;
                  _selectedIndex = _menuItems.indexOf('Products');
                });
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final displayMode = ref.watch(displayModeProvider);
    final isDesktop = displayMode == DisplayMode.previous && MediaQuery.of(context).size.width >= 1000;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final outOfStockProducts = ref.watch(outOfStockProductsProvider);

    // Automatic reminder notification when opening Dashboard if products are out of stock
    if (outOfStockProducts.isNotEmpty && !_hasShownStockAlert) {
      _hasShownStockAlert = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final firstNames = outOfStockProducts.take(2).map((p) => p.name).join(', ');
          final extra = outOfStockProducts.length > 2 ? ' and ${outOfStockProducts.length - 2} more' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reminder: your $firstNames$extra stock is out of stock',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'VIEW',
                textColor: Colors.amberAccent,
                onPressed: () => _showNotificationsDialog(context, outOfStockProducts),
              ),
            ),
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: isDesktop
            ? null
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  tooltip: AppTranslations.tr('Open Menu', lang),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        title: Text(
          _isMainDairyMode
              ? AppTranslations.tr('Main Dairy Portal', lang)
              : (ref.watch(sessionProvider)?.isAdmin == true
                  ? AppTranslations.tr('Dairy Management', lang)
                  : '${ref.watch(sessionProvider)?.activeEmployee?.name ?? ""} - ${AppTranslations.tr("Dairy Management", lang)}'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        backgroundColor: _isMainDairyMode ? Colors.indigo.shade800 : primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (AppConfig.isHybridMode)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: SyncStatusBadge(),
            ),
          if (_isMainDairyMode && isDesktop)
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: Text(AppTranslations.tr('Local Dairy', lang).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                setState(() {
                  _isMainDairyMode = false;
                  _selectedIndex = 0;
                });
              },
            ),
          Badge(
            isLabelVisible: outOfStockProducts.isNotEmpty,
            label: Text(
              '${outOfStockProducts.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            backgroundColor: Colors.redAccent,
            child: IconButton(
              icon: Icon(
                outOfStockProducts.isNotEmpty ? Icons.notifications_active : Icons.notifications,
                color: outOfStockProducts.isNotEmpty ? Colors.amberAccent : Colors.white,
              ),
              tooltip: outOfStockProducts.isNotEmpty
                  ? '${outOfStockProducts.length} product(s) out of stock!'
                  : 'Notifications',
              onPressed: () => _showNotificationsDialog(context, outOfStockProducts),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.support_agent),
            tooltip: 'Help Center (Yu_Vi Development)',
            onPressed: () {
              final helpIndex = _menuItems.indexOf('Help Center');
              if (helpIndex != -1) {
                setState(() {
                  _isMainDairyMode = false;
                  _selectedIndex = helpIndex;
                });
              }
            },
          ),
          // User Avatar / Logo Icon
          Consumer(
            builder: (context, ref, child) {
              final settingsAsync = ref.watch(settingsProvider);
              final logoBytes = settingsAsync.value?.logoBytes;
              if (logoBytes != null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundImage: MemoryImage(logoBytes),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Three-Dot Menu (⋮)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: AppTranslations.tr('Options', lang),
            onSelected: (val) {
              if (val == 'local_dairy') {
                setState(() {
                  _isMainDairyMode = false;
                  _selectedIndex = 0;
                });
              } else if (val == 'mode') {
                _showDisplayModeDialog(context);
              } else if (val == 'language') {
                _showLanguageDialog(context);
              } else if (val == 'mode_desktop') {
                ref.read(displayModeProvider.notifier).setDisplayMode(DisplayMode.previous);
              } else if (val == 'mode_mobile') {
                ref.read(displayModeProvider.notifier).setDisplayMode(DisplayMode.mobile);
              } else if (val == 'logout') {
                _confirmLogout(context);
              } else if (val == 'help') {
                final helpIndex = _menuItems.indexOf('Help Center');
                if (helpIndex != -1) {
                  setState(() {
                    _isMainDairyMode = false;
                    _selectedIndex = helpIndex;
                  });
                }
              } else if (val == 'switch') {
                ref.read(sessionProvider.notifier).logoutSubAccount();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SubLoginScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (ctx) {
              final activeDisplayMode = ref.read(displayModeProvider);
              return [
                if (_isMainDairyMode)
                  PopupMenuItem(
                    value: 'local_dairy',
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          AppTranslations.tr('Local Dairy', lang),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                // 1. Mode Option
                PopupMenuItem(
                  value: 'mode',
                  child: Row(
                    children: [
                      Icon(
                        activeDisplayMode == DisplayMode.mobile ? Icons.smartphone : Icons.desktop_windows,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppTranslations.tr('Mode', lang),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: activeDisplayMode == DisplayMode.mobile ? Colors.green.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: activeDisplayMode == DisplayMode.mobile ? Colors.green.shade300 : Colors.blue.shade300,
                          ),
                        ),
                        child: Text(
                          activeDisplayMode == DisplayMode.mobile
                              ? AppTranslations.tr('Mobile Mode', lang)
                              : AppTranslations.tr('Previous / Desktop Mode', lang),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: activeDisplayMode == DisplayMode.mobile ? Colors.green.shade800 : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 2. Language Option
                PopupMenuItem(
                  value: 'language',
                  child: Row(
                    children: [
                      Icon(
                        Icons.translate,
                        color: Colors.orange.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppTranslations.tr('Language', lang),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: lang == 'mr' ? Colors.orange.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: lang == 'mr' ? Colors.orange.shade300 : Colors.blue.shade300,
                          ),
                        ),
                        child: Text(
                          lang == 'mr' ? 'मराठी' : 'English',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: lang == 'mr' ? Colors.orange.shade900 : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                // 2. Help Center
                PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      const Icon(Icons.support_agent, color: Colors.blue, size: 20),
                      const SizedBox(width: 10),
                      Text(AppTranslations.tr('Help Center', lang)),
                    ],
                  ),
                ),
                // 3. Switch Account
                PopupMenuItem(
                  value: 'switch',
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, color: Colors.blue, size: 20),
                      const SizedBox(width: 10),
                      Text(AppTranslations.tr('Switch Account', lang)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                // 4. Logout
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Text(AppTranslations.tr('Logout', lang), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      drawer: isDesktop ? null : _buildDrawer(),
      body: Row(
        children: [
          if (isDesktop)
            Container(
              width: 250,
              color: Colors.orange,
              child: _buildDrawerContent(),
            ),
          if (isDesktop)
            const VerticalDivider(width: 1, thickness: 1),
          
          // Main Content Area
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.orange,
      child: _buildDrawerContent(),
    );
  }

  Widget _buildDrawerContent() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final settingsAsync = ref.watch(settingsProvider);
    final dairyName = settingsAsync.value?.dairyName ?? 'My Dairy';
    final logoBytes = settingsAsync.value?.logoBytes;
    final lang = ref.watch(languageProvider);

    return Column(
      children: [
        if (_isMainDairyMode)
          Container(
            height: 140,
            width: double.infinity,
            color: Colors.indigo.shade900,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.domain, size: 44, color: Colors.white),
                const SizedBox(height: 8),
                Text(AppTranslations.tr('MAIN DAIRY PORTAL', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(AppTranslations.tr('Outward Milk Dispatches & Rates', lang), style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          )
        else
          Container(
            height: 140,
            width: double.infinity,
            color: primaryColor.withValues(alpha: 0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (logoBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      logoBytes, 
                      height: 60, width: 60, fit: BoxFit.cover
                    ),
                  )
                else
                  Icon(Icons.water_drop, size: 40, color: primaryColor),
                
                const SizedBox(height: 12),
                Text(
                  dairyName,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
          ),
        Expanded(
          child: _isMainDairyMode ? _buildMainDairyMenu() : _buildLocalDairyMenu(),
        ),
        const Divider(height: 1),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _confirmLogout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
            ),
            icon: const Icon(Icons.power_settings_new),
            label: Text(AppTranslations.tr('LOGOUT', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
          ),
        ),
      ],
    );
  }

  Widget _buildMainDairyMenu() {
    final bonusSubItems = [
      'Bonus Dashboard',
      'Bonus Settings',
      'Paid Bonus',
      'Remaining Bonus',
      'Bonus Transactions',
    ];

    final isBonusActive = _mainDairySelectedMenu.startsWith('Bonus');

    return ListView(
      children: [
        _buildMainDairyTile('Dashboard', Icons.dashboard),
        _buildMainDairyTile('Milk Collection', Icons.local_drink),
        _buildMainDairyTile('Farmers / Members', Icons.people),
        _buildMainDairyTile('Milk Purchase', Icons.shopping_cart),
        _buildMainDairyTile('Milk Sale', Icons.storefront),
        _buildMainDairyTile('Payments', Icons.payments),
        _buildMainDairyTile('Rate Management', Icons.price_change),
        // Bonus Expandable Tree
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black87, width: 1),
            borderRadius: BorderRadius.circular(8),
            color: isBonusActive ? Colors.indigo.shade800 : Colors.blue,
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.workspace_premium, color: Colors.white),
                title: Text(
                  AppTranslations.tr('Bonus', ref.watch(languageProvider)),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                trailing: Icon(
                  _isBonusExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
                onTap: () {
                  setState(() {
                    _isBonusExpanded = !_isBonusExpanded;
                    if (_isBonusExpanded && !_mainDairySelectedMenu.startsWith('Bonus')) {
                      _mainDairySelectedMenu = 'Bonus Dashboard';
                    }
                  });
                },
              ),
              if (_isBonusExpanded)
                Container(
                  padding: const EdgeInsets.only(bottom: 6),
                  color: Colors.indigo.shade900.withValues(alpha: 0.4),
                  child: Column(
                    children: bonusSubItems.map((sub) {
                      final isSubSelected = _mainDairySelectedMenu == sub;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: isSubSelected ? Colors.indigo.shade600 : Colors.transparent,
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 24, right: 12),
                          leading: _getIconForMenu(sub, isSubSelected),
                          title: Text(
                            AppTranslations.tr(sub, ref.watch(languageProvider)),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSubSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSubSelected ? Colors.white : Colors.white70,
                            ),
                          ),
                          onTap: () {
                            setState(() => _mainDairySelectedMenu = sub);
                            if (!MediaQuery.of(context).size.width.isFinite || MediaQuery.of(context).size.width < 800) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        _buildMainDairyTile('Bank', Icons.account_balance),
        _buildMainDairyTile('Reports', Icons.bar_chart),
        _buildMainDairyTile('Help Center', Icons.support_agent),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black87, width: 1),
            borderRadius: BorderRadius.circular(8),
            color: Colors.deepOrange.shade800,
          ),
          child: ListTile(
            leading: const Icon(Icons.arrow_back, color: Colors.white),
            title: Text(
              AppTranslations.tr('⬅ Back to Local Dairy', ref.watch(languageProvider)),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onTap: () {
              setState(() {
                _isMainDairyMode = false;
                _selectedIndex = 0;
              });
              if (!MediaQuery.of(context).size.width.isFinite || MediaQuery.of(context).size.width < 800) {
                Navigator.pop(context);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMainDairyTile(String title, IconData icon) {
    final isSelected = _mainDairySelectedMenu == title;
    final lang = ref.watch(languageProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87, width: 1),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? Colors.blue.shade800 : Colors.blue,
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          AppTranslations.tr(title, lang),
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: Colors.white,
          ),
        ),
        onTap: () {
          setState(() => _mainDairySelectedMenu = title);
          if (!MediaQuery.of(context).size.width.isFinite || MediaQuery.of(context).size.width < 800) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildLocalDairyMenu() {
    return ListView.builder(
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final menu = _menuItems[index];
        final isSelected = _selectedIndex == index;

        if (menu == 'Subscription' && AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
          return const SizedBox.shrink();
        }

        if (menu == 'Bonus') {
          final isBonusActive = isSelected;
          final bonusSubItems = [
            'Bonus Dashboard',
            'Bonus Settings',
            'Paid Bonus',
            'Remaining Bonus',
            'Bonus Transactions',
            'Local Dairy Bonus Slip',
          ];

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black87, width: 1),
              borderRadius: BorderRadius.circular(8),
              color: isBonusActive ? Colors.blue.shade800 : Colors.blue,
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.workspace_premium, color: Colors.white),
                  title: Text(
                    AppTranslations.tr('Bonus', ref.watch(languageProvider)),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  trailing: Icon(
                    _isLocalDairyBonusExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                  onTap: () {
                    setState(() {
                      _isLocalDairyBonusExpanded = !_isLocalDairyBonusExpanded;
                      _selectedIndex = index;
                    });
                  },
                ),
                if (_isLocalDairyBonusExpanded)
                  Container(
                    padding: const EdgeInsets.only(bottom: 6),
                    color: Colors.blue.shade900.withValues(alpha: 0.4),
                    child: Column(
                      children: bonusSubItems.map((sub) {
                        final isSubSelected = isBonusActive && _localDairyBonusSelectedSub == sub;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: isSubSelected ? Colors.blue.shade600 : Colors.transparent,
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.only(left: 24, right: 12),
                            leading: _getIconForMenu(sub, isSubSelected),
                            title: Text(
                              AppTranslations.tr(sub, ref.watch(languageProvider)),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSubSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSubSelected ? Colors.white : Colors.white70,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedIndex = index;
                                _localDairyBonusSelectedSub = sub;
                              });
                              if (!MediaQuery.of(context).size.width.isFinite || MediaQuery.of(context).size.width < 800) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black87, width: 1),
            borderRadius: BorderRadius.circular(8),
            color: menu == 'Main Dairy'
                ? Colors.indigo.shade700
                : (isSelected ? Colors.blue.shade800 : Colors.blue),
          ),
          child: ListTile(
            leading: _getIconForMenu(menu, isSelected),
            title: Text(
              AppTranslations.tr(menu, ref.watch(languageProvider)),
              style: TextStyle(
                fontWeight: isSelected || menu == 'Main Dairy' ? FontWeight.bold : FontWeight.normal,
                color: Colors.white,
              ),
            ),
            selected: isSelected,
            onTap: () {
              if (menu == 'Main Dairy') {
                setState(() {
                  _isMainDairyMode = true;
                  _mainDairySelectedMenu = 'Dashboard';
                });
                if (!MediaQuery.of(context).size.width.isFinite || MediaQuery.of(context).size.width < 800) {
                  Navigator.pop(context);
                }
                return;
              }

              if (menu == "Switch Account") {
                ref.read(sessionProvider.notifier).logoutSubAccount();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SubLoginScreen()),
                  (route) => false,
                );
                return;
              }

              final session = ref.read(sessionProvider);
              bool allowed = false;

              if (session == null || session.isAdmin) {
                allowed = true;
              } else {
                if (menu == 'Help Center') {
                  allowed = true; // Accessible by all users
                } else if (menu == "Employee Management" || menu == "Employee Rights" || menu == "Settings" || menu == "Backup & Restore" || menu == "Subscription") {
                  allowed = false; // Strictly admin only
                } else {
                  allowed = session.canView(menu);
                }
              }

              if (!allowed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("You do not have permission to access $menu."), backgroundColor: Colors.red),
                );
                return;
              }

              setState(() {
                _selectedIndex = index;
              });
              if (!MediaQuery.of(context).size.width.isFinite || MediaQuery.of(context).size.width < 800) {
                Navigator.pop(context); // Close drawer on mobile
              }
            },
          ),
        );
      },
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.white,
      Colors.orange.shade50,
      Colors.brown.shade50,
      Colors.blue.shade50,
      Colors.purple.shade50,
      Colors.indigo.shade50,
      Colors.pink.shade50,
      Colors.teal.shade50,
      Colors.amber.shade50,
      Colors.cyan.shade50,
      Colors.green.shade50,
      Colors.red.shade50,
      Colors.yellow.shade50,
      Colors.deepOrange.shade50,
      Colors.grey.shade50,
      Colors.lightBlue.shade50,
      Colors.blueGrey.shade50,
      Colors.blueGrey.shade50,
    ];
    return colors[index % colors.length];
  }

  Widget _buildMainContent() {
    final lang = ref.watch(languageProvider);
    final displayMode = ref.watch(displayModeProvider);

    if (_isMainDairyMode) {
      Widget mainDairyContent;
      switch (_mainDairySelectedMenu) {
        case 'Dashboard':
          mainDairyContent = DesktopWrapper(
            child: MainDairyDashboardScreen(
              onNavigate: (targetIndex) {
                setState(() {
                  if (targetIndex == 0) _mainDairySelectedMenu = 'Dashboard';
                  else if (targetIndex == 1) _mainDairySelectedMenu = 'Farmers / Members';
                  else if (targetIndex == 2) _mainDairySelectedMenu = 'Milk Collection';
                  else if (targetIndex == 3) _mainDairySelectedMenu = 'Rate Management';
                  else if (targetIndex == 4) _mainDairySelectedMenu = 'Reports';
                });
              },
            ),
          );
          break;
        case 'Milk Collection':
          mainDairyContent = DesktopWrapper(child: const MainDairyCollectionScreen());
          break;
        case 'Farmers / Members':
        case 'Main Dairies':
        case 'Main Dairies / Members':
          mainDairyContent = DesktopWrapper(child: const MainDairyListScreen());
          break;
        case 'Milk Purchase':
          mainDairyContent = DesktopWrapper(child: const PurchaseScreen());
          break;
        case 'Milk Sale':
          mainDairyContent = DesktopWrapper(child: const SalesScreen());
          break;
        case 'Payments':
        case 'Bank':
        case 'Payments & Ledgers':
          mainDairyContent = DesktopWrapper(child: const MainDairyPaymentScreen());
          break;
        case 'Bonus':
        case 'Bonus Dashboard':
          mainDairyContent = DesktopWrapper(
            child: BonusDashboardScreen(
              onNavigateSubTab: (tabIdx) {
                setState(() {
                  if (tabIdx == 1) _mainDairySelectedMenu = 'Bonus Settings';
                  else if (tabIdx == 2) _mainDairySelectedMenu = 'Paid Bonus';
                  else if (tabIdx == 3) _mainDairySelectedMenu = 'Remaining Bonus';
                  else if (tabIdx == 4) _mainDairySelectedMenu = 'Bonus Transactions';
                });
              },
            ),
          );
          break;
        case 'Bonus Settings':
          mainDairyContent = DesktopWrapper(child: const BonusSettingsScreen());
          break;
        case 'Paid Bonus':
          mainDairyContent = DesktopWrapper(child: const PaidBonusScreen());
          break;
        case 'Remaining Bonus':
          mainDairyContent = DesktopWrapper(child: const RemainingBonusScreen());
          break;
        case 'Bonus Transactions':
          mainDairyContent = DesktopWrapper(child: const BonusTransactionsScreen());
          break;
        case 'Reports':
          mainDairyContent = DesktopWrapper(child: const MainDairyReportsScreen());
          break;
        case 'Rate Management':
          mainDairyContent = const MainDairyRateScreen();
          break;
        case 'Help Center':
          mainDairyContent = DesktopWrapper(child: const HelpCenterScreen());
          break;
        default:
          mainDairyContent = DesktopWrapper(
            child: MainDairyDashboardScreen(
              onNavigate: (targetIndex) {},
            ),
          );
      }
      return KeyedSubtree(
        key: ValueKey('main_dairy_${_mainDairySelectedMenu}_${lang}_$displayMode'),
        child: Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: Colors.indigo.shade50.withOpacity(0.3),
          ),
          child: mainDairyContent,
        ),
      );
    }

    final menu = _menuItems[_selectedIndex];
    Widget content;
    switch (menu) {
      case 'Dashboard':
        content = DesktopWrapper(
          child: DashboardHome(
            onNavigateToProducts: () {
              setState(() {
                _isMainDairyMode = false;
                _selectedIndex = _menuItems.indexOf('Products');
              });
            },
          ),
        );
        break;
      case 'Farmers': content = DesktopWrapper(child: const FarmerScreen()); break;
      case 'Animals': content = DesktopWrapper(child: const AnimalScreen()); break;
      case 'Milk Collection': content = DesktopWrapper(child: const MilkCollectionScreen()); break;
      case 'Sales': content = DesktopWrapper(child: const SalesScreen()); break;
      case 'Customers': content = DesktopWrapper(child: const CustomerScreen()); break;
      case 'Products': content = DesktopWrapper(child: const ProductScreen()); break;
      case 'Stock': content = DesktopWrapper(child: const StockScreen()); break;
      case 'Suppliers': content = DesktopWrapper(child: const SupplierScreen()); break;
      case 'Purchases': content = DesktopWrapper(child: const PurchaseScreen()); break;
      case 'Payments': content = DesktopWrapper(child: const PaymentScreen()); break;
      case 'Expenses': content = DesktopWrapper(child: const ExpenseScreen()); break;
      case 'Staff': content = DesktopWrapper(child: const StaffScreen()); break;
      case 'Advances': content = DesktopWrapper(child: const AdvanceScreen()); break;
      case 'Reports': content = DesktopWrapper(child: const ReportsScreen()); break;
      case 'Rate Management': content = const RateManagementScreen(); break;
      case 'Bonus':
        switch (_localDairyBonusSelectedSub) {
          case 'Bonus Dashboard':
            content = DesktopWrapper(child: const BonusDashboardScreen());
            break;
          case 'Bonus Settings':
            content = DesktopWrapper(child: const BonusSettingsScreen());
            break;
          case 'Paid Bonus':
            content = DesktopWrapper(child: const PaidBonusScreen());
            break;
          case 'Remaining Bonus':
            content = DesktopWrapper(child: const RemainingBonusScreen());
            break;
          case 'Bonus Transactions':
            content = DesktopWrapper(child: const BonusTransactionsScreen());
            break;
          case 'Local Dairy Bonus Slip':
          default:
            content = DesktopWrapper(child: const LocalDairyBonusScreen());
            break;
        }
        break;
      case 'Settings': content = DesktopWrapper(child: const SettingsScreen()); break;
      case 'Employee Management': content = DesktopWrapper(child: const EmployeeManagementScreen()); break;
      case 'Employee Rights': content = DesktopWrapper(child: const EmployeeRightsScreen()); break;
      case 'Backup & Restore': content = DesktopWrapper(child: const BackupRestoreScreen()); break;
      case 'Subscription': content = DesktopWrapper(child: const SubscriptionStatusScreen()); break;
      case 'Help Center': content = DesktopWrapper(child: const HelpCenterScreen()); break;
      default: content = const Center(child: Text('Coming Soon!'));
    }
    return KeyedSubtree(
      key: ValueKey('${menu}_${lang}_$displayMode'),
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: _getColorForIndex(_selectedIndex),
        ),
        child: content,
      ),
    );
  }

  Icon _getIconForMenu(String menu, bool isSelected) {
    IconData iconData;
    switch (menu) {
      case 'Dashboard': iconData = Icons.dashboard; break;
      case 'Farmers': iconData = Icons.people; break;
      case 'Animals': iconData = Icons.pets; break;
      case 'Milk Collection': iconData = Icons.local_drink; break;
      case 'Sales': iconData = Icons.storefront; break;
      case 'Customers': iconData = Icons.groups; break;
      case 'Products': iconData = Icons.inventory_2; break;
      case 'Stock': iconData = Icons.warehouse; break;
      case 'Suppliers': iconData = Icons.local_shipping; break;
      case 'Purchases': iconData = Icons.shopping_cart; break;
      case 'Payments': iconData = Icons.payments; break;
      case 'Expenses': iconData = Icons.receipt_long; break;
      case 'Staff': iconData = Icons.badge; break;
      case 'Advances': iconData = Icons.payments_outlined; break;
      case 'Reports': iconData = Icons.bar_chart; break;
      case 'Rate Management': iconData = Icons.price_change; break;
      case 'Bonus': iconData = Icons.workspace_premium; break;
      case 'Bonus Dashboard': iconData = Icons.dashboard; break;
      case 'Bonus Settings': iconData = Icons.tune; break;
      case 'Paid Bonus': iconData = Icons.check_circle_outline; break;
      case 'Remaining Bonus': iconData = Icons.schedule; break;
      case 'Bonus Transactions': iconData = Icons.receipt_long; break;
      case 'Local Dairy Bonus Slip': iconData = Icons.receipt_long; break;
      case 'Bank': iconData = Icons.account_balance; break;
      case 'Farmers / Members': iconData = Icons.people; break;
      case 'Milk Purchase': iconData = Icons.shopping_cart; break;
      case 'Milk Sale': iconData = Icons.storefront; break;
      case 'Main Dairy': iconData = Icons.domain; break;
      case '⬅ Back to Local Dairy': iconData = Icons.arrow_back; break;
      case 'Main Dairies': iconData = Icons.business; break;
      case 'Settings': iconData = Icons.settings; break;
      case 'Backup & Restore': iconData = Icons.settings_backup_restore; break;
      case 'Subscription': iconData = Icons.card_membership; break;
      case 'Help Center': iconData = Icons.support_agent; break;
      case 'Switch Account': iconData = Icons.swap_horiz; break;
      case 'Employee Management': iconData = Icons.admin_panel_settings; break;
      case 'Employee Rights': iconData = Icons.security; break;
      default: iconData = Icons.circle;
    }
    return Icon(iconData, color: Colors.white);
  }
}
