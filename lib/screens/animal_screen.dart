import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flutter_models.dart';
import '../providers/animal_provider.dart';
import '../providers/farmer_provider.dart';

class AnimalScreen extends ConsumerStatefulWidget {
  const AnimalScreen({super.key});

  @override
  ConsumerState<AnimalScreen> createState() => _AnimalScreenState();
}

class _AnimalScreenState extends ConsumerState<AnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _breedCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  
  String _animalType = 'Cow';
  String? _selectedFarmerId;
  bool _isSaving = false;

  @override
  void dispose() {
    _breedCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedFarmerId == null) return;
    setState(() => _isSaving = true);
    
    try {
      await ref.read(animalProvider.notifier).addAnimal(
        farmerId: _selectedFarmerId!,
        animalType: _animalType,
        breed: _breedCtrl.text.isEmpty ? null : _breedCtrl.text,
        name: _nameCtrl.text.isEmpty ? null : _nameCtrl.text,
        age: _ageCtrl.text.isEmpty ? null : int.parse(_ageCtrl.text),
        milkCapacity: _capacityCtrl.text.isEmpty ? null : double.parse(_capacityCtrl.text),
      );
      
      _breedCtrl.clear();
      _nameCtrl.clear();
      _ageCtrl.clear();
      _capacityCtrl.clear();
      setState(() => _selectedFarmerId = null);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Animal registered successfully')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animalAsync = ref.watch(animalProvider);
    final farmerAsync = ref.watch(farmersProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isMobile = false; // Forced desktop layout as per user request

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animals & Livestock', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Flex(
        direction: isMobile ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Registration Form
          Expanded(
            flex: isMobile ? 0 : 1,
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
                        Text('Register New Animal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                        const Divider(height: 32),
                        farmerAsync.when(
                          loading: () => const CircularProgressIndicator(),
                          error: (e, s) => Text('Error loading farmers: $e'),
                          data: (farmers) => DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'Select Owner (Farmer) *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            value: _selectedFarmerId,
                            items: farmers.map((f) => DropdownMenuItem(value: f.id, child: Text('${f.farmerNo} - ${f.name}'))).toList(),
                            onChanged: (v) => setState(() => _selectedFarmerId = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(labelText: 'Animal Type *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          value: _animalType,
                          items: ['Cow', 'Buffalo', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => _animalType = v!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(labelText: 'Tag No / Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _breedCtrl,
                          decoration: InputDecoration(labelText: 'Breed (e.g., HF, Jersey)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isMobile ? double.infinity : (MediaQuery.of(context).size.width / 4 - 60),
                              child: TextFormField(
                                controller: _ageCtrl,
                                decoration: InputDecoration(labelText: 'Age (Years)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            SizedBox(
                              width: isMobile ? double.infinity : (MediaQuery.of(context).size.width / 4 - 60),
                              child: TextFormField(
                                controller: _capacityCtrl,
                                decoration: InputDecoration(labelText: 'Daily Milk Cap. (L)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: TextInputType.number,
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
                            icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.pets),
                            label: Text(_isSaving ? 'SAVING...' : 'REGISTER ANIMAL', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Animal List
          Expanded(
            flex: isMobile ? 1 : 2,
            child: Container(
              color: Colors.grey.shade50,
              height: isMobile ? 500 : double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.all(16.0), child: Text('Registered Livestock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  Expanded(
                    child: animalAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Error: $e')),
                      data: (animals) {
                        if (animals.isEmpty) return const Center(child: Text('No animals registered.'));
                        return ListView.builder(
                          itemCount: animals.length,
                          itemBuilder: (context, index) {
                            final animal = animals[index];
                            // Find the farmer to display their name
                            final farmers = farmerAsync.value ?? [];
                            final owner = farmers.where((f) => f.id == animal.farmerId).firstOrNull;
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: animal.animalType == 'Cow' ? Colors.orange.shade100 : Colors.blueGrey.shade100,
                                  child: Icon(Icons.pets, color: animal.animalType == 'Cow' ? Colors.orange : Colors.blueGrey),
                                ),
                                title: Text(animal.name != null && animal.name!.isNotEmpty ? '${animal.animalType} - ${animal.name}' : animal.animalType, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Owner: ${owner?.name ?? 'Unknown'} | Cap: ${animal.milkCapacity ?? 0} Ltr'),
                                trailing: Switch(
                                  value: animal.status,
                                  onChanged: (val) => ref.read(animalProvider.notifier).toggleStatus(animal.id, animal.status),
                                  activeColor: Colors.green,
                                ),
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
