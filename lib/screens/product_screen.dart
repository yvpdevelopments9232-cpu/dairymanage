import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider.dart';
import '../models/flutter_models.dart';

class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key});

  void _showProductDialog(BuildContext context, {Product? product}) {
    showDialog(
      context: context,
      builder: (context) => ProductDialog(product: product),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete ${product.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(productsProvider.notifier).deleteProduct(product.id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted successfully')));
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
    final productsAsync = ref.watch(productsProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No products in inventory yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showProductDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add your first Product'),
                  )
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final bool isLowStock = product.currentStock <= 5;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blue.shade50,
                    child: Icon(
                      product.category == 'Feed' ? Icons.agriculture : Icons.inventory_2, 
                      color: Colors.blue
                    ),
                  ),
                  title: Text(
                    product.name, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('${product.category} | Buy: ₹${product.purchaseRate} / Sell: ₹${product.sellingRate}'),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('In Stock', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            '${product.currentStock.toStringAsFixed(1)} ${product.unit}', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 15,
                              color: isLowStock ? Colors.red.shade700 : Colors.green.shade700
                            )
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showProductDialog(context, product: product);
                          } else if (value == 'delete') {
                            _confirmDelete(context, ref, product);
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

class ProductDialog extends ConsumerStatefulWidget {
  final Product? product;
  const ProductDialog({super.key, this.product});

  @override
  ConsumerState<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _purchaseController;
  late TextEditingController _sellController;
  late TextEditingController _stockController;
  
  String _selectedCategory = 'Milk Products';
  String _selectedUnit = 'Pkt';
  
  final List<String> _categories = ['Milk Products', 'Sweets', 'Feed', 'Other'];
  final List<String> _units = ['Pkt', 'Ltr', 'Kg', 'Box', 'Bag'];
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _purchaseController = TextEditingController(text: widget.product?.purchaseRate.toString() ?? '');
    _sellController = TextEditingController(text: widget.product?.sellingRate.toString() ?? '');
    _stockController = TextEditingController(text: widget.product?.currentStock.toString() ?? '0');
    
    if (widget.product != null) {
      _selectedCategory = widget.product!.category ?? 'Milk Products';
      _selectedUnit = widget.product!.unit ?? 'Pkt';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      if (widget.product == null) {
        await ref.read(productsProvider.notifier).addProduct(
          _nameController.text.trim(),
          _selectedCategory,
          _selectedUnit,
          double.parse(_purchaseController.text),
          double.parse(_sellController.text),
          double.parse(_stockController.text),
        );
      } else {
        await ref.read(productsProvider.notifier).updateProduct(
          widget.product!.id,
          _nameController.text.trim(),
          _selectedCategory,
          _selectedUnit,
          double.parse(_purchaseController.text),
          double.parse(_sellController.text),
        );
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.product == null ? 'Product added successfully!' : 'Product updated!'), 
            backgroundColor: Colors.green
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchaseController.dispose();
    _sellController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Product' : 'Add New Product', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    labelText: 'Product Name *', 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.inventory)
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (val) => setState(() => _selectedUnit = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchaseController,
                        decoration: InputDecoration(
                          labelText: 'Purchase Rate (₹) *', 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _sellController,
                        decoration: InputDecoration(
                          labelText: 'Sale Rate (₹) *', 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                if (!isEditing) const SizedBox(height: 16),
                if (!isEditing)
                  TextFormField(
                    controller: _stockController,
                    decoration: InputDecoration(
                      labelText: 'Opening Stock', 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.layers)
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                if (isEditing)
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: Text('Note: Stock quantity is managed through Purchases and Sales, so it cannot be directly edited here.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  )
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isSaving ? const CircularProgressIndicator() : Text(isEditing ? 'UPDATE' : 'SAVE PRODUCT'),
        ),
      ],
    );
  }
}
