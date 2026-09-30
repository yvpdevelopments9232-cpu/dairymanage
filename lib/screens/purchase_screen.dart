import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/purchase_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/product_provider.dart';
import '../models/flutter_models.dart';
import '../providers/language_provider.dart';
import '../providers/display_mode_provider.dart';
import '../services/translations.dart';

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  Supplier? _selectedSupplier;
  Product? _selectedProduct;

  final _qtyCtrl = TextEditingController();
  final _purchaseRateCtrl = TextEditingController();
  final _sellingRateCtrl = TextEditingController();
  final _paidAmtCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();

  double _totalAmount = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl.addListener(_calculateTotal);
    _purchaseRateCtrl.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _purchaseRateCtrl.dispose();
    _sellingRateCtrl.dispose();
    _paidAmtCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final rate = double.tryParse(_purchaseRateCtrl.text) ?? 0;
    setState(() {
      _totalAmount = qty * rate;
    });
  }

  void _onProductSelected(Product? p) {
    setState(() {
      _selectedProduct = p;
      if (p != null) {
        _purchaseRateCtrl.text = p.purchaseRate.toString();
        _sellingRateCtrl.text = p.sellingRate.toString();
        _calculateTotal();
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplier == null || _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select Dealer and Product'.tr)));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(purchaseProvider.notifier).addPurchase(
        supplierId: _selectedSupplier!.id,
        productId: _selectedProduct!.id,
        qty: double.parse(_qtyCtrl.text),
        purchaseRate: double.parse(_purchaseRateCtrl.text),
        sellingRate: double.parse(_sellingRateCtrl.text),
        paidAmount: double.tryParse(_paidAmtCtrl.text) ?? 0,
        vehicleNo: _vehicleCtrl.text.trim(),
      );
      
      if (mounted) {
        // Refresh products and suppliers so balances and stock show correctly in other screens
        ref.invalidate(supplierProvider);
        ref.invalidate(productsProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stock Updated Successfully!'.tr), backgroundColor: Colors.green));
        
        // Reset form
        _qtyCtrl.clear();
        _paidAmtCtrl.clear();
        _vehicleCtrl.clear();
        setState(() {
          _selectedSupplier = null;
          _selectedProduct = null;
          _purchaseRateCtrl.clear();
          _sellingRateCtrl.clear();
          _totalAmount = 0;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final displayMode = ref.watch(displayModeProvider);
    final isMobile = displayMode == DisplayMode.mobile || MediaQuery.of(context).size.width < 900;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final suppliersAsync = ref.watch(supplierProvider);
    final productsAsync = ref.watch(productsProvider);
    final purchasesAsync = ref.watch(purchaseProvider);

    final supplierField = suppliersAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, s) => Text('Error: $e'),
      data: (suppliers) => Autocomplete<Supplier>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) return suppliers;
          return suppliers.where((s) => s.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
        },
        displayStringForOption: (Supplier option) => option.name,
        onSelected: (Supplier selection) => setState(() => _selectedSupplier = selection),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Search Dealer *'.tr,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: const Icon(Icons.search),
          ),
          validator: (v) => _selectedSupplier == null ? 'Required'.tr : null,
        ),
      ),
    );

    final productField = productsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, s) => Text('Error: $e'),
      data: (products) => Autocomplete<Product>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) return products;
          return products.where((p) => p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
        },
        displayStringForOption: (Product option) => '${option.name} (${'In Stock'.tr}: ${option.currentStock})',
        onSelected: _onProductSelected,
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Search Product *'.tr,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: const Icon(Icons.search),
          ),
          validator: (v) => _selectedProduct == null ? 'Required'.tr : null,
        ),
      ),
    );

    final purchaseRateField = TextFormField(
      controller: _purchaseRateCtrl,
      decoration: InputDecoration(labelText: 'Purchase Rate (₹) *'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) => v!.isEmpty ? 'Required'.tr : null,
    );

    final sellingRateField = TextFormField(
      controller: _sellingRateCtrl,
      decoration: InputDecoration(labelText: 'Sale Rate (₹) *'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) => v!.isEmpty ? 'Required'.tr : null,
    );

    final qtyField = TextFormField(
      controller: _qtyCtrl,
      decoration: InputDecoration(labelText: 'Quantity *'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) => v!.isEmpty ? 'Required'.tr : null,
    );

    final totalDisplay = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Amount'.tr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text('₹${_totalAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
        ],
      ),
    );

    final paidAmtField = TextFormField(
      controller: _paidAmtCtrl,
      decoration: InputDecoration(labelText: 'Paid Amount (₹)'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );

    final vehicleField = TextFormField(
      controller: _vehicleCtrl,
      decoration: InputDecoration(labelText: 'Vehicle Number (Optional)'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
    );

    final formCard = Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Purchase Entry'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
              const Divider(height: 24),
              
              if (isMobile) ...[
                supplierField,
                const SizedBox(height: 16),
                productField,
                const SizedBox(height: 16),
                purchaseRateField,
                const SizedBox(height: 16),
                sellingRateField,
                const SizedBox(height: 16),
                qtyField,
                const SizedBox(height: 16),
                totalDisplay,
                const SizedBox(height: 16),
                paidAmtField,
                const SizedBox(height: 16),
                vehicleField,
              ] else ...[
                Row(
                  children: [
                    Expanded(child: supplierField),
                    const SizedBox(width: 16),
                    Expanded(child: productField),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: purchaseRateField),
                    const SizedBox(width: 16),
                    Expanded(child: sellingRateField),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: qtyField),
                    const SizedBox(width: 16),
                    Expanded(child: totalDisplay),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: paidAmtField),
                    const SizedBox(width: 16),
                    Expanded(child: vehicleField),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
                  label: Text(_isSaving ? 'SAVING...'.tr : 'SAVE & UPDATE STOCK'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final historyList = Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: Text('Recent Stock Updates'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          purchasesAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
            error: (e, s) => Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error: $e'))),
            data: (purchases) {
              if (purchases.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('No recent purchases'.tr)));
              return ListView.builder(
                shrinkWrap: isMobile,
                physics: isMobile ? const NeverScrollableScrollPhysics() : null,
                itemCount: purchases.length,
                itemBuilder: (context, index) {
                  final p = purchases[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.receipt)),
                    title: Text(p.supplierName ?? 'Unknown Dealer'.tr),
                    subtitle: Text('${p.purchaseDate} | ₹${p.grandTotal}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${'Paid:'.tr} ₹${p.paidAmount}', style: const TextStyle(color: Colors.green, fontSize: 12)),
                        Text('${'Bal:'.tr} ₹${p.balance}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                  );
                },
              );
            }
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Update Stock (Purchases)'.tr, style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: isMobile
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  formCard,
                  const SizedBox(height: 16),
                  historyList,
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: formCard,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: historyList,
                ),
              ],
            ),
    );
  }
}
