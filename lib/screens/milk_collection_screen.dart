import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';

import '../providers/milk_collection_provider.dart';
import '../providers/farmer_provider.dart';
import '../providers/rate_provider.dart';
import '../models/flutter_models.dart';
import '../services/sync_service.dart';

import 'package:intl/intl.dart';

class MilkCollectionScreen extends ConsumerStatefulWidget {
  const MilkCollectionScreen({super.key});

  @override
  ConsumerState<MilkCollectionScreen> createState() =>
      _MilkCollectionScreenState();
}

class _MilkCollectionScreenState extends ConsumerState<MilkCollectionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _farmerNoController = TextEditingController();
  final _qtyController = TextEditingController();
  final _fatController = TextEditingController();
  final _snfController = TextEditingController();
  final _rateController = TextEditingController();

  String? _selectedFarmerId;
  String? _editingId;
  String _milkType = 'Cow Milk';
  double _totalAmount = 0.0;
  bool _isSaving = false;

  // Focus nodes for rapid entry
  final _farmerNoFocus = FocusNode();
  final _qtyFocus = FocusNode();
  final _fatFocus = FocusNode();
  final _snfFocus = FocusNode();
  final _saveFocus = FocusNode();


  final _totalController = TextEditingController(text: '0.00');
  TextEditingController? _autocompleteController;

  @override
  void initState() {
    super.initState();
    _farmerNoFocus.addListener(() {
      if (!_farmerNoFocus.hasFocus && _farmerNoController.text.isNotEmpty) {
        ref.read(farmersProvider.future).then((farmers) {
          if (mounted) _onFarmerNoSubmitted(_farmerNoController.text, farmers);
        });
      }
    });
    _qtyController.addListener(_calculateTotal);
    _rateController.addListener(_calculateTotal);
    _fatController.addListener(_fetchApplicableRate);
    _snfController.addListener(_fetchApplicableRate);
    SyncService.instance.syncVersion.addListener(_onSyncUpdate);
  }

  void _onSyncUpdate() {
    if (mounted) {
      ref.invalidate(milkCollectionProvider);
      ref.invalidate(farmersProvider);
    }
  }

  @override
  void dispose() {
    SyncService.instance.syncVersion.removeListener(_onSyncUpdate);
    _farmerNoController.dispose();
    _qtyController.dispose();
    _fatController.dispose();
    _snfController.dispose();
    _rateController.dispose();
    _farmerNoFocus.dispose();
    _qtyFocus.dispose();
    _fatFocus.dispose();
    _snfFocus.dispose();
    _saveFocus.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    setState(() {
      _totalAmount = qty * rate;
      _totalController.text = _totalAmount.toStringAsFixed(2);
    });
  }

  Future<void> _fetchApplicableRate() async {
    if (_fatController.text.isNotEmpty && _snfController.text.isNotEmpty) {
      final fat = double.tryParse(_fatController.text);
      final snf = double.tryParse(_snfController.text);
      if (fat != null && snf != null) {
        final dateStr = ref.read(milkCollectionProvider.notifier).currentDate;
        final dateObj = DateTime.tryParse(dateStr) ?? DateTime.now();
        final autoRate = await ref
            .read(rateConfigProvider.notifier)
            .getApplicableRate(_milkType, fat, snf, dateObj);
        if (autoRate != null && _rateController.text != autoRate.toString()) {
          _rateController.text = autoRate.toString();
        }
      }
    }
  }

  void _onFarmerNoSubmitted(String noStr, List<Farmer> farmers) {
    final no = int.tryParse(noStr);
    if (no == null) return;

    try {
      final farmer = farmers.firstWhere((f) => f.farmerNo == no);
      setState(() {
        _selectedFarmerId = farmer.id;
          _autocompleteController?.text = '#' + farmer.farmerNo.toString() + ' - ' + farmer.name;
      });
      // Automatically determine milk type if they have animals
      _checkFarmerAnimals(farmer.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _qtyFocus.requestFocus();
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Farmer ID not found')));
      _farmerNoController.clear();
      _farmerNoFocus.requestFocus();
    }
  }

  Future<void> _checkFarmerAnimals(String farmerId) async {
    // Wait for the provider to fetch the data from the database
    try {
      final animals = await ref.read(farmerAnimalsProvider(farmerId).future);
      if (animals.isNotEmpty && mounted) {
        setState(() {
          _milkType = animals.first.animalType == 'Buffalo'
              ? 'Buffalo Milk'
              : 'Cow Milk';
        });
      }
    } catch (_) {
      // Ignore if fetch fails
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedFarmerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(milkCollectionProvider.notifier);
      final time = DateFormat('HH:mm:ss').format(DateTime.now());

      await notifier.addCollection(
        date: notifier.currentDate,
        time: time,
        shift: notifier.currentShift,
        farmerId: _selectedFarmerId!,
        milkType: _milkType,
        qty: double.parse(_qtyController.text),
        fat: double.tryParse(_fatController.text) ?? 0,
        snf: double.tryParse(_snfController.text) ?? 0,
        rate: double.parse(_rateController.text),
      );

      // Clear for next entry
      _farmerNoController.clear();
      _qtyController.clear();
      _fatController.clear();
      _snfController.clear();
      _rateController.clear();
      setState(() {
        _selectedFarmerId = null;
        _totalAmount = 0.0;
      });
      _farmerNoFocus.requestFocus(); // Back to start

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  void _loadForEdit(MilkCollection collection) {
    setState(() {
      _editingId = collection.id;
      _farmerNoController.text = collection.farmerNo.toString();
      _selectedFarmerId = collection.farmerId;
      _milkType = collection.milkType;
      _qtyController.text = collection.quantity.toString();
      _fatController.text = collection.fat.toString();
      _snfController.text = collection.snf.toString();
      _rateController.text = collection.rate.toString();
    });
    _calculateTotal();
    
    // Automatically set autocomplete if possible
    if (_autocompleteController != null) {
      _autocompleteController!.text = collection.farmerNo.toString();
    }
  }
  
  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _farmerNoController.clear();
      _selectedFarmerId = null;
      _qtyController.clear();
      _fatController.clear();
      _snfController.clear();
      _rateController.clear();
      if (_autocompleteController != null) {
        _autocompleteController!.clear();
      }
    });
    _calculateTotal();
  }

  void _showEditDialogOld(MilkCollection collection) {
    showDialog(
      context: context,
      builder: (context) => EditCollectionDialog(collection: collection),
    );
  }

  void _confirmDelete(MilkCollection collection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text(
          'Are you sure you want to delete this collection entry? This will reverse the ledger balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(milkCollectionProvider.notifier)
                    .deleteCollection(collection.id);
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String mainValue, String subValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          mainValue,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subValue,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    Function(String)? onChanged, {
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade200 : Colors.white,
      ),
      keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
      onChanged: onChanged,
      onFieldSubmitted: nextFocus != null
          ? (v) => nextFocus.requestFocus()
          : null,
      validator: readOnly
          ? null
          : (val) => val == null || val.isEmpty ? 'Req' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(milkCollectionProvider.notifier);
    final collectionsAsync = ref.watch(milkCollectionProvider);
    final farmersAsync = ref.watch(farmersProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isMobile = false; // Forced desktop layout as per user request

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Milk Collection',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: primaryColor,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            label: Text(
              notifier.currentDate,
              style: const TextStyle(color: Colors.white),
            ),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(notifier.currentDate),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                notifier.setFilters(
                  DateFormat('yyyy-MM-dd').format(date),
                  notifier.currentShift,
                );
              }
            },
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: notifier.currentShift,
                items: ['Morning', 'Evening']
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null)
                    notifier.setFilters(notifier.currentDate, val);
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(child: Column(
        children: [
          // --- SHIFT SUMMARY SECTION ---
          collectionsAsync.maybeWhen(
            data: (collections) {
              double cowQty = 0, cowFatSum = 0, cowSnfSum = 0;
              double buffQty = 0, buffFatSum = 0, buffSnfSum = 0;
              double totalAmt = 0;

              for (var col in collections) {
                totalAmt += col.totalAmount;
                if (col.milkType == 'Cow Milk') {
                  cowQty += col.quantity;
                  cowFatSum += (col.quantity * col.fat);
                  cowSnfSum += (col.quantity * col.snf);
                } else if (col.milkType == 'Buffalo Milk') {
                  buffQty += col.quantity;
                  buffFatSum += (col.quantity * col.fat);
                  buffSnfSum += (col.quantity * col.snf);
                }
              }

              // Calculate Weighted Average mathematically
              double cowAvgFat = cowQty > 0 ? (cowFatSum / cowQty) : 0;
              double cowAvgSnf = cowQty > 0 ? (cowSnfSum / cowQty) : 0;
              double buffAvgFat = buffQty > 0 ? (buffFatSum / buffQty) : 0;
              double buffAvgSnf = buffQty > 0 ? (buffSnfSum / buffQty) : 0;

              final isMobile = false; // Forced desktop layout as per user request
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: Colors.blue.shade900,
                child: isMobile
                    ? Column(
                        children: [
                          _buildStatItem(
                            'COW MILK',
                            '${cowQty.toStringAsFixed(1)} Ltr',
                            'Fat: ${cowAvgFat.toStringAsFixed(1)} | SNF: ${cowAvgSnf.toStringAsFixed(1)}',
                          ),
                          const Divider(color: Colors.white30),
                          _buildStatItem(
                            'BUFFALO MILK',
                            '${buffQty.toStringAsFixed(1)} Ltr',
                            'Fat: ${buffAvgFat.toStringAsFixed(1)} | SNF: ${buffAvgSnf.toStringAsFixed(1)}',
                          ),
                          const Divider(color: Colors.white30),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'TOTAL SHIFT AMOUNT',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₹ ${totalAmt.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            'COW MILK',
                            '${cowQty.toStringAsFixed(1)} Ltr',
                            'Fat: ${cowAvgFat.toStringAsFixed(1)} | SNF: ${cowAvgSnf.toStringAsFixed(1)}',
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.white30,
                          ),
                          _buildStatItem(
                            'BUFFALO MILK',
                            '${buffQty.toStringAsFixed(1)} Ltr',
                            'Fat: ${buffAvgFat.toStringAsFixed(1)} | SNF: ${buffAvgSnf.toStringAsFixed(1)}',
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.white30,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'TOTAL SHIFT AMOUNT',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₹ ${totalAmt.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // DATA ENTRY SECTION
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (isMobile)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _farmerNoController,
                            focusNode: _farmerNoFocus,
                            decoration: InputDecoration(
                              labelText: 'Farmer ID',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                            onFieldSubmitted: (val) {
                              if (farmersAsync.hasValue)
                                _onFarmerNoSubmitted(val, farmersAsync.value!);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        farmersAsync.when(
                          loading: () => const CircularProgressIndicator(),
                          error: (e, st) => const Text('Error'),
                          data: (farmers) => Autocomplete<Farmer>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty)
                                    return farmers;
                                  return farmers.where(
                                    (f) =>
                                        f.name.toLowerCase().contains(
                                          textEditingValue.text.toLowerCase(),
                                        ) ||
                                        f.farmerNo.toString() ==
                                            textEditingValue.text,
                                  );
                                },
                            displayStringForOption: (Farmer option) =>
                                '#${option.farmerNo} - ${option.name}',
                            onSelected: (Farmer selection) {
                              setState(() {
                                _selectedFarmerId = selection.id;
                                _farmerNoController.text = selection.farmerNo
                                    .toString();
                              });
                              _checkFarmerAnimals(selection.id);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _qtyFocus.requestFocus();
                              });
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  _autocompleteController = controller;
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    onFieldSubmitted: (String value) {
                                      onFieldSubmitted();
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Search Farmer by Name/No',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      suffixIcon: const Icon(Icons.search),
                                    ),
                                  );
                                },
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Milk Type',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          value: _milkType,
                          items: ['Cow Milk', 'Buffalo Milk', 'Mixed']
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() => _milkType = val!);
                            _fetchApplicableRate();
                          },
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _farmerNoController,
                            focusNode: _farmerNoFocus,
                            decoration: InputDecoration(
                              labelText: 'F. ID',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                            onFieldSubmitted: (val) {
                              if (farmersAsync.hasValue)
                                _onFarmerNoSubmitted(val, farmersAsync.value!);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: farmersAsync.when(
                            loading: () => const CircularProgressIndicator(),
                            error: (e, st) => const Text('Error'),
                            data: (farmers) => Autocomplete<Farmer>(
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty)
                                      return farmers;
                                    return farmers.where(
                                      (f) =>
                                          f.name.toLowerCase().contains(
                                            textEditingValue.text.toLowerCase(),
                                          ) ||
                                          f.farmerNo.toString() ==
                                              textEditingValue.text,
                                    );
                                  },
                              displayStringForOption: (Farmer option) =>
                                  '#${option.farmerNo} - ${option.name}',
                              onSelected: (Farmer selection) {
                                setState(() {
                                  _selectedFarmerId = selection.id;
                                  _farmerNoController.text = selection.farmerNo
                                      .toString();
                                });
                                _checkFarmerAnimals(selection.id);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _qtyFocus.requestFocus();
                                });
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    if (_selectedFarmerId != null) {
                                      try {
                                        final f = farmers.firstWhere(
                                          (x) => x.id == _selectedFarmerId,
                                        );
                                        final expected =
                                            '#${f.farmerNo} - ${f.name}';
                                        if (controller.text != expected) {
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                controller.text = expected;
                                              });
                                        }
                                      } catch (_) {}
                                    } else if (_selectedFarmerId == null &&
                                        controller.text.isNotEmpty) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            controller.clear();
                                          });
                                    }
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      onFieldSubmitted: (String value) {
                                        onFieldSubmitted();
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Search Farmer by Name/No',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        suffixIcon: const Icon(Icons.search),
                                      ),
                                    );
                                  },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Milk Type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: _milkType,
                            items: ['Cow Milk', 'Buffalo Milk', 'Mixed']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() => _milkType = val!);
                              _fetchApplicableRate();
                            },
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  if (isMobile)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                'Qty',
                                _qtyController,
                                _qtyFocus,
                                _fatFocus,
                                (v) => _fetchApplicableRate(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTextField(
                                'Fat%',
                                _fatController,
                                _fatFocus,
                                _snfFocus,
                                (v) => _fetchApplicableRate(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTextField(
                                'SNF%',
                                _snfController,
                                _snfFocus,
                                _saveFocus,
                                (v) => _fetchApplicableRate(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                'Rate',
                                _rateController,
                                null,
                                null,
                                (v) => _calculateTotal(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTextField(
                                'Total ₹',
                                _totalController,
                                null,
                                null,
                                null,
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            focusNode: _saveFocus,
                            onPressed: _isSaving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'SAVE COLLECTION',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Qty (Ltr)',
                            _qtyController,
                            _qtyFocus,
                            _fatFocus,
                            (v) => _fetchApplicableRate(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            'Fat %',
                            _fatController,
                            _fatFocus,
                            _snfFocus,
                            (v) => _fetchApplicableRate(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            'SNF %',
                            _snfController,
                            _snfFocus,
                            _saveFocus,
                            (v) => _fetchApplicableRate(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            'Rate',
                            _rateController,
                            null,
                            null,
                            (v) => _calculateTotal(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            'Total ₹',
                            _totalController,
                            null,
                            null,
                            null,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'SAVE',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // HISTORY SECTION
          Container(
            padding: const EdgeInsets.all(12),
            color: primaryColor.withOpacity(0.1),
            width: double.infinity,
            child: Text(
              '${notifier.currentShift} History - ${notifier.currentDate}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
          collectionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (collections) {
                if (collections.isEmpty)
                  return const Center(
                    child: Text('No collections for this shift.'),
                  );

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final col = collections[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 24),
                          child: IntrinsicWidth(
                            child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Text(
                            col.farmerNo?.toString() ?? '?',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          '${col.farmerName}  (${col.quantity} Ltr ${col.milkType})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Fat: ${col.fat} | SNF: ${col.snf} | Rate: ₹${col.rate}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹ ${col.totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _loadForEdit(col),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(col),
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
          ],
        ),
      ),
    );
  }
}

// Dialog for editing mistakes
class EditCollectionDialog extends ConsumerStatefulWidget {
  final MilkCollection collection;
  const EditCollectionDialog({super.key, required this.collection});

  @override
  ConsumerState<EditCollectionDialog> createState() =>
      _EditCollectionDialogState();
}

class _EditCollectionDialogState extends ConsumerState<EditCollectionDialog> {
  late TextEditingController _qtyController;
  late TextEditingController _fatController;
  late TextEditingController _snfController;
  late TextEditingController _rateController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.collection.quantity.toString(),
    );
    _fatController = TextEditingController(
      text: widget.collection.fat.toString(),
    );
    _snfController = TextEditingController(
      text: widget.collection.snf.toString(),
    );
    _rateController = TextEditingController(
      text: widget.collection.rate.toString(),
    );
  }

  Future<void> _update() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(milkCollectionProvider.notifier)
          .updateCollection(
            widget.collection.id,
            qty: double.parse(_qtyController.text),
            fat: double.parse(_fatController.text),
            snf: double.parse(_snfController.text),
            rate: double.parse(_rateController.text),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Collection (Farmer #${widget.collection.farmerNo})'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _qtyController,
            decoration: const InputDecoration(labelText: 'Quantity (Ltr)'),
          ),
          TextFormField(
            controller: _fatController,
            decoration: const InputDecoration(labelText: 'FAT %'),
          ),
          TextFormField(
            controller: _snfController,
            decoration: const InputDecoration(labelText: 'SNF %'),
          ),
          TextFormField(
            controller: _rateController,
            decoration: const InputDecoration(labelText: 'Rate (₹)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _update,
          child: const Text('UPDATE'),
        ),
      ],
    );
  }
}
