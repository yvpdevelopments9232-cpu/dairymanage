import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider.dart';
import '../models/flutter_models.dart';
import '../providers/language_provider.dart';
import '../providers/display_mode_provider.dart';
import '../services/translations.dart';

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
        title: Text('Delete Product'.tr),
        content: Text('${'Are you sure you want to delete'.tr} ${product.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL'.tr)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(productsProvider.notifier).deleteProduct(product.id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product deleted successfully'.tr)));
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
    final productsAsync = ref.watch(productsProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context),
        icon: const Icon(Icons.add),
        label: Text('Add Product'.tr),
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
                  Text('No products in inventory yet.'.tr, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showProductDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text('Add your first Product'.tr),
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

              final tile = ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 22,
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
                  child: Text('${(product.category ?? '').tr} | ${'Buy:'.tr} ₹${product.purchaseRate} / ${'Sell:'.tr} ₹${product.sellingRate}'),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('In Stock'.tr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          '${product.currentStock.toStringAsFixed(1)} ${product.unit.tr}', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 14,
                            color: isLowStock ? Colors.red.shade700 : Colors.green.shade700
                          )
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showProductDialog(context, product: product);
                        } else if (value == 'delete') {
                          _confirmDelete(context, ref, product);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [const Icon(Icons.edit, size: 20), const SizedBox(width: 8), Text('Edit'.tr)]),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [const Icon(Icons.delete, color: Colors.red, size: 20), const SizedBox(width: 8), Text('Delete'.tr, style: const TextStyle(color: Colors.red))]),
                        ),
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
            content: Text(widget.product == null ? 'Product added successfully!'.tr : 'Product updated!'.tr), 
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
    ref.watch(languageProvider);
    final displayMode = ref.watch(displayModeProvider);
    final isMobile = displayMode == DisplayMode.mobile || MediaQuery.of(context).size.width < 500;
    final isEditing = widget.product != null;

    final categoryField = DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category'.tr,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.tr))).toList(),
      onChanged: (val) => setState(() => _selectedCategory = val!),
    );

    final unitField = DropdownButtonFormField<String>(
      value: _selectedUnit,
      decoration: InputDecoration(
        labelText: 'Unit'.tr,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u.tr))).toList(),
      onChanged: (val) => setState(() => _selectedUnit = val!),
    );

    final purchaseField = TextFormField(
      controller: _purchaseController,
      decoration: InputDecoration(
        labelText: 'Purchase Rate (₹) *'.tr, 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (val) => val == null || val.trim().isEmpty ? 'Required'.tr : null,
    );

    final sellField = TextFormField(
      controller: _sellController,
      decoration: InputDecoration(
        labelText: 'Sale Rate (₹) *'.tr, 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (val) => val == null || val.trim().isEmpty ? 'Required'.tr : null,
    );

    return AlertDialog(
      title: Text(isEditing ? 'Edit Product'.tr : 'Add New Product'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    labelText: 'Product Name *'.tr, 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.inventory)
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required'.tr : null,
                ),
                const SizedBox(height: 16),
                if (isMobile) ...[
                  categoryField,
                  const SizedBox(height: 16),
                  unitField,
                ] else
                  Row(
                    children: [
                      Expanded(child: categoryField),
                      const SizedBox(width: 16),
                      Expanded(child: unitField),
                    ],
                  ),
                const SizedBox(height: 16),
                if (isMobile) ...[
                  purchaseField,
                  const SizedBox(height: 16),
                  sellField,
                ] else
                  Row(
                    children: [
                      Expanded(child: purchaseField),
                      const SizedBox(width: 16),
                      Expanded(child: sellField),
                    ],
                  ),
                if (!isEditing) const SizedBox(height: 16),
                if (!isEditing)
                  TextFormField(
                    controller: _stockController,
                    decoration: InputDecoration(
                      labelText: 'Opening Stock'.tr, 
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
        TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL'.tr)),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isSaving ? const CircularProgressIndicator() : Text(isEditing ? 'UPDATE'.tr : 'SAVE PRODUCT'.tr),
        ),
      ],
    );
  }
}
