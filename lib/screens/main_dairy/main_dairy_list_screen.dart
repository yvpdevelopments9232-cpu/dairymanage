import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/flutter_models.dart';
import '../../providers/main_dairy_provider.dart';
import '../../providers/main_dairy_payment_provider.dart';
import '../../services/translations.dart';

class MainDairyListScreen extends ConsumerStatefulWidget {
  const MainDairyListScreen({super.key});

  @override
  ConsumerState<MainDairyListScreen> createState() => _MainDairyListScreenState();
}

class _MainDairyListScreenState extends ConsumerState<MainDairyListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showDairyDialog(BuildContext context, {MainDairy? existingDairy}) {
    showDialog(
      context: context,
      builder: (context) => MainDairyDialog(dairy: existingDairy),
    );
  }

  void _showPaymentDialog(BuildContext context, MainDairy dairy) {
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String paymentMode = 'Bank Transfer';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.payments, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Record Payment: #${dairy.dairyNo != null ? dairy.dairyNo.toString().padLeft(3, '0') : ""} ${dairy.name}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Balance:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    Text(
                      '₹ ${dairy.currentBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: dairy.currentBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount Received (₹) *',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: paymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  border: OutlineInputBorder(),
                ),
                items: ['Bank Transfer', 'NEFT/RTGS', 'Cheque', 'Cash', 'UPI']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setDialogState(() => paymentMode = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reference / Cheque No',
                  hintText: 'e.g. UTR / Txn ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  hintText: 'Optional notes',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim());
                if (amt == null || amt <= 0) return;
                Navigator.pop(ctx);
                final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                await ref.read(mainDairyPaymentProvider.notifier).addPayment(
                  mainDairyId: dairy.id,
                  amount: amt,
                  paymentMode: paymentMode,
                  paymentDate: todayStr,
                  referenceNo: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                  remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
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

  void _confirmDelete(BuildContext context, MainDairy dairy) {
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
  Widget build(BuildContext context) {
    final dairiesAsync = ref.watch(mainDairyProvider);
    final primaryColor = Colors.indigo.shade700;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Main Dairies / Members'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.indigo),
            tooltip: 'Refresh'.tr,
            onPressed: () => ref.invalidate(mainDairyProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDairyDialog(context),
        icon: const Icon(Icons.add),
        label: Text('Add Main Dairy'.tr),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: dairiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (dairies) {
          final filtered = dairies.where((d) {
            if (_searchQuery.isEmpty) return true;
            final name = d.name.toLowerCase();
            final noStr = d.dairyNo != null ? d.dairyNo.toString().padLeft(3, '0') : '';
            final village = (d.village ?? '').toLowerCase();
            final mobile = (d.mobile ?? '').toLowerCase();
            return name.contains(_searchQuery) ||
                noStr.contains(_searchQuery) ||
                village.contains(_searchQuery) ||
                mobile.contains(_searchQuery);
          }).toList();

          final totalReceivable = dairies.fold<double>(0.0, (sum, d) => sum + d.currentBalance);

          return Column(
            children: [
              // Top Search & Summary Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.indigo.shade50.withOpacity(0.5),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Search by D. ID (e.g. 001), Name (e.g. Sonai), Village...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.indigo.shade200),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total: ${dairies.length} Main Dairy Centers',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo.shade900, fontSize: 13),
                        ),
                        Text(
                          'Total Receivable: ₹ ${totalReceivable.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: totalReceivable > 0 ? Colors.red.shade700 : Colors.green.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Dairies List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.domain_outlined, size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'No Main Dairies added yet.' : 'No Main Dairies match "$_searchQuery"',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            if (_searchQuery.isEmpty)
                              TextButton.icon(
                                onPressed: () => _showDairyDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add your first Main Dairy'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final dairy = filtered[index];
                          final displayId = dairy.dairyNo != null ? dairy.dairyNo.toString().padLeft(3, '0') : '---';

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Row: Avatar + Name & ID + More Popup
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: primaryColor.withOpacity(0.1),
                                        child: Icon(Icons.business, color: primaryColor, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '#$displayId  ${dairy.name}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${dairy.village != null && dairy.village!.isNotEmpty ? dairy.village : (dairy.address ?? "No Village")} | 📞 ${dairy.mobile ?? "N/A"}${dairy.animalType != null ? " | ${dairy.animalType}" : ""}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showDairyDialog(context, existingDairy: dairy);
                                          } else if (value == 'delete') {
                                            _confirmDelete(context, dairy);
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
                                  const Divider(height: 20),
                                  // Bottom Row: Balance + Receive Payment Button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Receivable Bal', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₹ ${dairy.currentBalance.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: dairy.currentBalance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.payments, size: 18),
                                        label: const Text('Receive Payment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 1,
                                        ),
                                        onPressed: () => _showPaymentDialog(context, dairy),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
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
