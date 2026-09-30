import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_config.dart';
import '../providers/session_provider.dart';
import '../services/translations.dart';
import '../providers/language_provider.dart';

class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  // Official Contact Details
  static const String developerName = 'Yu_Vi Development';
  static const String leadDeveloper = 'Mr. Vikram Malhari Pawar';
  static const String primaryPhone = '6361782144';
  static const String internationalPhone = '+91 6361782144';
  static const String primaryEmail = 'Vikrams4727@gmail.com';
  static const String alternateEmail = 'yvpdevelopments9232@gmail.com';
  static const String supportHours = '7:00 AM – 10:00 PM IST (Mon – Sun)';

  // Inquiry Form Controllers
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController(text: 'General Inquiry / Support');
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _makeCall() async {
    final uri = Uri(scheme: 'tel', path: primaryPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _copyToClipboard(primaryPhone, 'Phone number copied to clipboard: $primaryPhone');
      }
    } catch (_) {
      _copyToClipboard(primaryPhone, 'Dial directly: $primaryPhone');
    }
  }

  Future<void> _openWhatsApp({String? customMessage}) async {
    final text = customMessage ??
        'Hello Yu_Vi Development, I need support with the Dairy Management Application.';
    final encoded = Uri.encodeComponent(text);
    final uri = Uri.parse('https://wa.me/91$primaryPhone?text=$encoded');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _copyToClipboard(primaryPhone, 'WhatsApp number copied: $primaryPhone');
      }
    } catch (_) {
      _copyToClipboard(primaryPhone, 'Contact on WhatsApp: $primaryPhone');
    }
  }

  Future<void> _sendEmail({String? subject, String? body}) async {
    final sub = subject ?? 'Dairy Management Support Inquiry';
    final content = body ?? 'Hello Yu_Vi Development,\n\nI need assistance with: ';
    final uri = Uri(
      scheme: 'mailto',
      path: primaryEmail,
      queryParameters: {
        'subject': sub,
        'body': content,
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _copyToClipboard(primaryEmail, 'Email address copied to clipboard: $primaryEmail');
      }
    } catch (_) {
      _copyToClipboard(primaryEmail, 'Email to: $primaryEmail');
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFF1565C0),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _submitInquiry(bool viaWhatsApp) {
    final name = _nameController.text.trim();
    final subject = _subjectController.text.trim();
    final msg = _messageController.text.trim();

    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your query or message.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final fullMessage =
        'Name: ${name.isNotEmpty ? name : "Dairy User"}\n'
        'Subject: $subject\n'
        'Edition: ${AppConfig.isOfflineMode ? "Offline" : (AppConfig.isHybridMode ? "Hybrid" : "Cloud Online")}\n'
        'Message: $msg';

    if (viaWhatsApp) {
      _openWhatsApp(customMessage: fullMessage);
    } else {
      _sendEmail(subject: '[$subject] Dairy App Support', body: fullMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final primaryColor = const Color(0xFF1565C0);
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: canPop
          ? AppBar(
              title: Text('Help Center & Support'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 1,
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Hero Banner
                _buildHeroBanner(primaryColor),
                const SizedBox(height: 24),

                // Main Content Grid / Column
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Contact Cards & Support Details
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            _buildDeveloperCard(primaryColor),
                            const SizedBox(height: 20),
                            _buildQuickActionCards(),
                            const SizedBox(height: 20),
                            _buildFaqSection(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column: Direct Message Form & System Info
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            _buildDirectInquiryForm(primaryColor),
                            const SizedBox(height: 20),
                            _buildSystemInfoCard(),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildDeveloperCard(primaryColor),
                      const SizedBox(height: 20),
                      _buildQuickActionCards(),
                      const SizedBox(height: 20),
                      _buildDirectInquiryForm(primaryColor),
                      const SizedBox(height: 20),
                      _buildFaqSection(),
                      const SizedBox(height: 20),
                      _buildSystemInfoCard(),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. Hero Header Banner
  Widget _buildHeroBanner(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0F172A), primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'HELP CENTER & SUPPORT'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                          SizedBox(width: 4),
                          Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Dedicated technical support, license approvals, milk chart configurations, and custom dairy software features by Yu_Vi Development.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Official Developer Card
  Widget _buildDeveloperCard(Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.business, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        developerName,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Software Engineering & Dairy Technology Solutions',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // Lead Developer
            _buildContactRow(
              icon: Icons.person,
              label: 'Lead Developer',
              value: leadDeveloper,
              actionLabel: 'Developer Profile',
              onAction: null,
            ),
            const SizedBox(height: 12),

            // Primary Mobile Number
            _buildContactRow(
              icon: Icons.phone_android,
              label: 'Mobile / Calling',
              value: internationalPhone,
              actionLabel: 'Call Now',
              actionIcon: Icons.call,
              actionColor: Colors.green.shade700,
              onAction: _makeCall,
              onCopy: () => _copyToClipboard(primaryPhone, 'Mobile number copied!'),
            ),
            const SizedBox(height: 12),

            // WhatsApp Number
            _buildContactRow(
              icon: Icons.chat,
              label: 'WhatsApp Support',
              value: internationalPhone,
              actionLabel: 'Chat on WhatsApp',
              actionIcon: Icons.open_in_new,
              actionColor: const Color(0xFF25D366),
              onAction: () => _openWhatsApp(),
              onCopy: () => _copyToClipboard(primaryPhone, 'WhatsApp number copied!'),
            ),
            const SizedBox(height: 12),

            // Primary Email
            _buildContactRow(
              icon: Icons.email,
              label: 'Primary Email',
              value: primaryEmail,
              actionLabel: 'Send Email',
              actionIcon: Icons.mail_outline,
              actionColor: primaryColor,
              onAction: () => _sendEmail(),
              onCopy: () => _copyToClipboard(primaryEmail, 'Email copied to clipboard!'),
            ),
            const SizedBox(height: 12),

            // Alternate Email
            _buildContactRow(
              icon: Icons.alternate_email,
              label: 'Support Desk Email',
              value: alternateEmail,
              actionLabel: 'Copy',
              actionIcon: Icons.copy,
              actionColor: Colors.blueGrey,
              onAction: () => _copyToClipboard(alternateEmail, 'Support email copied!'),
            ),
            const SizedBox(height: 12),

            // Operating Support Hours
            _buildContactRow(
              icon: Icons.access_time,
              label: 'Support Hours',
              value: supportHours,
              actionLabel: '7 AM - 10 PM',
              onAction: null,
            ),
          ],
        ),
      ),
    );
  }

  // 3. Contact Details Row Helper
  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required String actionLabel,
    IconData? actionIcon,
    Color? actionColor,
    VoidCallback? onAction,
    VoidCallback? onCopy,
  }) {
    final isCompact = MediaQuery.of(context).size.width < 650;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF475569)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    SelectableText(
                      value,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
              if (onCopy != null)
                IconButton(
                  icon: const Icon(Icons.copy, size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Copy',
                  onPressed: onCopy,
                ),
              if (onAction != null && !isCompact) ...[
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  icon: Icon(actionIcon ?? Icons.arrow_forward, size: 14),
                  label: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor ?? const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: onAction,
                ),
              ],
            ],
          ),
          if (onAction != null && isCompact) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(actionIcon ?? Icons.arrow_forward, size: 16),
                label: Text(actionLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor ?? const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 4. Quick Action Cards (Call, WhatsApp, Email, Approval)
  Widget _buildQuickActionCards() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final items = [
      _buildActionTile(
        title: 'Call Support',
        subtitle: 'Direct Voice Call',
        icon: Icons.phone_in_talk,
        color: const Color(0xFF16A34A),
        onTap: _makeCall,
      ),
      _buildActionTile(
        title: 'WhatsApp',
        subtitle: 'Instant Chat & Help',
        icon: Icons.chat_bubble_outline,
        color: const Color(0xFF059669),
        onTap: () => _openWhatsApp(),
      ),
      _buildActionTile(
        title: 'Email Desk',
        subtitle: 'Inquiries & Reports',
        icon: Icons.mail_outline,
        color: const Color(0xFF2563EB),
        onTap: () => _sendEmail(),
      ),
    ];

    if (isMobile) {
      return Column(
        children: items.map((tile) => Padding(padding: const EdgeInsets.only(bottom: 10), child: tile)).toList(),
      );
    }

    return Row(
      children: [
        Expanded(child: items[0]),
        const SizedBox(width: 12),
        Expanded(child: items[1]),
        const SizedBox(width: 12),
        Expanded(child: items[2]),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 5. Direct Inquiry Form
  Widget _buildDirectInquiryForm(Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.send_rounded, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Quick Inquiry & Assistance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Send your query directly to Yu_Vi Development via WhatsApp or Email:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            // Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name / Dairy Name',
                hintText: 'e.g. Malhari Dairy',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Subject
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. Subscription approval, milk rates chart, backup restore',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.topic_outlined, size: 20),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Message
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Message / Problem Description',
                hintText: 'Type your message or request details here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                alignLabelWithHint: true,
                isDense: true,
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Send on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _submitInquiry(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Send Email', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _submitInquiry(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 6. Frequently Asked Questions
  Widget _buildFaqSection() {
    final faqs = [
      {
        'q': 'How do I activate or renew my paid subscription?',
        'a': 'Go to the Subscription menu in the sidebar or choose your plan on signup. Scan the PhonePe / Google Pay QR code to transfer the fee, tap "I Have Paid", and call Yu_Vi Development at 6361782144. Your account is approved instantly!',
      },
      {
        'q': 'Can I access my account from multiple devices?',
        'a': 'Yes! Subscriptions are tied directly to your user account. Once approved, you can log into any Android phone, Windows PC, macOS, or iPhone with the same email & password.',
      },
      {
        'q': 'How does Offline Mode work?',
        'a': 'In the Offline edition, all milk collection, farmer ledger, and payment records are stored locally on your device in a high-speed SQLite database without requiring any internet connection.',
      },
      {
        'q': 'How can I back up my dairy database?',
        'a': 'Open the "Backup & Restore" menu in the sidebar to export your full database to a backup file (.db). You can also email or transfer this backup to Google Drive or another PC.',
      },
      {
        'q': 'How do I configure Cow and Buffalo milk rate charts?',
        'a': 'Navigate to "Rate Management" in the sidebar. You can set FAT / SNF rate tables, general base rates, or specific farmer rates dynamically.',
      },
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.help_outline, color: Color(0xFF0F172A), size: 22),
                SizedBox(width: 10),
                Text(
                  'Frequently Asked Questions (FAQ)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...faqs.map(
              (faq) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ExpansionTile(
                  title: Text(
                    faq['q']!,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Text(
                        faq['a']!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 7. System & Diagnostic Info Card
  Widget _buildSystemInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF475569)),
              SizedBox(width: 8),
              Text(
                'Application Diagnostics',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDiagRow('Application Name', 'Dairy Management System'),
          _buildDiagRow('Version', 'v1.0.2+3'),
          _buildDiagRow('Edition', AppConfig.isOfflineMode ? '100% Offline' : (AppConfig.isHybridMode ? 'Hybrid Sync' : 'Cloud Online')),
          _buildDiagRow('Developer Organization', developerName),
          _buildDiagRow('Direct Support Phone', primaryPhone),
          _buildDiagRow('Primary Email', primaryEmail),
        ],
      ),
    );
  }

  Widget _buildDiagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
