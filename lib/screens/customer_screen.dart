import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_provider.dart';
import '../models/flutter_models.dart';

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
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(customersProvider.notifier).deleteCustomer(customer.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer deleted successfully')));
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
    final customersAsync = ref.watch(customersProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
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
                  const Text('No customers added yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showCustomerDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add your first Customer'),
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
                    child: const Icon(Icons.store, color: Colors.orange),
                  ),
                  title: Text(
                    customer.name, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('${customer.customerType} | 📞 ${customer.mobile ?? "N/A"}'),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Bal:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            '₹ ${customer.currentBalance.toStringAsFixed(2)}', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 15,
                              color: customer.currentBalance > 0 ? Colors.red.shade700 : Colors.green.shade700
                            )
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showCustomerDialog(context, existingCustomer: customer);
                          } else if (value == 'delete') {
                            _confirmDelete(context, ref, customer);
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
    final isEditing = widget.customer != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Customer' : 'Add New Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    labelText: 'Shop / Customer Name *', 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.storefront)
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number', 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.phone)
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Customer Type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: _customerTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  onChanged: (val) => setState(() => _selectedType = val!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _creditLimitController,
                  decoration: InputDecoration(
                    labelText: 'Credit Limit (₹)', 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.account_balance_wallet)
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Full Address', 
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isSaving ? const CircularProgressIndicator() : Text(isEditing ? 'UPDATE' : 'SAVE CUSTOMER'),
        ),
      ],
    );
  }
}
