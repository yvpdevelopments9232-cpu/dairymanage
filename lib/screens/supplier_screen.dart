import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supplier_provider.dart';
import '../models/flutter_models.dart';

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
        title: const Text('Delete Dealer'),
        content: Text('Are you sure you want to delete ${supplier.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(supplierProvider.notifier).deleteSupplier(supplier.id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final suppliersAsync = ref.watch(supplierProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplierDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Dealer'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const Center(child: Text('No dealers found. Add one to start.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 24),
                    child: IntrinsicWidth(
                      child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.orange.shade50,
                    child: const Icon(Icons.local_shipping, color: Colors.orange),
                  ),
                  title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text('${supplier.mobile ?? "No phone"} | ${supplier.productType ?? "General"}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Bal:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            '₹${supplier.currentBalance.toStringAsFixed(2)}', 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: supplier.currentBalance > 0 ? Colors.red : Colors.green)
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'pay') _showPaymentDialog(context, supplier);
                          if (val == 'edit') _showSupplierDialog(context, supplier: supplier);
                          if (val == 'delete') _confirmDelete(context, ref, supplier);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'pay', child: Row(children: [Icon(Icons.payment, color: Colors.green), SizedBox(width: 8), Text('Make Payment')])),
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete')])),
                        ],
                      ),
                    ],
                  ),
                ),
                      ),
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
    return AlertDialog(
      title: Text(widget.supplier == null ? 'Add Dealer' : 'Edit Dealer'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Dealer Name *'), validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(controller: _mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile No')),
              TextFormField(controller: _productTypeCtrl, decoration: const InputDecoration(labelText: 'Product Type (e.g., Feed, Box)')),
              TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
              if (widget.supplier == null)
                TextFormField(controller: _openingBalCtrl, decoration: const InputDecoration(labelText: 'Opening Balance (₹)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(onPressed: _isSaving ? null : _submit, child: _isSaving ? const CircularProgressIndicator() : const Text('SAVE')),
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
    return AlertDialog(
      title: Text('Make Payment to ${widget.supplier.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Current Balance: ₹${widget.supplier.currentBalance}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 16),
          TextFormField(controller: _amountCtrl, decoration: const InputDecoration(labelText: 'Payment Amount (₹)'), keyboardType: TextInputType.number),
          TextFormField(controller: _remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks / Ref No')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(onPressed: _isSaving ? null : _submit, child: _isSaving ? const CircularProgressIndicator() : const Text('PAY NOW')),
      ],
    );
  }
}
