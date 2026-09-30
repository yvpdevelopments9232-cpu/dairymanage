import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supplier_provider.dart';
import '../models/flutter_models.dart';
import '../providers/language_provider.dart';
import '../providers/display_mode_provider.dart';
import '../services/translations.dart';

class SupplierScreen extends ConsumerWidget {
  const SupplierScreen({super.key});

  void _showSupplierDialog(BuildContext context, {Supplier? supplier}) {
    showDialog(context: context, builder: (_) => SupplierDialog(supplier: supplier));
  }
  
  void _showPaymentDialog(BuildContext context, Supplier supplier) {
    showDialog(context: context, builder: (_) => PaymentDialog(supplier: supplier));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Supplier supplier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Dealer'.tr),
        content: Text('${'Are you sure you want to delete'.tr} ${supplier.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL'.tr)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(supplierProvider.notifier).deleteSupplier(supplier.id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted successfully'.tr)));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text('DELETE'.tr, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final displayMode = ref.watch(displayModeProvider);
    final isMobile = displayMode == DisplayMode.mobile || MediaQuery.of(context).size.width < 700;
    final suppliersAsync = ref.watch(supplierProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplierDialog(context),
        icon: const Icon(Icons.add),
        label: Text('Add Dealer'.tr),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return Center(child: Text('No dealers found. Add one to start.'.tr));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];

              final tile = ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.orange.shade50,
                  child: const Icon(Icons.local_shipping, color: Colors.orange),
                ),
                title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('${supplier.mobile ?? "N/A"} | ${supplier.productType ?? "General"}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Bal:'.tr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          '₹${supplier.currentBalance.toStringAsFixed(2)}', 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: supplier.currentBalance > 0 ? Colors.red : Colors.green)
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'pay') _showPaymentDialog(context, supplier);
                        if (val == 'edit') _showSupplierDialog(context, supplier: supplier);
                        if (val == 'delete') _confirmDelete(context, ref, supplier);
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(value: 'pay', child: Row(children: [const Icon(Icons.payment, color: Colors.green, size: 20), const SizedBox(width: 8), Text('Make Payment'.tr)])),
                        PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, size: 20), const SizedBox(width: 8), Text('Edit'.tr)])),
                        PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, color: Colors.red, size: 20), const SizedBox(width: 8), Text('Delete'.tr, style: const TextStyle(color: Colors.red))])),
                      ],
                    ),
                  ],
                ),
              );

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: isMobile ? tile : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 24),
                    child: IntrinsicWidth(child: tile),
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

class SupplierDialog extends ConsumerStatefulWidget {
  final Supplier? supplier;
  const SupplierDialog({super.key, this.supplier});

  @override
  ConsumerState<SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends ConsumerState<SupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _mobileCtrl, _addressCtrl, _productTypeCtrl, _openingBalCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.supplier?.name ?? '');
    _mobileCtrl = TextEditingController(text: widget.supplier?.mobile ?? '');
    _addressCtrl = TextEditingController(text: widget.supplier?.address ?? '');
    _productTypeCtrl = TextEditingController(text: widget.supplier?.productType ?? '');
    _openingBalCtrl = TextEditingController(text: widget.supplier?.openingBalance.toString() ?? '0');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    
    try {
      final s = Supplier(
        id: widget.supplier?.id ?? '',
        name: _nameCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        productType: _productTypeCtrl.text.trim(),
        openingBalance: double.tryParse(_openingBalCtrl.text) ?? 0,
      );
      
      if (widget.supplier == null) {
        await ref.read(supplierProvider.notifier).addSupplier(s);
      } else {
        await ref.read(supplierProvider.notifier).updateSupplier(s.id, s);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final isEditing = widget.supplier != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Dealer'.tr : 'Add Dealer'.tr),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Dealer Name *'.tr), validator: (v) => v!.isEmpty ? 'Required'.tr : null),
              TextFormField(controller: _mobileCtrl, decoration: InputDecoration(labelText: 'Mobile No'.tr)),
              TextFormField(controller: _productTypeCtrl, decoration: InputDecoration(labelText: 'Product Type (e.g., Feed, Box)'.tr)),
              TextFormField(controller: _addressCtrl, decoration: InputDecoration(labelText: 'Full Address'.tr), maxLines: 2),
              if (!isEditing)
                TextFormField(controller: _openingBalCtrl, decoration: InputDecoration(labelText: 'Opening Balance (₹)'.tr), keyboardType: TextInputType.number),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL'.tr)),
        ElevatedButton(onPressed: _isSaving ? null : _submit, child: _isSaving ? const CircularProgressIndicator() : Text('Save'.tr)),
      ],
    );
  }
}

class PaymentDialog extends ConsumerStatefulWidget {
  final Supplier supplier;
  const PaymentDialog({super.key, required this.supplier});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  bool _isSaving = false;

  Future<void> _submit() async {
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    if (amt <= 0) return;
    setState(() => _isSaving = true);
    
    try {
      await ref.read(supplierProvider.notifier).makePayment(widget.supplier.id, amt, _remarksCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);

    return AlertDialog(
      title: Text('${widget.supplier.name} ${'Make Payment to'.tr}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${'Current Balance:'.tr} ₹${widget.supplier.currentBalance}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 16),
          TextFormField(controller: _amountCtrl, decoration: InputDecoration(labelText: 'Amount (₹) *'.tr), keyboardType: TextInputType.number),
          TextFormField(controller: _remarksCtrl, decoration: InputDecoration(labelText: 'Remarks / Notes'.tr)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL'.tr)),
        ElevatedButton(onPressed: _isSaving ? null : _submit, child: _isSaving ? const CircularProgressIndicator() : Text('PAY NOW'.tr)),
      ],
    );
  }
}
