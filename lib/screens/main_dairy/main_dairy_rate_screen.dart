import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/flutter_models.dart';
import '../../providers/main_dairy_rate_provider.dart';
import '../../services/translations.dart';
import '../../providers/language_provider.dart';

class MainDairyRateScreen extends ConsumerStatefulWidget {
  const MainDairyRateScreen({super.key});

  @override
  ConsumerState<MainDairyRateScreen> createState() => _MainDairyRateScreenState();
}

class _MainDairyRateScreenState extends ConsumerState<MainDairyRateScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _incFormKey = GlobalKey<FormState>();
  final _decFormKey = GlobalKey<FormState>();

  String _animalType = 'Cow Milk';
  DateTime _effectiveDate = DateTime.now();
  String? _editingConfigId;
  bool _isInitialized = false;

  // Filter state for Tab 3 (All Configurations)
  String _filterAnimalType = 'All';
  String _filterRateType = 'All';

  // Inputs
  final _baseFatController = TextEditingController(text: '3.5');
  final _baseSnfController = TextEditingController(text: '8.5');
  final _baseRateController = TextEditingController(text: '40.0');

  final _fatFromController = TextEditingController(text: '3.5');
  final _fatToController = TextEditingController(text: '6.0');
  final _fatPointController = TextEditingController(text: '0.1');
  final _fatRateController = TextEditingController(text: '1.0');

  final _snfFromController = TextEditingController(text: '8.5');
  final _snfToController = TextEditingController(text: '10.0');
  final _snfPointController = TextEditingController(text: '0.1');
  final _snfRateController = TextEditingController(text: '1.0');

  List<Map<String, dynamic>> _generatedChart = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index < 2) {
        setState(() {
          _generatedChart = [];
          _populateFormForSelectedAnimalAndTab();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _baseFatController.dispose();
    _baseSnfController.dispose();
    _baseRateController.dispose();
    _fatFromController.dispose();
    _fatToController.dispose();
    _fatPointController.dispose();
    _fatRateController.dispose();
    _snfFromController.dispose();
    _snfToController.dispose();
    _snfPointController.dispose();
    _snfRateController.dispose();
    super.dispose();
  }

  void _populateFormForSelectedAnimalAndTab({MainDairyRateConfig? specificConfig}) {
    if (_tabController.index >= 2) return;
    final isIncrease = _tabController.index == 0;
    final targetRateType = isIncrease ? 'Increase' : 'Decrease';

    MainDairyRateConfig? configToUse = specificConfig;
    if (configToUse == null) {
      final configs = ref.read(mainDairyRateProvider).value ?? [];
      final matches = configs.where((c) => c.animalType == _animalType && c.rateType == targetRateType).toList();
      if (matches.isNotEmpty) {
        configToUse = matches.first;
      } else {
        final anyAnimalMatch = configs.where((c) => c.animalType == _animalType).firstOrNull;
        if (anyAnimalMatch != null) {
          _baseFatController.text = anyAnimalMatch.baseFat.toString();
          _baseSnfController.text = anyAnimalMatch.baseSnf.toString();
          _baseRateController.text = anyAnimalMatch.baseRate.toString();
        }
      }
    }

    if (configToUse != null) {
      _editingConfigId = configToUse.id;
      _baseFatController.text = configToUse.baseFat.toString();
      _baseSnfController.text = configToUse.baseSnf.toString();
      _baseRateController.text = configToUse.baseRate.toString();

      _fatFromController.text = configToUse.fatRangeFrom.toString();
      _fatToController.text = configToUse.fatRangeTo.toString();
      _fatPointController.text = configToUse.fatPoint.toString();
      _fatRateController.text = configToUse.fatRate.toString();

      _snfFromController.text = configToUse.snfRangeFrom.toString();
      _snfToController.text = configToUse.snfRangeTo.toString();
      _snfPointController.text = configToUse.snfPoint.toString();
      _snfRateController.text = configToUse.snfRate.toString();

      final parsedDate = DateTime.tryParse(configToUse.effectiveDate);
      if (parsedDate != null) {
        _effectiveDate = parsedDate;
      }
    } else {
      _editingConfigId = null;
      if (_animalType == 'Cow Milk') {
        _baseFatController.text = '3.5';
        _baseSnfController.text = '8.5';
        _baseRateController.text = '40.0';
      } else {
        _baseFatController.text = '6.0';
        _baseSnfController.text = '9.0';
        _baseRateController.text = '60.0';
      }

      final baseF = double.tryParse(_baseFatController.text) ?? 3.5;
      final baseS = double.tryParse(_baseSnfController.text) ?? 8.5;

      if (isIncrease) {
        _fatFromController.text = baseF.toString();
        _fatToController.text = (baseF + 2.5).toStringAsFixed(1);
        _fatPointController.text = '0.1';
        _fatRateController.text = '1.0';

        _snfFromController.text = baseS.toString();
        _snfToController.text = (baseS + 1.5).toStringAsFixed(1);
        _snfPointController.text = '0.1';
        _snfRateController.text = '1.0';
      } else {
        _fatFromController.text = (baseF - 1.5 > 0 ? baseF - 1.5 : 2.0).toStringAsFixed(1);
        _fatToController.text = baseF.toString();
        _fatPointController.text = '0.1';
        _fatRateController.text = '1.0';

        _snfFromController.text = (baseS - 1.5 > 0 ? baseS - 1.5 : 7.0).toStringAsFixed(1);
        _snfToController.text = baseS.toString();
        _snfPointController.text = '0.1';
        _snfRateController.text = '1.0';
      }
    }

    _generateChart();
  }

  void _generateChart() {
    if (_tabController.index >= 2) return;
    final key = _tabController.index == 0 ? _incFormKey : _decFormKey;
    if (key.currentState != null && !key.currentState!.validate()) return;

    final isIncrease = _tabController.index == 0;

    double baseFat = double.tryParse(_baseFatController.text) ?? 3.5;
    double baseSnf = double.tryParse(_baseSnfController.text) ?? 8.5;
    double baseRate = double.tryParse(_baseRateController.text) ?? 40.0;

    double fatFrom = double.tryParse(_fatFromController.text) ?? (isIncrease ? 3.5 : 2.0);
    double fatTo = double.tryParse(_fatToController.text) ?? (isIncrease ? 6.0 : 3.5);
    double fatPoint = double.tryParse(_fatPointController.text) ?? 0.1;
    double fatRate = double.tryParse(_fatRateController.text) ?? 1.0;

    double snfFrom = double.tryParse(_snfFromController.text) ?? (isIncrease ? 8.5 : 7.0);
    double snfTo = double.tryParse(_snfToController.text) ?? (isIncrease ? 10.0 : 8.5);
    double snfPoint = double.tryParse(_snfPointController.text) ?? 0.1;
    double snfRate = double.tryParse(_snfRateController.text) ?? 1.0;

    if (fatPoint <= 0) fatPoint = 0.1;
    if (snfPoint <= 0) snfPoint = 0.1;

    List<Map<String, dynamic>> rows = [];
    int counter = 1;

    for (double f = fatFrom; f <= fatTo + 0.01; f += 0.1) {
      double fat = double.parse(f.toStringAsFixed(1));
      for (double s = snfFrom; s <= snfTo + 0.01; s += 0.1) {
        double snf = double.parse(s.toStringAsFixed(1));

        if (isIncrease) {
          if (fat >= baseFat && snf >= baseSnf) {
            double finalRate = baseRate;
            int fPts = ((fat - baseFat) / fatPoint).round();
            int sPts = ((snf - baseSnf) / snfPoint).round();
            if (fPts > 0) finalRate += (fPts * fatRate);
            if (sPts > 0) finalRate += (sPts * snfRate);
            rows.add({'no': counter++, 'fat': fat, 'snf': snf, 'rate': finalRate});
          }
        } else {
          if (fat <= baseFat && snf <= baseSnf) {
            double finalRate = baseRate;
            int fPts = ((baseFat - fat) / fatPoint).round();
            int sPts = ((baseSnf - snf) / snfPoint).round();
            if (fPts > 0) finalRate -= (fPts * fatRate);
            if (sPts > 0) finalRate -= (sPts * snfRate);
            rows.add({'no': counter++, 'fat': fat, 'snf': snf, 'rate': finalRate});
          }
        }
      }
    }

    setState(() {
      _generatedChart = rows;
    });
  }

  Future<void> _exportPdf() async {
    if (_generatedChart.isEmpty) return;

    final isIncrease = _tabController.index == 0;
    final title = '$_animalType Main Dairy Rate Chart (${isIncrease ? "Increase" : "Decrease"})';

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.Text('Effective From: ${DateFormat('dd MMM yyyy').format(_effectiveDate)}', style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['No.', 'Fat %', 'SNF %', 'Rate'],
            data: _generatedChart.map((e) => [
              e['no'].toString(),
              e['fat'].toStringAsFixed(1),
              e['snf'].toStringAsFixed(1),
              'Rs ${e['rate'].toStringAsFixed(2)}'
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _saveConfig({bool saveAsNew = false}) async {
    final key = _tabController.index == 0 ? _incFormKey : _decFormKey;
    if (key.currentState != null && !key.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final rateType = _tabController.index == 0 ? 'Increase' : 'Decrease';

    try {
      final config = MainDairyRateConfig(
        id: (saveAsNew || _editingConfigId == null) ? '' : _editingConfigId!,
        animalType: _animalType,
        rateType: rateType,
        baseFat: double.parse(_baseFatController.text),
        baseSnf: double.parse(_baseSnfController.text),
        baseRate: double.parse(_baseRateController.text),
        fatRangeFrom: double.parse(_fatFromController.text),
        fatRangeTo: double.parse(_fatToController.text),
        fatPoint: double.parse(_fatPointController.text),
        fatRate: double.parse(_fatRateController.text),
        snfRangeFrom: double.parse(_snfFromController.text),
        snfRangeTo: double.parse(_snfToController.text),
        snfPoint: double.parse(_snfPointController.text),
        snfRate: double.parse(_snfRateController.text),
        effectiveDate: DateFormat('yyyy-MM-dd').format(_effectiveDate),
        isActive: true,
      );

      if (!saveAsNew && _editingConfigId != null && _editingConfigId!.isNotEmpty) {
        await ref.read(mainDairyRateProvider.notifier).updateRateConfig(_editingConfigId!, config);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_animalType ($rateType) Main Dairy Configuration updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await ref.read(mainDairyRateProvider.notifier).saveRateConfig(config);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New $_animalType ($rateType) Main Dairy Configuration saved!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      setState(() {
        _populateFormForSelectedAnimalAndTab();
      });
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

  Widget _buildField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (val) => val == null || val.isEmpty ? '*' : null,
      onChanged: (_) {
        setState(() {});
      },
    );
  }

  Widget _buildTabContent(bool isIncrease) {
    final lang = ref.watch(languageProvider);
    final themeColor = isIncrease ? Colors.green.shade600 : Colors.red.shade600;
    final bgColor = isIncrease ? Colors.green.shade50 : Colors.red.shade50;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: isIncrease ? _incFormKey : _decFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              color: bgColor,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: themeColor.withValues(alpha: 0.5))),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(isIncrease ? Icons.arrow_upward : Icons.arrow_downward, color: themeColor, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          isIncrease
                              ? AppTranslations.tr('Main Dairy Rate Increase Chart', lang)
                              : AppTranslations.tr('Main Dairy Rate Decrease Chart', lang),
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isIncrease
                          ? AppTranslations.tr('Outward dispatch rate increases when Fat or SNF is higher than base.', lang)
                          : AppTranslations.tr('Outward dispatch rate decreases when Fat or SNF is lower than base.', lang),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(AppTranslations.tr('Animal Type:', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _animalType,
                                  items: ['Cow Milk', 'Buffalo Milk'].map((e) => DropdownMenuItem(value: e, child: Text(AppTranslations.tr(e, lang), style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _animalType = val;
                                        _populateFormForSelectedAnimalAndTab();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(AppTranslations.tr('Effective Date:', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month, size: 20),
                              label: Text(DateFormat('dd MMM yyyy').format(_effectiveDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: BorderSide(color: Colors.grey.shade400),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _effectiveDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) setState(() => _effectiveDate = date);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Active Edit Mode Banner
            if (_editingConfigId != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400, width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.amber.shade900, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Editing Active Main Dairy Configuration: $_animalType (${isIncrease ? "Increase" : "Decrease"})',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 14),
                          ),
                          Text(
                            'Modify base values or ranges below and tap "Update Configuration", or "Save as New Version".',
                            style: TextStyle(color: Colors.brown.shade700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle, size: 18),
                      label: const Text('Create New Instead'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue.shade900),
                      onPressed: () {
                        setState(() {
                          _editingConfigId = null;
                          _effectiveDate = DateTime.now();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Switched to New Configuration mode.'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],

            // Base Values (Responsive)
            Text(AppTranslations.tr('Base Values', lang), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 650;
                if (isCompact) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildField(AppTranslations.tr('Base Fat', lang), _baseFatController)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildField(AppTranslations.tr('Base SNF', lang), _baseSnfController)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildField(AppTranslations.tr('Base Rate (₹)', lang), _baseRateController),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: _buildField(AppTranslations.tr('Base Fat', lang), _baseFatController)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField(AppTranslations.tr('Base SNF', lang), _baseSnfController)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField(AppTranslations.tr('Base Rate (₹)', lang), _baseRateController)),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Settings (Responsive)
            Text(
              isIncrease
                  ? AppTranslations.tr('Increase Settings', lang)
                  : AppTranslations.tr('Decrease Settings', lang),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColor),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 650;
                    if (isCompact) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildField(AppTranslations.tr('Fat Range From', lang), _fatFromController)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildField(AppTranslations.tr('Fat Range To', lang), _fatToController)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildField(AppTranslations.tr('Fat Point', lang), _fatPointController)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildField(AppTranslations.tr('Fat Rate (₹)', lang), _fatRateController)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildField(AppTranslations.tr('SNF Range From', lang), _snfFromController)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildField(AppTranslations.tr('SNF Range To', lang), _snfToController)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildField(AppTranslations.tr('SNF Point', lang), _snfPointController)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildField(AppTranslations.tr('SNF Rate (₹)', lang), _snfRateController)),
                            ],
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildField(AppTranslations.tr('Fat Range From', lang), _fatFromController)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildField(AppTranslations.tr('Fat Range To', lang), _fatToController)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildField(AppTranslations.tr('Fat Point', lang), _fatPointController)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildField(AppTranslations.tr('Fat Rate (₹)', lang), _fatRateController)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildField(AppTranslations.tr('SNF Range From', lang), _snfFromController)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildField(AppTranslations.tr('SNF Range To', lang), _snfToController)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildField(AppTranslations.tr('SNF Point', lang), _snfPointController)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildField(AppTranslations.tr('SNF Rate (₹)', lang), _snfRateController)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Actions
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart),
                  label: Text(AppTranslations.tr('Generate Chart', lang), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: _generateChart,
                ),
                ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(_editingConfigId != null ? Icons.check_circle : Icons.save),
                  label: Text(
                    _editingConfigId != null
                        ? AppTranslations.tr('Update Configuration', lang)
                        : AppTranslations.tr('Save Configuration', lang),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _editingConfigId != null ? Colors.amber.shade800 : Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: _isSaving ? null : () => _saveConfig(saveAsNew: false),
                ),
                if (_editingConfigId != null) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(AppTranslations.tr('Save as New Version', lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade800,
                      side: BorderSide(color: Colors.blue.shade800, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: _isSaving ? null : () => _saveConfig(saveAsNew: true),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Generated Preview
            if (_generatedChart.isNotEmpty) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Generated Preview (${_generatedChart.length} combinations)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Export PDF'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                            onPressed: _exportPdf,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 380,
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(themeColor.withValues(alpha: 0.12)),
                                columns: const [
                                  DataColumn(label: Text('No.', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Fat %', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('SNF %', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: _generatedChart.take(100).map((row) => DataRow(
                                  cells: [
                                    DataCell(Text(row['no'].toString())),
                                    DataCell(Text(row['fat'].toStringAsFixed(1))),
                                    DataCell(Text(row['snf'].toStringAsFixed(1))),
                                    DataCell(Text('₹ ${row['rate'].toStringAsFixed(2)}', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold))),
                                  ],
                                )).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAllSavedConfigsView() {
    final configsAsync = ref.watch(mainDairyRateProvider);

    return configsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading configurations: $e')),
      data: (configs) {
        var filteredConfigs = configs;
        if (_filterAnimalType != 'All') {
          filteredConfigs = filteredConfigs.where((c) => c.animalType == _filterAnimalType).toList();
        }
        if (_filterRateType != 'All') {
          filteredConfigs = filteredConfigs.where((c) => c.rateType == _filterRateType).toList();
        }

        final lang = ref.watch(languageProvider);
        return Column(
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey.shade100,
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppTranslations.tr('Animal: ', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _filterAnimalType,
                        items: ['All', 'Cow Milk', 'Buffalo Milk'].map((t) => DropdownMenuItem(value: t, child: Text(AppTranslations.tr(t, lang)))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _filterAnimalType = val);
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${AppTranslations.tr('Rate Type', lang)}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _filterRateType,
                        items: ['All', 'Increase', 'Decrease'].map((t) => DropdownMenuItem(value: t, child: Text(AppTranslations.tr(t, lang)))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _filterRateType = val);
                        },
                      ),
                    ],
                  ),
                  Text('Showing: ${filteredConfigs.length} of ${configs.length} records', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable 2D Table
            Expanded(
              child: filteredConfigs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(AppTranslations.tr('No saved Main Dairy rate configurations found.', lang), style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                            columnSpacing: 20,
                            columns: [
                              DataColumn(label: Text(AppTranslations.tr('Animal Type', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(AppTranslations.tr('Rate Type', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(AppTranslations.tr('Effective Date', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(AppTranslations.tr('Base Fat', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(AppTranslations.tr('Base SNF', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(AppTranslations.tr('Base Rate', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(AppTranslations.tr('Fat Range', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(AppTranslations.tr('Fat Increment', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(AppTranslations.tr('SNF Range', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(AppTranslations.tr('SNF Increment', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(AppTranslations.tr('Actions', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: filteredConfigs.map((c) {
                              final isIncrease = c.rateType == 'Increase';
                              return DataRow(
                                cells: [
                                  DataCell(Text(c.animalType, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isIncrease ? Colors.green.shade100 : Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        c.rateType,
                                        style: TextStyle(
                                          color: isIncrease ? Colors.green.shade800 : Colors.red.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(c.effectiveDate)),
                                  DataCell(Text('${c.baseFat}%')),
                                  DataCell(Text('${c.baseSnf}%')),
                                  DataCell(Text('₹${c.baseRate.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                                  DataCell(Text('${c.fatRangeFrom} - ${c.fatRangeTo}%')),
                                  DataCell(Text('${c.fatPoint} pt -> ₹${c.fatRate}')),
                                  DataCell(Text('${c.snfRangeFrom} - ${c.snfRangeTo}%')),
                                  DataCell(Text('${c.snfPoint} pt -> ₹${c.snfRate}')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          tooltip: 'Edit Configuration',
                                          onPressed: () {
                                            setState(() {
                                              _animalType = c.animalType;
                                              _populateFormForSelectedAnimalAndTab(specificConfig: c);
                                              _tabController.animateTo(isIncrease ? 0 : 1);
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Loaded ${c.animalType} (${c.rateType}) configuration into editor.')),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          tooltip: 'Delete Configuration',
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Delete Main Dairy Config'),
                                                content: Text('Are you sure you want to delete this ${c.animalType} (${c.rateType}) configuration?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              try {
                                                await ref.read(mainDairyRateProvider.notifier).deleteRateConfig(c.id, config: c);
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Main Dairy rate configuration deleted successfully.')),
                                                  );
                                                }
                                              } catch (err) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Failed to delete: $err'), backgroundColor: Colors.red),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final configsAsync = ref.watch(mainDairyRateProvider);
    if (!_isInitialized && configsAsync.hasValue) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _populateFormForSelectedAnimalAndTab();
          });
        }
      });
    }

    final totalCount = configsAsync.value?.length ?? 0;
    final lang = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.tr('Main Dairy Rate Management', lang)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade900,
          unselectedLabelColor: Colors.grey.shade700,
          indicatorColor: Colors.blue.shade900,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.arrow_upward, color: Colors.green),
              text: AppTranslations.tr('Rate Increase Chart', lang),
            ),
            Tab(
              icon: const Icon(Icons.arrow_downward, color: Colors.red),
              text: AppTranslations.tr('Rate Decrease Chart', lang),
            ),
            Tab(
              icon: Badge(
                label: Text(totalCount.toString()),
                isLabelVisible: totalCount > 0,
                child: const Icon(Icons.table_chart, color: Colors.blue),
              ),
              text: AppTranslations.tr('All Saved Configurations', lang),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(true),
          _buildTabContent(false),
          _buildAllSavedConfigsView(),
        ],
      ),
    );
  }
}
