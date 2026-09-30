import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_provider.dart';
import '../models/flutter_models.dart';
import '../providers/language_provider.dart';
import '../providers/display_mode_provider.dart';
import '../services/translations.dart';

class CustomerScreen extends ConsumerWidget {
  const CustomerScreen({super.key});

  void _showCustomerDialog(BuildContext context, {Customer? existingCustomer}) {
    showDialog(
      context: context,
      builder: (context) => CustomerDialog(customer: existingCustomer),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Customer'.tr),
        content: Text('${'Are you sure you want to delete'.tr} ${customer.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL'.tr)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(customersProvider.notifier).deleteCustomer(customer.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Customer deleted successfully'.tr)));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
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
    final customersAsync = ref.watch(customersProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(context),
        icon: const Icon(Icons.add),
        label: Text('Add Customer'.tr),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (customers) {
          if (customers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No customers added yet.'.tr, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showCustomerDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text('Add your first Customer'.tr),
                  )
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];

              final tile = ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.orange.shade50,
                  child: const Icon(Icons.store, color: Colors.orange),
                ),
                title: Text(
                  customer.name, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('${customer.customerType.tr} | 📞 ${customer.mobile ?? "N/A"}'),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Bal:'.tr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          '₹ ${customer.currentBalance.toStringAsFixed(2)}', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 14,
                            color: customer.currentBalance > 0 ? Colors.red.shade700 : Colors.green.shade700
                          )
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showCustomerDialog(context, existingCustomer: customer);
                        } else if (value == 'delete') {
                          _confirmDelete(context, ref, customer);
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

class CustomerDialog extends ConsumerStatefulWidget {
  final Customer? customer;
  const CustomerDialog({super.key, this.customer});

  @override
  ConsumerState<CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends ConsumerState<CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _creditLimitController;
  
  String _selectedType = 'Retail';
  final List<String> _customerTypes = ['Retail', 'Hotel', 'Restaurant', 'Shop', 'Wholesale', 'Other'];
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _mobileController = TextEditingController(text: widget.customer?.mobile ?? '');
    _addressController = TextEditingController(text: widget.customer?.address ?? '');
    _creditLimitController = TextEditingController(text: widget.customer?.creditLimit.toString() ?? '5000');
    if (widget.customer != null) {
      _selectedType = widget.customer!.customerType;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      if (widget.customer == null) {
        await ref.read(customersProvider.notifier).addCustomer(
          _nameController.text.trim(),
          _mobileController.text.trim(),
          _addressController.text.trim(),
          _selectedType,
          double.parse(_creditLimitController.text),
        );
      } else {
        await ref.read(customersProvider.notifier).updateCustomer(
          widget.customer!.id,
          _nameController.text.trim(),
          _mobileController.text.trim(),
          _addressController.text.trim(),
          _selectedType,
          double.parse(_creditLimitController.text),
        );
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.customer == null ? 'Customer added successfully!' : 'Customer updated!'), 
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
    _mobileController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final isEditing = widget.customer != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Customer'.tr : 'Add New Customer'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    labelText: 'Shop / Customer Name *'.tr, 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.storefront)
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required'.tr : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number'.tr, 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.phone)
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Customer Type'.tr,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: _customerTypes.map((type) => DropdownMenuItem(value: type, child: Text(type.tr))).toList(),
                  onChanged: (val) => setState(() => _selectedType = val!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _creditLimitController,
                  decoration: InputDecoration(
                    labelText: 'Credit Limit (₹)'.tr, 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.account_balance_wallet)
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Full Address'.tr, 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.location_on)
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
        TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL'.tr)),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isSaving ? const CircularProgressIndicator() : Text(isEditing ? 'UPDATE'.tr : 'SAVE CUSTOMER'.tr),
        ),
      ],
    );
  }
}
