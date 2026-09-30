import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/settings_provider.dart';
import '../services/app_config.dart';
import '../services/offline_db_helper.dart';
import '../main.dart';
import 'package:url_launcher/url_launcher.dart';
import 'help_center_screen.dart';
import '../providers/language_provider.dart';
import '../services/translations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _dairyNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _headerCtrl;
  late TextEditingController _footerCtrl;
  late TextEditingController _adminPinCtrl;
  
  String? _base64Logo;

  bool _isInit = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dairyNameCtrl = TextEditingController();
    _ownerNameCtrl = TextEditingController();
    _mobileCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _gstCtrl = TextEditingController();
    _headerCtrl = TextEditingController();
    _footerCtrl = TextEditingController();
    _adminPinCtrl = TextEditingController(text: prefs.getString(AppConfig.prefKey('admin_pin')) ?? prefs.getString('offline_admin_pin') ?? '1234');
  }

  @override
  void dispose() {
    _dairyNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    _adminPinCtrl.dispose();
    super.dispose();
  }

  void _initData(AppSettingsModel? settings) {
    if (_isInit) return;
    if (settings != null) {
      _dairyNameCtrl.text = settings.dairyName;
      _ownerNameCtrl.text = settings.ownerName ?? '';
      _mobileCtrl.text = settings.mobile ?? '';
      _addressCtrl.text = settings.address ?? '';
      _gstCtrl.text = settings.gstNo ?? '';
      _headerCtrl.text = settings.receiptHeader ?? '';
      _footerCtrl.text = settings.receiptFooter ?? '';
      _base64Logo = settings.logoUrl;
    } else {
      _dairyNameCtrl.text = 'My Dairy';
    }
    _isInit = true;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300, 
        maxHeight: 300,
        imageQuality: 80, // Compress it down since we are saving as Base64
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _base64Logo = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await ref.read(settingsProvider.notifier).saveSettings(
        dairyName: _dairyNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        gstNo: _gstCtrl.text.trim(),
        header: _headerCtrl.text.trim(),
        footer: _footerCtrl.text.trim(),
        logoBase64: _base64Logo,
      );
      if (AppConfig.isOfflineMode) {
        await prefs.setString(AppConfig.prefKey('admin_pin'), _adminPinCtrl.text.trim());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentLang = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.tr('Settings', currentLang), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (settings) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _initData(settings));

          final isMobile = MediaQuery.of(context).size.width < 600;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Language Mode Selection Card (Permanent i18n)
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blue.shade300, width: 1.5),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade50, Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.translate, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppTranslations.tr('Language Settings', currentLang),
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                                        ),
                                        Text(
                                          AppTranslations.tr('Choose your preferred language for the application', currentLang),
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        await ref.read(languageProvider.notifier).setLanguage('en');
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(AppTranslations.tr('Language changed to English', 'en')),
                                              backgroundColor: Colors.blue.shade800,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: currentLang == 'en' ? Colors.blue.shade800 : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: currentLang == 'en' ? Colors.blue.shade900 : Colors.grey.shade300,
                                            width: currentLang == 'en' ? 2 : 1,
                                          ),
                                          boxShadow: currentLang == 'en'
                                              ? [BoxShadow(color: Colors.blue.shade200, blurRadius: 6, offset: const Offset(0, 3))]
                                              : [],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              currentLang == 'en' ? Icons.check_circle : Icons.radio_button_unchecked,
                                              color: currentLang == 'en' ? Colors.white : Colors.grey,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'English',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: currentLang == 'en' ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        await ref.read(languageProvider.notifier).setLanguage('mr');
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(AppTranslations.tr('Language changed to Marathi', 'mr')),
                                              backgroundColor: Colors.green.shade800,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: currentLang == 'mr' ? Colors.green.shade700 : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: currentLang == 'mr' ? Colors.green.shade900 : Colors.grey.shade300,
                                            width: currentLang == 'mr' ? 2 : 1,
                                          ),
                                          boxShadow: currentLang == 'mr'
                                              ? [BoxShadow(color: Colors.green.shade200, blurRadius: 6, offset: const Offset(0, 3))]
                                              : [],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              currentLang == 'mr' ? Icons.check_circle : Icons.radio_button_unchecked,
                                              color: currentLang == 'mr' ? Colors.white : Colors.grey,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'मराठी (Marathi)',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: currentLang == 'mr' ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Logo Section
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: _base64Logo != null && _base64Logo!.isNotEmpty
                                  ? MemoryImage(base64Decode(_base64Logo!))
                                  : null,
                              child: _base64Logo == null || _base64Logo!.isEmpty
                                  ? Icon(Icons.store, size: 50, color: Colors.grey.shade400)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.upload),
                              label: Text(AppTranslations.tr('Upload Logo', currentLang)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Business Profile Section
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.business, color: primaryColor, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      AppTranslations.tr('General Settings', currentLang),
                                      style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold, color: primaryColor),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _dairyNameCtrl,
                                      decoration: InputDecoration(labelText: '${AppTranslations.tr("Dairy Name", currentLang)} *', border: const OutlineInputBorder()),
                                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _ownerNameCtrl,
                                      decoration: InputDecoration(labelText: AppTranslations.tr('Owner Name', currentLang), border: const OutlineInputBorder()),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _mobileCtrl,
                                      decoration: InputDecoration(labelText: AppTranslations.tr('Mobile Number', currentLang), border: const OutlineInputBorder()),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _gstCtrl,
                                      decoration: InputDecoration(labelText: AppTranslations.tr('GST Number', currentLang), border: const OutlineInputBorder()),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressCtrl,
                                decoration: InputDecoration(labelText: AppTranslations.tr('Address', currentLang), border: const OutlineInputBorder()),
                                maxLines: 2,
                              ),
                              if (AppConfig.isOfflineMode) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _adminPinCtrl,
                                  decoration: InputDecoration(
                                    labelText: AppTranslations.tr('Offline Admin Login PIN (Default: 1234)', currentLang),
                                    hintText: AppTranslations.tr('Enter 4-digit PIN or password', currentLang),
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.lock_outline),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Printing Section
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.print, color: primaryColor, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      AppTranslations.tr('Receipt Printing Details', currentLang),
                                      style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold, color: primaryColor),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              TextFormField(
                                controller: _headerCtrl,
                                decoration: InputDecoration(
                                  labelText: AppTranslations.tr('Receipt Header', currentLang),
                                  helperText: currentLang == 'mr' ? 'उदा. भेट दिल्याबद्दल धन्यवाद!' : 'e.g. Thanks for visiting!',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _footerCtrl,
                                decoration: InputDecoration(
                                  labelText: AppTranslations.tr('Receipt Footer', currentLang),
                                  helperText: currentLang == 'mr' ? 'उदा. पुन्हा भेट द्या' : 'e.g. Visit again',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ),
                          icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.save),
                          label: Text(_isSaving ? (currentLang == 'mr' ? 'जतन करत आहे...' : 'SAVING...') : AppTranslations.tr('Save Settings', currentLang).toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      if (AppConfig.isOfflineMode) ...[
                        const SizedBox(height: 32),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.backup, color: Colors.teal.shade800, size: 28),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        AppTranslations.tr('Local Database Backup & Restore', currentLang),
                                        style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),
                                Text(
                                  AppTranslations.tr('Create a secure local copy of your offline database. You can copy backups to a USB drive or other folder, and restore anytime.', currentLang),
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          final path = await OfflineDbHelper.instance.backupDatabase();
                                          if (context.mounted) {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Row(
                                                  children: [
                                                    const Icon(Icons.check_circle, color: Colors.green),
                                                    const SizedBox(width: 8),
                                                    Text(AppTranslations.tr('Backup Successful', currentLang)),
                                                  ],
                                                ),
                                                content: SelectableText('Database backed up to:\n\n$path'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                                                ],
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      ),
                                      icon: const Icon(Icons.download),
                                      label: const Text('BACKUP DATABASE NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _showRestoreDialog(context),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.teal.shade800,
                                        side: BorderSide(color: Colors.teal.shade700, width: 1.5),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      ),
                                      icon: const Icon(Icons.upload),
                                      label: const Text('RESTORE DATABASE', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.blue.shade50.withValues(alpha: 0.5),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.support_agent, color: Colors.blue.shade800, size: 28),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Help Center & Developer Support',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Yu_Vi Development (Mr. Vikram Malhari Pawar)\nPhone / WhatsApp: +91 6361782144 | Email: Vikrams4727@gmail.com',
                                style: TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.help_center, size: 18),
                                    label: const Text('OPEN HELP CENTER', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final uri = Uri(scheme: 'tel', path: '6361782144');
                                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue.shade900,
                                      side: BorderSide(color: Colors.blue.shade700),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.call, size: 18),
                                    label: const Text('CALL 6361782144', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRestoreDialog(BuildContext context) {
    final pathCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Database from Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the full path of the .db backup file you want to restore:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathCtrl,
              decoration: const InputDecoration(
                hintText: 'C:\\path\\to\\dairy_backup.db',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final target = pathCtrl.text.trim();
              if (target.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await OfflineDbHelper.instance.restoreDatabase(target);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Database restored successfully!'), backgroundColor: Colors.green),
                  );
                  ref.invalidate(settingsProvider);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('RESTORE NOW'),
          ),
        ],
      ),
    );
  }
}
