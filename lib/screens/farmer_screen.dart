import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/farmer_provider.dart';
import '../models/flutter_models.dart';
import '../services/app_db.dart';
import '../services/translations.dart';
import '../providers/language_provider.dart';

class FarmerScreen extends ConsumerWidget {
  const FarmerScreen({super.key});

  void _showFarmerDialog(BuildContext context, {Farmer? existingFarmer}) {
    showDialog(
      context: context,
      builder: (context) => FarmerDialog(farmer: existingFarmer),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Farmer farmer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Farmer'.tr),
        content: Text('${'Are you sure you want to delete'.tr} ${farmer.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL'.tr)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(farmersProvider.notifier).deleteFarmer(farmer.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Farmer deleted successfully'.tr)));
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
    final lang = ref.watch(languageProvider);
    final farmersAsync = ref.watch(farmersProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFarmerDialog(context),
        icon: const Icon(Icons.add),
        label: Text('Add Farmer'.tr),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: farmersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (farmers) {
          if (farmers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No farmers added yet.'.tr, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showFarmerDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text('Add your first Farmer'.tr),
                  )
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: farmers.length,
            itemBuilder: (context, index) {
              final farmer = farmers[index];
              // Format ID to 3 digits (e.g., #003)
              final displayId = farmer.farmerNo != null ? farmer.farmerNo.toString().padLeft(3, '0') : '---';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    child: Icon(Icons.person, color: primaryColor),
                  ),
                  title: Text(
                    '#$displayId  ${farmer.name}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('${farmer.village ?? "No Village".tr} | 📞 ${farmer.mobile ?? "N/A"}'),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Ledger Bal'.tr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            '₹ ${farmer.currentBalance.toStringAsFixed(2)}', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 15,
                              color: farmer.currentBalance < 0 ? Colors.red.shade700 : Colors.green.shade700
                            )
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // Dropdown menu for Edit and Delete
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showFarmerDialog(context, existingFarmer: farmer);
                          } else if (value == 'delete') {
                            _confirmDelete(context, ref, farmer);
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
                  onTap: () {
                    // TODO: Open Farmer Profile / Ledger History
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FarmerDialog extends ConsumerStatefulWidget {
  final Farmer? farmer;
  const FarmerDialog({super.key, this.farmer});

  @override
  ConsumerState<FarmerDialog> createState() => _FarmerDialogState();
}

class _FarmerDialogState extends ConsumerState<FarmerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _villageController;
  
  // Animal Type Selection (Only shown when adding a new farmer)
  String _selectedAnimalType = 'Cow';
  final List<String> _animalTypes = ['Cow', 'Buffalo', 'Jersey Cow', 'HF Cow', 'Other'];
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.farmer?.name ?? '');
    _mobileController = TextEditingController(text: widget.farmer?.mobile ?? '');
    _addressController = TextEditingController(text: widget.farmer?.address ?? '');
    _villageController = TextEditingController(text: widget.farmer?.village ?? '');
    if (widget.farmer != null) _fetchAnimalType();
  }

  Future<void> _fetchAnimalType() async {
    final supabase = AppDb.client;
    final res = await supabase.from('animals').select('animal_type').eq('farmer_id', widget.farmer!.id).limit(1);
    if (res.isNotEmpty && mounted) {
      setState(() {
        _selectedAnimalType = res[0]['animal_type'] == 'Buffalo' ? 'Buffalo' : 'Cow';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      if (widget.farmer == null) {
        // Add new farmer
        await ref.read(farmersProvider.notifier).addFarmer(
          _nameController.text.trim(),
          _mobileController.text.trim(),
          _addressController.text.trim(),
          _villageController.text.trim(),
          _selectedAnimalType,
        );
      } else {
        // Update existing farmer
        await ref.read(farmersProvider.notifier).updateFarmer(
          widget.farmer!.id,
          _nameController.text.trim(),
          _mobileController.text.trim(),
          _addressController.text.trim(),
          _villageController.text.trim(),
            animalType: _selectedAnimalType,
        );
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.farmer == null ? 'Farmer and Animal added successfully!'.tr : 'Farmer updated successfully!'.tr), 
            backgroundColor: Colors.green
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
        );
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
    _villageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isEditing = widget.farmer != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Farmer Details'.tr : 'Add New Farmer'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    labelText: 'Full Name *'.tr, 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.person_outline)
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required'.tr : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number'.tr, 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.phone_outlined)
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _villageController,
                  decoration: InputDecoration(
                    labelText: 'Village'.tr, 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.home_outlined)
                  ),
                ),
                
                // Show animal dropdown for both add and edit
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedAnimalType,
                  decoration: InputDecoration(
                    labelText: 'Primary Animal Type'.tr,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.pets),
                  ),
                  items: _animalTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.tr),
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
                    labelText: 'Full Address'.tr, 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.location_on_outlined)
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
          child: Text('CANCEL'.tr),
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
              : Text(isEditing ? 'UPDATE'.tr : 'SAVE FARMER'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
