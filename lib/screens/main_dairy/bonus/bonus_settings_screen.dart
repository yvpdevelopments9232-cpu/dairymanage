import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/bonus_provider.dart';

class BonusSettingsScreen extends ConsumerStatefulWidget {
  const BonusSettingsScreen({super.key});

  @override
  ConsumerState<BonusSettingsScreen> createState() => _BonusSettingsScreenState();
}

class _BonusSettingsScreenState extends ConsumerState<BonusSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _cowRateController;
  late TextEditingController _buffaloRateController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(bonusSettingsProvider).value;
    _cowRateController = TextEditingController(
      text: (settings?.cowRate ?? 0.40).toStringAsFixed(2),
    );
    _buffaloRateController = TextEditingController(
      text: (settings?.buffaloRate ?? 0.50).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _cowRateController.dispose();
    _buffaloRateController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final cowRate = double.tryParse(_cowRateController.text.trim()) ?? 0.0;
    final buffaloRate = double.tryParse(_buffaloRateController.text.trim()) ?? 0.0;

    setState(() => _isSaving = true);
    try {
      await ref.read(bonusSettingsProvider.notifier).updateRates(
        cowRate: cowRate,
        buffaloRate: buffaloRate,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Bonus rates updated successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bonusSettingsProvider, (prev, next) {
      if (next.value != null && !_isSaving) {
        if (_cowRateController.text.isEmpty) {
          _cowRateController.text = next.value!.cowRate.toStringAsFixed(2);
        }
        if (_buffaloRateController.text.isEmpty) {
          _buffaloRateController.text = next.value!.buffaloRate.toStringAsFixed(2);
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb & Title
            Row(
              children: [
                const Icon(Icons.workspace_premium, size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  'Bonus',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                const Text(
                  'Bonus Settings',
                  style: TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Bonus Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 24),

            // Card: Bonus Rate Configuration
            Container(
              padding: const EdgeInsets.all(24),
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bonus Rate Configuration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 20),

                    // Inputs Row
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 650;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _buildRateInput(
                                label: 'Cow Milk Bonus Rate',
                                controller: _cowRateController,
                              ),
                              const SizedBox(height: 16),
                              _buildRateInput(
                                label: 'Buffalo Milk Bonus Rate',
                                controller: _buffaloRateController,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _buildRateInput(
                                label: 'Cow Milk Bonus Rate',
                                controller: _cowRateController,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildRateInput(
                                label: 'Buffalo Milk Bonus Rate',
                                controller: _buffaloRateController,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),

                    const SizedBox(height: 24),

                    // Information Note
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'These rates will be used automatically for bonus calculation based on the animal type (Cow / Buffalo) from milk collection data.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF), height: 1.4),
                            ),
                          ),
                        ],
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

  Widget _buildRateInput({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text(
                '₹',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF475569)),
              ),
            ),
            suffixText: '/ Liter',
            suffixStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) return 'Rate is required';
            final d = double.tryParse(val.trim());
            if (d == null || d < 0) return 'Enter a valid positive rate';
            return null;
          },
        ),
      ],
    );
  }
}
