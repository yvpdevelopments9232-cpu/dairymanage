import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/settings_provider.dart';
import '../../providers/main_dairy_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_db.dart';

class MainDairyReportsScreen extends ConsumerStatefulWidget {
  const MainDairyReportsScreen({super.key});

  @override
  ConsumerState<MainDairyReportsScreen> createState() => _MainDairyReportsScreenState();
}

class _MainDairyReportsScreenState extends ConsumerState<MainDairyReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Ledger Tab State
  String? _selectedDairyId;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  List<Map<String, dynamic>> _dispatchEntries = [];
  List<Map<String, dynamic>> _paymentEntries = [];
  bool _isLoadingLedger = false;

  // Annual Tab State
  int _selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> _monthlySummary = [];
  bool _isLoadingAnnual = false;

  double get _totalBilling => _dispatchEntries.fold(0.0, (s, e) => s + ((e['total_amount'] as num?)?.toDouble() ?? 0.0));
  double get _totalPaid => _paymentEntries.fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
  double get _totalRemaining => _totalBilling - _totalPaid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLedger() async {
    if (_selectedDairyId == null) return;
    setState(() => _isLoadingLedger = true);
    final supabase = AppDb.client;
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    try {
      final dispatches = await supabase
          .from('main_dairy_collections')
          .select()
          .eq('main_dairy_id', _selectedDairyId!)
          .gte('collection_date', startStr)
          .lte('collection_date', endStr)
          .order('collection_date');

      final payments = await supabase
          .from('main_dairy_payments')
          .select()
          .eq('main_dairy_id', _selectedDairyId!)
          .gte('payment_date', startStr)
          .lte('payment_date', endStr)
          .order('payment_date');

      setState(() {
        _dispatchEntries = List<Map<String, dynamic>>.from(dispatches);
        _paymentEntries = List<Map<String, dynamic>>.from(payments);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingLedger = false);
    }
  }

  Future<void> _fetchAnnualReport() async {
    setState(() => _isLoadingAnnual = true);
    final supabase = AppDb.client;
    final startStr = '$_selectedYear-01-01';
    final endStr = '$_selectedYear-12-31';

    try {
      final dispatches = await supabase
          .from('main_dairy_collections')
          .select('collection_date, quantity, total_amount')
          .gte('collection_date', startStr)
          .lte('collection_date', endStr);

      final payments = await supabase
          .from('main_dairy_payments')
          .select('payment_date, amount')
          .gte('payment_date', startStr)
          .lte('payment_date', endStr);

      Map<int, Map<String, double>> months = {};
      for (int m = 1; m <= 12; m++) {
        months[m] = {'qty': 0.0, 'billing': 0.0, 'paid': 0.0};
      }

      for (var d in dispatches as List) {
        final dt = DateTime.parse(d['collection_date']);
        final m = dt.month;
        months[m]!['qty'] = (months[m]!['qty'] ?? 0) + ((d['quantity'] ?? 0) as num).toDouble();
        months[m]!['billing'] = (months[m]!['billing'] ?? 0) + ((d['total_amount'] ?? 0) as num).toDouble();
      }

      for (var p in payments as List) {
        final dt = DateTime.parse(p['payment_date']);
        final m = dt.month;
        months[m]!['paid'] = (months[m]!['paid'] ?? 0) + ((p['amount'] ?? 0) as num).toDouble();
      }

      List<Map<String, dynamic>> list = [];
      months.forEach((m, data) {
        list.add({
          'month_num': m,
          'month_name': DateFormat('MMMM').format(DateTime(_selectedYear, m)),
          'qty': data['qty'] ?? 0.0,
          'billing': data['billing'] ?? 0.0,
          'paid': data['paid'] ?? 0.0,
          'balance': (data['billing'] ?? 0.0) - (data['paid'] ?? 0.0),
        });
      });

      setState(() => _monthlySummary = list);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingAnnual = false);
    }
  }

  Future<void> _printLedgerPdf(String dairyName) async {
    if (_dispatchEntries.isEmpty && _paymentEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to print.')));
      return;
    }

    final settings = ref.read(settingsProvider).value;
    final myDairyName = settings?.dairyName ?? 'My Dairy';
    final ownerName = settings?.ownerName ?? 'Owner';
    final phone = settings?.mobile ?? '';
    final address = settings?.address ?? '';

    pw.MemoryImage? logoImage;
    if (settings?.logoBytes != null) {
      logoImage = pw.MemoryImage(settings!.logoBytes!);
    }

    final pdf = pw.Document();
    final totalBilling = _totalBilling;
    final totalPaid = _totalPaid;
    final totalRemaining = _totalRemaining;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null) pw.Container(width: 60, height: 60, child: pw.Image(logoImage)),
              if (logoImage == null) pw.SizedBox(width: 60),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(myDairyName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Owner: $ownerName | Phone: $phone'),
                    pw.Text('Address: $address'),
                    pw.SizedBox(height: 12),
                    pw.Text('Main Dairy Dispatch & Ledger Statement', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                    pw.SizedBox(height: 8),
                  ],
                ),
              ),
              pw.SizedBox(width: 60),
            ],
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Main Dairy: $dairyName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Period: ${DateFormat('dd/MM/yyyy').format(_startDate)} to ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
            ],
          ),
          pw.SizedBox(height: 16),

          // Table 1: Dispatches
          pw.Text('1. Dispatched Milk Details', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (_dispatchEntries.isEmpty)
            pw.Text('No dispatches recorded in this period.', style: const pw.TextStyle(fontSize: 10))
          else
            pw.TableHelper.fromTextArray(
              context: context,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              headerHeight: 24,
              cellHeight: 20,
              headers: ['Date', 'Shift', 'Milk Type', 'Qty (Ltr)', 'Fat %', 'SNF %', 'Rate (Rs)', 'Total (Rs)'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8),
              data: [
                ..._dispatchEntries.map((e) => [
                  e['collection_date'],
                  e['shift'],
                  e['milk_type'],
                  (e['quantity'] as num).toDouble().toStringAsFixed(2),
                  (e['fat'] as num).toDouble().toStringAsFixed(2),
                  (e['snf'] as num).toDouble().toStringAsFixed(2),
                  (e['rate'] as num).toDouble().toStringAsFixed(2),
                  (e['total_amount'] as num).toDouble().toStringAsFixed(2),
                ]),
                ['', '', '', '', '', '', 'Total Billing:', totalBilling.toStringAsFixed(2)],
              ],
            ),

          pw.SizedBox(height: 18),

          // Table 2: Payments Received
          pw.Text('2. Payments Received', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (_paymentEntries.isEmpty)
            pw.Text('No payment records found for this period.', style: const pw.TextStyle(fontSize: 10))
          else
            pw.TableHelper.fromTextArray(
              context: context,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              headerHeight: 24,
              cellHeight: 20,
              headers: ['Date', 'Mode', 'Reference No', 'Remarks', 'Amount Received (Rs)'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8),
              data: [
                ..._paymentEntries.map((p) => [
                  p['payment_date'],
                  p['payment_mode'] ?? 'Bank Transfer',
                  p['reference_no'] ?? '-',
                  p['remarks'] ?? '-',
                  (p['amount'] as num).toDouble().toStringAsFixed(2),
                ]),
                ['', '', '', 'Total Paid:', totalPaid.toStringAsFixed(2)],
              ],
            ),

          pw.SizedBox(height: 18),
          pw.Divider(),

          // Summary
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total Dispatched Billing: Rs ${totalBilling.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Total Payments Received: Rs ${totalPaid.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Total Receivable Balance: Rs ${totalRemaining.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: totalRemaining > 0 ? PdfColors.red800 : PdfColors.green800)),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Main_Dairy_Statement.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final dairiesAsync = ref.watch(mainDairyProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Dairy Reports', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Dairy Ledger Statement'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Annual Dispatch Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Ledger Statement
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: dairiesAsync.when(
                        loading: () => const CircularProgressIndicator(),
                        error: (e, _) => const Text('Error'),
                        data: (list) => DropdownButtonFormField<String>(
                          value: _selectedDairyId,
                          decoration: const InputDecoration(labelText: 'Select Main Dairy', border: OutlineInputBorder()),
                          items: list.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                          onChanged: (v) {
                            setState(() => _selectedDairyId = v);
                            _fetchLedger();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                          );
                          if (range != null) {
                            setState(() {
                              _startDate = range.start;
                              _endDate = range.end;
                            });
                            _fetchLedger();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date Range', border: OutlineInputBorder()),
                          child: Text('${DateFormat('dd MMM yy').format(_startDate)} - ${DateFormat('dd MMM yy').format(_endDate)}'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _fetchLedger,
                      icon: const Icon(Icons.search),
                      label: const Text('GENERATE'),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        final dairies = dairiesAsync.value ?? [];
                        final dairy = dairies.where((d) => d.id == _selectedDairyId).firstOrNull;
                        _printLedgerPdf(dairy?.name ?? 'Main Dairy');
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('PRINT PDF'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingLedger
                    ? const Center(child: CircularProgressIndicator())
                    : (_dispatchEntries.isEmpty && _paymentEntries.isEmpty)
                        ? const Center(child: Text('Select a Main Dairy and date range to view ledger reports.'))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Table 1: Dispatches
                                Card(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        color: primaryColor.withOpacity(0.1),
                                        padding: const EdgeInsets.all(16),
                                        child: const Text('1. Dispatched Milk Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text('Shift', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text('Milk Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text('Quantity (Ltr)', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text('Fat %', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text('SNF %', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text('Total (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                          ],
                                          rows: _dispatchEntries.map((e) => DataRow(cells: [
                                            DataCell(Text(e['collection_date'])),
                                            DataCell(Text(e['shift'])),
                                            DataCell(Text(e['milk_type'])),
                                            DataCell(Text((e['quantity'] as num).toDouble().toStringAsFixed(2))),
                                            DataCell(Text((e['fat'] as num).toDouble().toStringAsFixed(2))),
                                            DataCell(Text((e['snf'] as num).toDouble().toStringAsFixed(2))),
                                            DataCell(Text('₹${(e['rate'] as num).toDouble().toStringAsFixed(2)}')),
                                            DataCell(Text('₹${(e['total_amount'] as num).toDouble().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                          ])).toList(),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        color: Colors.grey.shade100,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            const Text('Total Billing: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text('₹${_totalBilling.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Table 2: Payments Received
                                Card(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        color: Colors.green.withOpacity(0.1),
                                        padding: const EdgeInsets.all(16),
                                        child: const Text('2. Payments Received from Main Dairy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                      ),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text('Reference No', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                          ],
                                          rows: _paymentEntries.map((p) => DataRow(cells: [
                                            DataCell(Text(p['payment_date'])),
                                            DataCell(Text(p['payment_mode'] ?? '-')),
                                            DataCell(Text(p['reference_no'] ?? '-')),
                                            DataCell(Text(p['remarks'] ?? '-')),
                                            DataCell(Text('₹${(p['amount'] as num).toDouble().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                          ])).toList(),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        color: Colors.grey.shade100,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            const Text('Total Paid: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text('₹${_totalPaid.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Summary Bar
                                Card(
                                  elevation: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        Text('Total Billing: ₹${_totalBilling.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text('Total Paid: ₹${_totalPaid.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                        Text('Receivable Balance: ₹${_totalRemaining.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _totalRemaining > 0 ? Colors.red : Colors.green)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),

          // TAB 2: Annual Summary
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    const Text('Select Year: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _selectedYear,
                      items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                      onChanged: (y) {
                        setState(() => _selectedYear = y!);
                        _fetchAnnualReport();
                      },
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchAnnualReport,
                      icon: const Icon(Icons.refresh),
                      label: const Text('LOAD ANNUAL REPORT'),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingAnnual
                    ? const Center(child: CircularProgressIndicator())
                    : _monthlySummary.isEmpty
                        ? Center(
                            child: ElevatedButton(
                              onPressed: _fetchAnnualReport,
                              child: const Text('Click to Load Annual Report'),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Card(
                              elevation: 2,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Dispatched Milk (Ltr)', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Total Billing (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Payments Received (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Net Balance (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: _monthlySummary.map((m) => DataRow(cells: [
                                  DataCell(Text(m['month_name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text((m['qty'] as double).toStringAsFixed(2))),
                                  DataCell(Text('₹${(m['billing'] as double).toStringAsFixed(2)}')),
                                  DataCell(Text('₹${(m['paid'] as double).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green))),
                                  DataCell(Text('₹${(m['balance'] as double).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: (m['balance'] as double) > 0 ? Colors.red : Colors.green))),
                                ])).toList(),
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
