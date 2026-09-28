import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/flutter_models.dart';
import '../../providers/main_dairy_rate_provider.dart';

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

  // Inputs
  final _baseFatController = TextEditingController(text: '3.5');
  final _baseSnfController = TextEditingController(text: '8.5');
  final _baseRateController = TextEditingController(text: '40');

  final _fatFromController = TextEditingController(text: '2.5');
  final _fatToController = TextEditingController(text: '6.0');
  final _fatPointController = TextEditingController(text: '0.1');
  final _fatRateController = TextEditingController(text: '1.0');

  final _snfFromController = TextEditingController(text: '7.0');
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
      setState(() {
        _generatedChart = [];
      });
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

  void _generateChart() {
    final key = _tabController.index == 0 ? _incFormKey : _decFormKey;
    if (!key.currentState!.validate()) return;

    final isIncrease = _tabController.index == 0;

    double baseFat = double.parse(_baseFatController.text);
    double baseSnf = double.parse(_baseSnfController.text);
    double baseRate = double.parse(_baseRateController.text);

    double fatFrom = double.parse(_fatFromController.text);
    double fatTo = double.parse(_fatToController.text);
    double fatPoint = double.parse(_fatPointController.text);
    double fatRate = double.parse(_fatRateController.text);

    double snfFrom = double.parse(_snfFromController.text);
    double snfTo = double.parse(_snfToController.text);
    double snfPoint = double.parse(_snfPointController.text);
    double snfRate = double.parse(_snfRateController.text);

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
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _saveConfig() async {
    final key = _tabController.index == 0 ? _incFormKey : _decFormKey;
    if (!key.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final rateType = _tabController.index == 0 ? 'Increase' : 'Decrease';

    try {
      final config = MainDairyRateConfig(
        id: '',
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

      await ref.read(mainDairyRateProvider.notifier).saveRateConfig(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rate Configuration Saved successfully!'), backgroundColor: Colors.green),
        );
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (val) => val == null || val.isEmpty ? '*' : null,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: themeColor.withOpacity(0.5))),
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
                          isIncrease ? 'Rate Increase Chart' : 'Rate Decrease Chart',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isIncrease
                          ? 'Rate increases when Fat or SNF is higher than the base value.'
                          : 'Rate decreases when Fat or SNF is lower than the base value.',
                      style: TextStyle(color: Colors.grey.shade700),
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
                            if (val != null) setState(() => _animalType = val);
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

            // Base Values
            Text('Base Values', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildField('Base Fat', _baseFatController)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Base SNF', _baseSnfController)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Base Rate', _baseRateController)),
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
                    label: const Text('Generate Rate Chart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _generateChart,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isSaving ? null : _saveConfig,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Generated Preview
            if (_generatedChart.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Generated Preview (Top 100 rows)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
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
                      headingRowColor: WidgetStateProperty.all(themeColor.withOpacity(0.1)),
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
                        ],
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
    final configsAsync = ref.watch(mainDairyRateProvider);
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
            rows: configs.map((c) => DataRow(
              cells: [
                DataCell(Text(c.animalType, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.rateType == 'Increase' ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      c.rateType,
                      style: TextStyle(color: c.rateType == 'Increase' ? Colors.green.shade800 : Colors.red.shade800),
                    ),
                  ),
                ),
                DataCell(Text(c.effectiveDate)),
                DataCell(Text('${c.baseFat} / ${c.baseSnf} / ₹${c.baseRate}')),
                DataCell(Text('${c.fatPoint} -> ₹${c.fatRate}')),
                DataCell(Text('${c.snfPoint} -> ₹${c.snfRate}')),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Config'),
                          content: const Text('Are you sure you want to delete this configuration?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await ref.read(mainDairyRateProvider.notifier).deleteRateConfig(c.id, config: c);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Main dairy rate configuration deleted successfully.')),
                            );
                          }
                        } catch (err) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to delete: $err'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              ],
            )).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Saved Rate Configurations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                ),
                Expanded(child: _buildSavedConfigs()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
