import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/flutter_models.dart';
import '../../providers/main_dairy_provider.dart';
import '../../providers/main_dairy_rate_provider.dart';
import '../../providers/main_dairy_collection_provider.dart';

class MainDairyCollectionScreen extends ConsumerStatefulWidget {
  const MainDairyCollectionScreen({super.key});

  @override
  ConsumerState<MainDairyCollectionScreen> createState() =>
      _MainDairyCollectionScreenState();
}

class _MainDairyCollectionScreenState extends ConsumerState<MainDairyCollectionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _dairyNoController = TextEditingController();
  final _qtyController = TextEditingController();
  final _fatController = TextEditingController();
  final _snfController = TextEditingController();
  final _rateController = TextEditingController();
  final _totalController = TextEditingController(text: '0.00');
  TextEditingController? _autocompleteController;

  String? _selectedDairyId;
  String? _editingId;
  String _milkType = 'Cow Milk';
  double _totalAmount = 0.0;
  bool _isSaving = false;

  // Focus nodes for rapid entry
  final _dairyNoFocus = FocusNode();
  final _qtyFocus = FocusNode();
  final _fatFocus = FocusNode();
  final _snfFocus = FocusNode();
  final _saveFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _dairyNoFocus.addListener(() {
      if (!_dairyNoFocus.hasFocus && _dairyNoController.text.isNotEmpty) {
        ref.read(mainDairyProvider.future).then((dairies) {
          if (mounted) _onDairyNoSubmitted(_dairyNoController.text, dairies);
        });
      }
    });
    _qtyController.addListener(_calculateTotal);
    _rateController.addListener(_calculateTotal);
    _fatController.addListener(_fetchApplicableRate);
    _snfController.addListener(_fetchApplicableRate);
  }

  @override
  void dispose() {
    _dairyNoController.dispose();
    _qtyController.dispose();
    _fatController.dispose();
    _snfController.dispose();
    _rateController.dispose();
    _totalController.dispose();
    _dairyNoFocus.dispose();
    _qtyFocus.dispose();
    _fatFocus.dispose();
    _snfFocus.dispose();
    _saveFocus.dispose();
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
        final dateStr = ref.read(mainDairyCollectionProvider.notifier).currentDate;
        final dateObj = DateTime.tryParse(dateStr) ?? DateTime.now();
        final autoRate = await ref
            .read(mainDairyRateProvider.notifier)
            .getApplicableRate(_milkType, fat, snf, dateObj);
        if (autoRate != null && _rateController.text != autoRate.toStringAsFixed(2)) {
          _rateController.text = autoRate.toStringAsFixed(2);
        } else if (autoRate == null) {
          final fallback = ref.read(mainDairyRateProvider.notifier).calculateRate(
            animalType: _milkType,
            fat: fat,
            snf: snf,
          );
          if (fallback > 0 && _rateController.text != fallback.toStringAsFixed(2)) {
            _rateController.text = fallback.toStringAsFixed(2);
          }
        }
      }
    }
  }

  void _onDairyNoSubmitted(String noStr, List<MainDairy> dairies) {
    final clean = noStr.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final no = int.tryParse(clean);
    if (no == null) return;

    try {
      final dairy = dairies.firstWhere((d) => d.dairyNo == no);
      setState(() {
        _selectedDairyId = dairy.id;
        final formattedNo = dairy.dairyNo != null ? dairy.dairyNo.toString().padLeft(3, '0') : '';
        _dairyNoController.text = formattedNo;
        _autocompleteController?.text = '#$formattedNo - ${dairy.name}';
        if (dairy.animalType != null && dairy.animalType!.isNotEmpty) {
          _milkType = dairy.animalType == 'Buffalo' ? 'Buffalo Milk' : 'Cow Milk';
        }
      });
      _fetchApplicableRate();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _qtyFocus.requestFocus();
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dairy ID not found')));
      _dairyNoController.clear();
      _dairyNoFocus.requestFocus();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedDairyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Main Dairy and fill all required fields correctly')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final notifier = ref.read(mainDairyCollectionProvider.notifier);

    try {
      final qty = double.parse(_qtyController.text);
      final fat = double.tryParse(_fatController.text) ?? 0;
      final snf = double.tryParse(_snfController.text) ?? 0;
      final rate = double.parse(_rateController.text);
      final total = qty * rate;

      if (_editingId != null) {
        await notifier.updateCollection(
          _editingId!,
          quantity: qty,
          fat: fat,
          snf: snf,
          rate: rate,
          totalAmount: total,
          milkType: _milkType,
          mainDairyId: _selectedDairyId,
        );
        _cancelEdit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Updated successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        await notifier.addCollection(
          mainDairyId: _selectedDairyId!,
          date: notifier.currentDate,
          shift: notifier.currentShift,
          milkType: _milkType,
          quantity: qty,
          fat: fat,
          snf: snf,
          rate: rate,
          totalAmount: total,
        );

        // Clear for next entry
        _dairyNoController.clear();
        _qtyController.clear();
        _fatController.clear();
        _snfController.clear();
        _rateController.clear();
        if (_autocompleteController != null) _autocompleteController!.clear();
        setState(() {
          _selectedDairyId = null;
          _totalAmount = 0.0;
          _totalController.text = '0.00';
        });
        _dairyNoFocus.requestFocus(); // Back to start

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved successfully!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _loadForEdit(MainDairyCollection collection) {
    setState(() {
      _editingId = collection.id;
      _dairyNoController.text = collection.dairyNo?.toString() ?? '';
      _selectedDairyId = collection.mainDairyId;
      _milkType = collection.milkType;
      _qtyController.text = collection.quantity.toString();
      _fatController.text = collection.fat.toString();
      _snfController.text = collection.snf.toString();
      _rateController.text = collection.rate.toString();
      if (_autocompleteController != null && collection.dairyName != null) {
        _autocompleteController!.text = '#${collection.dairyNo ?? ""} - ${collection.dairyName}';
      }
    });
    _calculateTotal();
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _dairyNoController.clear();
      _selectedDairyId = null;
      _qtyController.clear();
      _fatController.clear();
      _snfController.clear();
      _rateController.clear();
      if (_autocompleteController != null) _autocompleteController!.clear();
    });
    _calculateTotal();
  }

  void _confirmDelete(MainDairyCollection collection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this dispatch entry? This will reverse the ledger balance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(mainDairyCollectionProvider.notifier).deleteCollection(collection.id);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(mainValue, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(subValue, style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
      onFieldSubmitted: nextFocus != null ? (v) => nextFocus.requestFocus() : null,
      validator: readOnly ? null : (val) => val == null || val.isEmpty ? 'Req' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(mainDairyCollectionProvider.notifier);
    final collectionsAsync = ref.watch(mainDairyCollectionProvider);
    final dairiesAsync = ref.watch(mainDairyProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Dairy Milk Collection / Dispatch', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: primaryColor,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            label: Text(notifier.currentDate, style: const TextStyle(color: Colors.white)),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(notifier.currentDate),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                notifier.setFilters(DateFormat('yyyy-MM-dd').format(date), notifier.currentShift);
              }
            },
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: notifier.currentShift,
                items: ['Morning', 'Evening']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) notifier.setFilters(notifier.currentDate, val);
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- SHIFT SUMMARY BANNER ---
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

                double cowAvgFat = cowQty > 0 ? (cowFatSum / cowQty) : 0;
                double cowAvgSnf = cowQty > 0 ? (cowSnfSum / cowQty) : 0;
                double buffAvgFat = buffQty > 0 ? (buffFatSum / buffQty) : 0;
                double buffAvgSnf = buffQty > 0 ? (buffSnfSum / buffQty) : 0;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.blue.shade900,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                        'COW MILK',
                        '${cowQty.toStringAsFixed(1)} Ltr',
                        'Fat: ${cowAvgFat.toStringAsFixed(1)} | SNF: ${cowAvgSnf.toStringAsFixed(1)}',
                      ),
                      Container(height: 40, width: 1, color: Colors.white30),
                      _buildStatItem(
                        'BUFFALO MILK',
                        '${buffQty.toStringAsFixed(1)} Ltr',
                        'Fat: ${buffAvgFat.toStringAsFixed(1)} | SNF: ${buffAvgSnf.toStringAsFixed(1)}',
                      ),
                      Container(height: 40, width: 1, color: Colors.white30),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('TOTAL SHIFT AMOUNT', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('₹ ${totalAmt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            // --- DATA ENTRY ROW SECTION ---
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ROW 1: D. ID, Search Dairy, Milk Type
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _dairyNoController,
                            focusNode: _dairyNoFocus,
                            decoration: InputDecoration(
                              labelText: 'D. ID',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (val) {
                              if (dairiesAsync.hasValue) _onDairyNoSubmitted(val, dairiesAsync.value!);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: dairiesAsync.when(
                            loading: () => const CircularProgressIndicator(),
                            error: (e, st) => const Text('Error loading dairies'),
                            data: (dairies) => Autocomplete<MainDairy>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) return dairies;
                                final q = textEditingValue.text.toLowerCase().trim();
                                final qNum = int.tryParse(q.replaceAll(RegExp(r'[^0-9]'), ''));
                                return dairies.where((d) =>
                                    d.name.toLowerCase().contains(q) ||
                                    (d.dairyNo != null && (d.dairyNo == qNum || d.dairyNo.toString().contains(q))));
                              },
                              displayStringForOption: (MainDairy option) =>
                                  '#${option.dairyNo != null ? option.dairyNo.toString().padLeft(3, '0') : ""} - ${option.name}',
                              onSelected: (MainDairy selection) {
                                setState(() {
                                  _selectedDairyId = selection.id;
                                  _dairyNoController.text = selection.dairyNo != null ? selection.dairyNo.toString().padLeft(3, '0') : '';
                                  if (selection.animalType != null && selection.animalType!.isNotEmpty) {
                                    _milkType = selection.animalType == 'Buffalo' ? 'Buffalo Milk' : 'Cow Milk';
                                  }
                                });
                                _fetchApplicableRate();
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _qtyFocus.requestFocus();
                                });
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                _autocompleteController = controller;
                                if (_selectedDairyId != null) {
                                  try {
                                    final d = dairies.firstWhere((x) => x.id == _selectedDairyId);
                                    final formattedNo = d.dairyNo != null ? d.dairyNo.toString().padLeft(3, '0') : '';
                                    final expected = '#$formattedNo - ${d.name}';
                                    if (controller.text != expected) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) => controller.text = expected);
                                    }
                                  } catch (_) {}
                                }
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  onFieldSubmitted: (v) => onFieldSubmitted(),
                                  decoration: InputDecoration(
                                    labelText: 'Search Main Dairy by Name/No',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: _milkType,
                            items: ['Cow Milk', 'Buffalo Milk']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
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

                    // ROW 2: Qty, Fat, SNF, Rate, Total, SAVE
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
                        if (_editingId != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: OutlinedButton(
                              onPressed: _cancelEdit,
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20)),
                              child: const Text('CANCEL'),
                            ),
                          ),
                        ElevatedButton(
                          focusNode: _saveFocus,
                          onPressed: _isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          ),
                          child: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                              : Text(_editingId != null ? 'UPDATE' : 'SAVE', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // --- HISTORY SECTION ---
            Container(
              padding: const EdgeInsets.all(12),
              color: primaryColor.withOpacity(0.1),
              width: double.infinity,
              child: Text(
                '${notifier.currentShift} History - ${notifier.currentDate}',
                style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ),
            collectionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (collections) {
                if (collections.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('No collections for this shift.')),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final col = collections[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 24),
                          child: IntrinsicWidth(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: Text(
                                  col.dairyNo != null ? col.dairyNo.toString().padLeft(3, '0') : '?',
                                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              title: Text(
                                '${col.dairyName ?? "Main Dairy"}  (${col.quantity} Ltr ${col.milkType})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Fat: ${col.fat} | SNF: ${col.snf} | Rate: ₹${col.rate}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹ ${col.totalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _loadForEdit(col)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(col)),
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
