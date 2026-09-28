import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/purchase_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/product_provider.dart';
import '../models/flutter_models.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Dealer and Product')));
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
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock Updated Successfully!'), backgroundColor: Colors.green));
        
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
    final primaryColor = Theme.of(context).colorScheme.primary;
    final suppliersAsync = ref.watch(supplierProvider);
    final productsAsync = ref.watch(productsProvider);
    final purchasesAsync = ref.watch(purchaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Stock (Purchases)', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE: Form
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Purchase Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                        const Divider(height: 32),
                        
                        Row(
                          children: [
                            Expanded(
                              child: suppliersAsync.when(
                                loading: () => const CircularProgressIndicator(),
                                error: (e, s) => Text('Error loading dealers: $e'),
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
                                      labelText: 'Search Dealer *',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      suffixIcon: const Icon(Icons.search),
                                    ),
                                    validator: (v) => _selectedSupplier == null ? 'Required' : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: productsAsync.when(
                                loading: () => const CircularProgressIndicator(),
                                error: (e, s) => Text('Error loading products: $e'),
                                data: (products) => Autocomplete<Product>(
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) return products;
                                    return products.where((p) => p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                  },
                                  displayStringForOption: (Product option) => '${option.name} (Stock: ${option.currentStock})',
                                  onSelected: _onProductSelected,
                                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Search Product *',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      suffixIcon: const Icon(Icons.search),
                                    ),
                                    validator: (v) => _selectedProduct == null ? 'Required' : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _purchaseRateCtrl,
                                decoration: InputDecoration(labelText: 'Purchase Rate (₹) *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _sellingRateCtrl,
                                decoration: InputDecoration(labelText: 'Selling Rate (₹) *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qtyCtrl,
                                decoration: InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text('₹${_totalAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _paidAmtCtrl,
                                decoration: InputDecoration(labelText: 'Paid Amount (₹)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _vehicleCtrl,
                                decoration: InputDecoration(labelText: 'Vehicle Number (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _submit,
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
                            label: Text(_isSaving ? 'SAVING...' : 'SAVE & UPDATE STOCK', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // RIGHT SIDE: Recent Purchases History
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.all(16.0), child: Text('Recent Stock Updates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  Expanded(
                    child: purchasesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Error: $e')),
                      data: (purchases) {
                        if (purchases.isEmpty) return const Center(child: Text('No recent purchases'));
                        return ListView.builder(
                          itemCount: purchases.length,
                          itemBuilder: (context, index) {
                            final p = purchases[index];
                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.receipt)),
                              title: Text(p.supplierName ?? 'Unknown Dealer'),
                              subtitle: Text('${p.purchaseDate} | ₹${p.grandTotal}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Paid: ₹${p.paidAmount}', style: const TextStyle(color: Colors.green, fontSize: 12)),
                                  Text('Bal: ₹${p.balance}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                                ],
                              ),
                            );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
