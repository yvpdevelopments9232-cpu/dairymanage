import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../providers/rate_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class RateManagementScreen extends ConsumerStatefulWidget {
  const RateManagementScreen({super.key});

  @override
  ConsumerState<RateManagementScreen> createState() => _RateManagementScreenState();
}

class _RateManagementScreenState extends ConsumerState<RateManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _incFormKey = GlobalKey<FormState>();
  final _decFormKey = GlobalKey<FormState>();

  String _animalType = 'Cow Milk';
  DateTime _effectiveDate = DateTime.now();
  String? _editingConfigId;
  bool _isInitialized = false;

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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
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

  void _populateFormForSelectedAnimalAndTab({RateConfig? specificConfig}) {
    final isIncrease = _tabController.index == 0;
    final targetRateType = isIncrease ? 'Increase' : 'Decrease';

    RateConfig? configToUse = specificConfig;
    if (configToUse == null) {
      final configs = ref.read(rateConfigProvider).value ?? [];
      final matches = configs.where((c) => c.animalType == _animalType && c.rateType == targetRateType).toList();
      if (matches.isNotEmpty) {
        configToUse = matches.first;
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
      _effectiveDate = DateTime.now();
      if (_animalType == 'Cow Milk') {
        _baseFatController.text = '3.5';
        _baseSnfController.text = '8.5';
        _baseRateController.text = '40.0';
        _fatFromController.text = isIncrease ? '3.5' : '2.0';
        _fatToController.text = isIncrease ? '6.0' : '3.5';
        _fatPointController.text = '0.1';
        _fatRateController.text = '1.0';
        _snfFromController.text = isIncrease ? '8.5' : '7.0';
        _snfToController.text = isIncrease ? '10.0' : '8.5';
        _snfPointController.text = '0.1';
        _snfRateController.text = '1.0';
      } else {
        // Buffalo Milk
        _baseFatController.text = '6.0';
        _baseSnfController.text = '9.0';
        _baseRateController.text = '55.0';
        _fatFromController.text = isIncrease ? '6.0' : '4.5';
        _fatToController.text = isIncrease ? '10.0' : '6.0';
        _fatPointController.text = '0.1';
        _fatRateController.text = '1.0';
        _snfFromController.text = isIncrease ? '9.0' : '7.5';
        _snfToController.text = isIncrease ? '11.5' : '9.0';
        _snfPointController.text = '0.1';
        _snfRateController.text = '1.0';
      }
    }

    _generateChart();
  }

  void _generateChart() {
    final key = _tabController.index == 0 ? _incFormKey : _decFormKey;
    if (key.currentState != null && !key.currentState!.validate()) return;

    final isIncrease = _tabController.index == 0;
    
    double baseFat = double.tryParse(_baseFatController.text) ?? (isIncrease ? 3.5 : 3.5);
    double baseSnf = double.tryParse(_baseSnfController.text) ?? (isIncrease ? 8.5 : 8.5);
    double baseRate = double.tryParse(_baseRateController.text) ?? (isIncrease ? 40.0 : 40.0);
    
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
    final title = '$_animalType Rate Chart (${isIncrease ? "Increase" : "Decrease"})';

    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.Text('Effective From: ${DateFormat('dd MMM yyyy').format(_effectiveDate)}', style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
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
        ]
      )
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _saveConfig({bool saveAsNew = false}) async {
    final session = ref.read(sessionProvider);
    if (session != null && !session.isAdmin && (!session.canAdd('Rate Management') && !session.canEdit('Rate Management'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to edit rates.'), backgroundColor: Colors.red)
      );
      return;
    }
    final key = _tabController.index == 0 ? _incFormKey : _decFormKey;
    if (key.currentState != null && !key.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final rateType = _tabController.index == 0 ? 'Increase' : 'Decrease';
    final dateStr = DateFormat('yyyy-MM-dd').format(_effectiveDate);

    try {
      final config = RateConfig(
        id: (!saveAsNew && _editingConfigId != null) ? _editingConfigId! : '',
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
        effectiveDate: dateStr,
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
      );

      if (!saveAsNew && _editingConfigId != null && _editingConfigId!.isNotEmpty) {
        await ref.read(rateConfigProvider.notifier).updateRateConfig(_editingConfigId!, config);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_animalType ($rateType) updated: Base Rate ₹${config.baseRate} applies immediately!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } else {
        await ref.read(rateConfigProvider.notifier).saveRateConfig(config);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New $_animalType ($rateType) saved effective from $dateStr!'),
              backgroundColor: Colors.green.shade700,
            ),
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

  Widget _buildField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (val) => val == null || val.isEmpty ? '*' : null,
      onChanged: (_) {
        // Automatically reflect preview when fields are edited
        _generateChart();
      },
    );
  }

  Widget _buildTabContent(bool isIncrease) {
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
                        Text(isIncrease ? 'Rate Increase Chart' : 'Rate Decrease Chart', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isIncrease ? 'Rate increases when Fat or SNF is higher than the base value.' : 'Rate decreases when Fat or SNF is lower than the base value.',
                      style: TextStyle(color: Colors.grey.shade700)
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Animal Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: _animalType,
                          items: ['Cow Milk', 'Buffalo Milk'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _animalType = val;
                                _populateFormForSelectedAnimalAndTab();
                              });
                            }
                          },
                        ),
                        const Spacer(),
                        const Text('Effective Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month),
                          label: Text(DateFormat('dd MMM yyyy').format(_effectiveDate)),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _effectiveDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) setState(() => _effectiveDate = date);
                          },
                        )
                      ],
                    )
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
                    Icon(Icons.edit_note, color: Colors.amber.shade900, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Configuration Loaded for $_animalType (${isIncrease ? "Increase" : "Decrease"})',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 14),
                          ),
                          Text(
                            'Modify base price or ranges below and tap "Update Configuration", or tap "Save as New Version" for a new date.',
                            style: TextStyle(color: Colors.brown.shade700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle, size: 18),
                      label: const Text('New Mode'),
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
            
            // Base Values
            Text('Base Values', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildField('Base Fat', _baseFatController)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Base SNF', _baseSnfController)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Base Rate (₹)', _baseRateController)),
              ],
            ),
            const SizedBox(height: 16),

            // Settings
            Text(isIncrease ? 'Increase Settings' : 'Decrease Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColor)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildField('Fat Range From', _fatFromController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildField('Fat Range To', _fatToController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildField('Fat Point', _fatPointController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildField('Fat Rate (₹)', _fatRateController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildField('SNF Range From', _snfFromController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildField('SNF Range To', _snfToController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildField('SNF Point', _snfPointController)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildField('SNF Rate (₹)', _snfRateController)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Generate Chart', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _generateChart,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(_editingConfigId != null ? Icons.check_circle : Icons.save),
                    label: Text(
                      _editingConfigId != null ? 'Update Configuration' : 'Save Configuration',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _editingConfigId != null ? Colors.amber.shade800 : Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSaving ? null : () => _saveConfig(saveAsNew: false),
                  ),
                ),
                if (_editingConfigId != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Save as New Version', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade800,
                        side: BorderSide(color: Colors.blue.shade800, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isSaving ? null : () => _saveConfig(saveAsNew: true),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Generated Preview
            if (_generatedChart.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Generated Preview (${_generatedChart.length} combinations)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                    onPressed: _exportPdf,
                  )
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(themeColor.withValues(alpha: 0.1)),
                      columns: const [
                        DataColumn(label: Text('No.', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Fat', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('SNF', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _generatedChart.take(100).map((row) => DataRow(
                        cells: [
                          DataCell(Text(row['no'].toString())),
                          DataCell(Text(row['fat'].toStringAsFixed(1))),
                          DataCell(Text(row['snf'].toStringAsFixed(1))),
                          DataCell(Text('₹ ${row['rate'].toStringAsFixed(2)}', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold))),
                        ]
                      )).toList(),
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSavedConfigs() {
    final configsAsync = ref.watch(rateConfigProvider);
    return configsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (configs) {
        if (configs.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No saved configurations found.')));
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
            columns: const [
              DataColumn(label: Text('Animal Type')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Effective Date')),
              DataColumn(label: Text('Base Fat/SNF/Rate')),
              DataColumn(label: Text('Fat Pts/Rate')),
              DataColumn(label: Text('SNF Pts/Rate')),
              DataColumn(label: Text('Actions')),
            ],
            rows: configs.map((c) {
              final isBeingEdited = _editingConfigId == c.id;
              return DataRow(
                color: isBeingEdited ? WidgetStateProperty.all(Colors.amber.shade50) : null,
                cells: [
                  DataCell(Text(c.animalType, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.rateType == 'Increase' ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Text(c.rateType, style: TextStyle(color: c.rateType == 'Increase' ? Colors.green.shade800 : Colors.red.shade800)),
                    )
                  ),
                  DataCell(Text(c.effectiveDate)),
                  DataCell(Text('${c.baseFat} / ${c.baseSnf} / ₹${c.baseRate}')),
                  DataCell(Text('${c.fatPoint} -> ₹${c.fatRate}')),
                  DataCell(Text('${c.snfPoint} -> ₹${c.snfRate}')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: isBeingEdited ? Colors.amber.shade900 : Colors.blue),
                          tooltip: 'Edit Configuration',
                          onPressed: () {
                            setState(() {
                              _animalType = c.animalType;
                              final targetIndex = c.rateType == 'Increase' ? 0 : 1;
                              if (_tabController.index != targetIndex) {
                                _tabController.animateTo(targetIndex);
                              }
                              _populateFormForSelectedAnimalAndTab(specificConfig: c);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Loaded ${c.animalType} (${c.rateType}) configuration into editor.'),
                                backgroundColor: Colors.blue.shade700,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete Configuration',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Config'),
                                content: Text('Are you sure you want to delete this ${c.animalType} (${c.rateType}) configuration effective from ${c.effectiveDate}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await ref.read(rateConfigProvider.notifier).deleteRateConfig(c.id, config: c);
                                if (!mounted) return;
                                if (_editingConfigId == c.id) {
                                  setState(() {
                                    _editingConfigId = null;
                                    _populateFormForSelectedAnimalAndTab();
                                  });
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Rate configuration deleted successfully.')),
                                );
                              } catch (err) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to delete: $err'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    )
                  ),
                ]
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initial auto-populate when rateConfigProvider loads
    final configsAsync = ref.watch(rateConfigProvider);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade900,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue.shade900,
          tabs: const [
            Tab(icon: Icon(Icons.arrow_upward, color: Colors.green), text: 'Rate Increase Chart'),
            Tab(icon: Icon(Icons.arrow_downward, color: Colors.red), text: 'Rate Decrease Chart'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(true),
                _buildTabContent(false),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Saved Rate Configurations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                      Text('Tap Edit to load into form', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                Expanded(child: _buildSavedConfigs()),
              ],
            )
          )
        ],
      ),
    );
  }
}
