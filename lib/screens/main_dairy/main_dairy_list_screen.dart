import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/flutter_models.dart';
import '../../providers/main_dairy_provider.dart';

class MainDairyListScreen extends ConsumerWidget {
  const MainDairyListScreen({super.key});

  void _showDairyDialog(BuildContext context, {MainDairy? existingDairy}) {
    showDialog(
      context: context,
      builder: (context) => MainDairyDialog(dairy: existingDairy),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, MainDairy dairy) {
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String paymentMode = 'Bank Transfer';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Record Payment Received: ${dairy.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount Received (₹) *'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: paymentMode,
                decoration: const InputDecoration(labelText: 'Payment Mode'),
                items: ['Bank Transfer', 'NEFT/RTGS', 'Cheque', 'Cash', 'UPI']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => paymentMode = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference / Cheque No')),
              const SizedBox(height: 8),
              TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim());
                if (amt == null || amt <= 0) return;
                Navigator.pop(ctx);
                await ref.read(mainDairyProvider.notifier).recordPayment(
                  mainDairyId: dairy.id,
                  amount: amt,
                  paymentMode: paymentMode,
                  referenceNo: refCtrl.text.trim(),
                  remarks: remarksCtrl.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment recorded successfully!'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('SAVE PAYMENT'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MainDairy dairy) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Main Dairy'),
        content: Text('Are you sure you want to delete ${dairy.name}?\n\nThis will also delete their associated dispatch records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(mainDairyProvider.notifier).deleteDairy(dairy.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Main Dairy deleted successfully')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dairiesAsync = ref.watch(mainDairyProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDairyDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Main Dairy'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: dairiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (dairies) {
          if (dairies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.domain_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No Main Dairies added yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showDairyDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add your first Main Dairy'),
                  )
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dairies.length,
            itemBuilder: (context, index) {
              final dairy = dairies[index];
              final displayId = dairy.dairyNo != null ? dairy.dairyNo.toString().padLeft(3, '0') : '---';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    child: Icon(Icons.business, color: primaryColor),
                  ),
                  title: Text('#$displayId  ${dairy.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('${dairy.village != null && dairy.village!.isNotEmpty ? dairy.village : (dairy.address ?? "No Village")} | 📞 ${dairy.mobile ?? "N/A"}'),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Receivable Bal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            '₹ ${dairy.currentBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: dairy.currentBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.payments, color: Colors.green),
                        tooltip: 'Receive Payment',
                        onPressed: () => _showPaymentDialog(context, ref, dairy),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showDairyDialog(context, existingDairy: dairy);
                          } else if (value == 'delete') {
                            _confirmDelete(context, ref, dairy);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MainDairyDialog extends ConsumerStatefulWidget {
  final MainDairy? dairy;
  const MainDairyDialog({super.key, this.dairy});

  @override
  ConsumerState<MainDairyDialog> createState() => _MainDairyDialogState();
}

class _MainDairyDialogState extends ConsumerState<MainDairyDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _villageController;
  late TextEditingController _addressController;

  String _selectedAnimalType = 'Cow';
  final List<String> _animalTypes = ['Cow', 'Buffalo', 'Jersey Cow', 'HF Cow', 'Other'];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.dairy?.name ?? '');
    _mobileController = TextEditingController(text: widget.dairy?.mobile ?? '');
    _villageController = TextEditingController(text: widget.dairy?.village ?? '');
    _addressController = TextEditingController(text: widget.dairy?.address ?? '');
    if (widget.dairy?.animalType != null && _animalTypes.contains(widget.dairy!.animalType)) {
      _selectedAnimalType = widget.dairy!.animalType!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _villageController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      if (widget.dairy == null) {
        final newDairy = MainDairy(
          id: '',
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          village: _villageController.text.trim(),
          animalType: _selectedAnimalType,
          address: _addressController.text.trim(),
          openingBalance: 0.0,
        );
        await ref.read(mainDairyProvider.notifier).addDairy(newDairy);
      } else {
        final updated = MainDairy(
          id: widget.dairy!.id,
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          village: _villageController.text.trim(),
          animalType: _selectedAnimalType,
          address: _addressController.text.trim(),
        );
        await ref.read(mainDairyProvider.notifier).updateDairy(updated);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.dairy == null ? 'Dairy added successfully!' : 'Dairy updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.dairy != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Dairy Details' : 'Add New Dairy', style: const TextStyle(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Dairy Name *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _villageController,
                  decoration: InputDecoration(
                    labelText: 'Village',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedAnimalType,
                  decoration: InputDecoration(
                    labelText: 'Primary Animal Type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.pets),
                  ),
                  items: _animalTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedAnimalType = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Full Address',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEditing ? 'UPDATE' : 'SAVE DAIRY', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
