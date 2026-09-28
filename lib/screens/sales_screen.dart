import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sales_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/farmer_provider.dart';
import '../providers/product_provider.dart';
import '../models/flutter_models.dart';

class SaleParty {
  final String id;
  final String name;
  final String type;
  SaleParty({required this.id, required this.name, required this.type});
  
  @override
  String toString() => '$name ($type)';
}

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _formKey = GlobalKey<FormState>();

  SaleParty? _selectedParty;
  Product? _selectedProduct;

  final _qtyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _paidAmtCtrl = TextEditingController();
  final _partySearchCtrl = TextEditingController();

  double _totalAmount = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl.addListener(_calculateTotal);
    _rateCtrl.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _paidAmtCtrl.dispose();
    _partySearchCtrl.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final rate = double.tryParse(_rateCtrl.text) ?? 0;
    setState(() {
      _totalAmount = qty * rate;
    });
  }

  void _onProductSelected(Product? p) {
    setState(() {
      _selectedProduct = p;
      if (p != null) {
        _rateCtrl.text = p.sellingRate.toString();
        _calculateTotal();
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParty == null || _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Customer/Farmer and Product')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(salesProvider.notifier).addSale(
        partyId: _selectedParty!.id,
        partyType: _selectedParty!.type,
        productId: _selectedProduct!.id,
        qty: double.parse(_qtyCtrl.text),
        rate: double.parse(_rateCtrl.text),
        paidAmount: double.tryParse(_paidAmtCtrl.text) ?? 0,
      );
      
      if (mounted) {
        ref.invalidate(customersProvider);
        ref.invalidate(farmersProvider);
        ref.invalidate(productsProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale Recorded Successfully!'), backgroundColor: Colors.green));
        
        _qtyCtrl.clear();
        _paidAmtCtrl.clear();
        _partySearchCtrl.clear();
        setState(() {
          _selectedParty = null;
          _selectedProduct = null;
          _rateCtrl.clear();
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
    final customersAsync = ref.watch(customersProvider);
    final farmersAsync = ref.watch(farmersProvider);
    final productsAsync = ref.watch(productsProvider);
    final salesAsync = ref.watch(salesProvider);

    List<SaleParty> allParties = [];
    if (customersAsync.hasValue && farmersAsync.hasValue) {
      allParties.addAll(customersAsync.value!.map((c) => SaleParty(id: c.id, name: c.name, type: 'Customer')));
      allParties.addAll(farmersAsync.value!.map((f) => SaleParty(id: f.id, name: f.name, type: 'Farmer')));
    }
    
    final isMobile = false; // Forced desktop layout as per user request

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: isMobile
          ? SingleChildScrollView(
              child: Column(
                children: [
                  _buildFormContent(context, primaryColor, allParties, productsAsync, isMobile),
                  const SizedBox(height: 16),
                  _buildHistoryContent(context, primaryColor, salesAsync),
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
                    child: _buildFormContent(context, primaryColor, allParties, productsAsync, isMobile),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
                    child: _buildHistoryContent(context, primaryColor, salesAsync),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFormContent(BuildContext context, Color primaryColor, List<SaleParty> allParties, AsyncValue<List<Product>> productsAsync, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New Sale Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                        const Divider(height: 32),
                        
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isMobile ? double.infinity : 300,
                              child: Autocomplete<SaleParty>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return allParties;
                                  }
                                  return allParties.where((party) => party.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                },
                                displayStringForOption: (SaleParty option) => option.toString(),
                                onSelected: (SaleParty selection) {
                                  setState(() => _selectedParty = selection);
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Search Customer / Farmer *',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      suffixIcon: const Icon(Icons.search),
                                    ),
                                    validator: (v) => _selectedParty == null ? 'Required' : null,
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              width: isMobile ? double.infinity : 300,
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
                                      labelText: 'Search Product / Milk *',
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
                        
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isMobile ? double.infinity : 300,
                              child: TextFormField(
                                controller: _qtyCtrl,
                                decoration: InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            SizedBox(
                              width: isMobile ? double.infinity : 300,
                              child: TextFormField(
                                controller: _rateCtrl,
                                decoration: InputDecoration(labelText: 'Selling Rate (₹) *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isMobile ? double.infinity : 300,
                              child: TextFormField(
                                controller: _paidAmtCtrl,
                                decoration: InputDecoration(labelText: 'Paid Amount (₹)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            SizedBox(
                              width: isMobile ? double.infinity : 300,
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
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _submit,
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check_circle),
                            label: Text(_isSaving ? 'SAVING...' : 'RECORD SALE', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

  Widget _buildHistoryContent(BuildContext context, Color primaryColor, AsyncValue<List<Sale>> salesAsync) {
    return Container(
      color: Colors.grey.shade50,
      constraints: const BoxConstraints(minHeight: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.all(16.0), child: Text('Recent Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          salesAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())),
            error: (e, s) => Center(child: Text('Error: $e')),
            data: (sales) {
              if (sales.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No recent sales')));
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sales.length,
                itemBuilder: (context, index) {
                  final s = sales[index];
                  final name = s.customerName ?? s.farmerName ?? 'Unknown';
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.storefront)),
                    title: Text(name),
                    subtitle: Text('${s.invoiceNo} | ₹${s.grandTotal}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Paid: ₹${s.paidAmount}', style: const TextStyle(color: Colors.green, fontSize: 12)),
                        Text('Bal: ₹${s.balance}', style: const TextStyle(color: Colors.red, fontSize: 12)),
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
  }
}
