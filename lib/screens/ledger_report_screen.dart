import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/settings_provider.dart';
import '../providers/staff_provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/farmer_provider.dart';
import '../providers/supplier_provider.dart';

class LedgerReportScreen extends ConsumerStatefulWidget {
  final String partyType; // 'Farmer', 'Customer', 'Dealer'

  const LedgerReportScreen({super.key, required this.partyType});

  @override
  ConsumerState<LedgerReportScreen> createState() => _LedgerReportScreenState();
}

class _LedgerReportScreenState extends ConsumerState<LedgerReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedPartyId;
  
  List<Map<String, dynamic>> _billingEntries = [];
  List<Map<String, dynamic>> _paymentEntries = [];
  bool _isLoading = false;
  double _closingBalance = 0;

  double get _totalBilling => _billingEntries.fold(0.0, (sum, item) => sum + ((item['total'] as num?)?.toDouble() ?? 0.0));
  double get _totalPaid => _paymentEntries.fold(0.0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0.0));
  double get _totalRemaining => _totalBilling - _totalPaid;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.partyType} Ledger Report', style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildPartyDropdown(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: DateTimeRange(start: _startDate!, end: _endDate!),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked.start;
                          _endDate = picked.end;
                        });
                        _fetchLedger();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date Range', border: OutlineInputBorder()),
                      child: Text(
                        '${DateFormat('dd MMM yy').format(_startDate!)} - ${DateFormat('dd MMM yy').format(_endDate!)}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('GENERATE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  ),
                  onPressed: _fetchLedger,
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('PRINT'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)),
                  onPressed: () {
                    if (_selectedPartyId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a party first.')));
                      return;
                    }
                    dynamic partyObj;
                    try {
                      if (widget.partyType == 'Farmer') {
                        partyObj = ref.read(farmersProvider).value?.firstWhere((x) => x.id == _selectedPartyId);
                      } else if (widget.partyType == 'Customer') {
                        partyObj = ref.read(customersProvider).value?.firstWhere((x) => x.id == _selectedPartyId);
                      } else if (widget.partyType == 'Dealer') {
                        partyObj = ref.read(supplierProvider).value?.firstWhere((x) => x.id == _selectedPartyId);
                      } else if (widget.partyType == 'Staff') {
                        partyObj = ref.read(staffProvider).value?.firstWhere((x) => x.id == _selectedPartyId);
                      }
                    } catch (_) {}
                    _generatePdf(partyObj ?? _selectedPartyId);
                  },
                ),
              ],
            ),
          ),
          
          // Tables View
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : (_billingEntries.isEmpty && _paymentEntries.isEmpty)
                ? const Center(child: Text('No transactions found for this period. Please select a party and date range.'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Table 1: Billing (Products)
                        Card(
                          elevation: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                color: primaryColor.withOpacity(0.1),
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  '1. Billing Details (${widget.partyType == 'Dealer' ? 'Purchases' : 'Sales'})',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: const [
                                    Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 4, child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text('Quantity', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text('Price (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text('Total (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              if (_billingEntries.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No billing records found for this period.'),
                                )
                              else
                                ..._billingEntries.map((entry) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 2, child: Text(entry['date'])),
                                      Expanded(flex: 4, child: Text(entry['product_name'])),
                                      Expanded(flex: 2, child: Text((entry['quantity'] as double).toStringAsFixed(2), textAlign: TextAlign.right)),
                                      Expanded(flex: 2, child: Text('₹${(entry['price'] as double).toStringAsFixed(2)}', textAlign: TextAlign.right)),
                                      Expanded(flex: 2, child: Text('₹${(entry['total'] as double).toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                )),
                              Container(
                                color: Colors.grey.shade100,
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text('Total Billing Value: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text('₹${_totalBilling.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Table 2: Payment History
                        Card(
                          elevation: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                color: Colors.green.withOpacity(0.1),
                                padding: const EdgeInsets.all(16),
                                child: const Text(
                                  '2. Payment History',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: const [
                                    Expanded(flex: 3, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 6, child: Text('Payment Particulars / Mode', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 3, child: Text('Paid Amount (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              if (_paymentEntries.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No payment records found for this period.'),
                                )
                              else
                                ..._paymentEntries.map((entry) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 3, child: Text(entry['date'])),
                                      Expanded(flex: 6, child: Text(entry['particulars'])),
                                      Expanded(flex: 3, child: Text('₹${(entry['amount'] as double).toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                    ],
                                  ),
                                )),
                              Container(
                                color: Colors.grey.shade100,
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text('Total Paid Value: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text('₹${_totalPaid.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Summary Bar
                        Card(
                          elevation: 3,
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text('Total Billing Amount', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                    const SizedBox(height: 6),
                                    Text('₹${_totalBilling.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Container(height: 40, width: 1, color: Colors.grey.shade300),
                                Column(
                                  children: [
                                    const Text('Total Paid Amount', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                    const SizedBox(height: 6),
                                    Text('₹${_totalPaid.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                                Container(height: 40, width: 1, color: Colors.grey.shade300),
                                Column(
                                  children: [
                                    const Text('Total Remaining Amount', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                    const SizedBox(height: 6),
                                    Text(
                                      '₹${_totalRemaining.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: _totalRemaining > 0 ? Colors.red : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
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
    );
  }

  Future<void> _fetchLedger() async {
    if (_selectedPartyId == null || _startDate == null || _endDate == null) return;
    
    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseClientProvider);
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate!);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate!);
    
    List<Map<String, dynamic>> billingList = [];
    List<Map<String, dynamic>> paymentList = [];
    double calculatedClosing = 0;

    try {
      if (widget.partyType == 'Farmer') {
        final collections = await supabase.from('milk_collections')
          .select('collection_date, total_amount, milk_type, quantity, rate')
          .eq('farmer_id', _selectedPartyId as Object)
          .gte('collection_date', startStr)
          .lte('collection_date', endStr)
          .order('collection_date');
          
        for (var c in collections as List) {
          final qty = (c['quantity'] ?? 0).toDouble();
          final rate = (c['rate'] ?? 0).toDouble();
          final total = (c['total_amount'] ?? (qty * rate)).toDouble();
          billingList.add({
            'date': c['collection_date'],
            'product_name': '${c['milk_type'] ?? 'Milk'}',
            'quantity': qty,
            'price': rate,
            'total': total,
          });
        }
        
        final sales = await supabase.from('sales')
          .select('sale_date, invoice_no, grand_total, paid_amount, sale_items(quantity, rate, total_amount, products(name))')
          .eq('farmer_id', _selectedPartyId as Object)
          .gte('sale_date', startStr)
          .lte('sale_date', endStr)
          .order('sale_date');
          
        for (var s in sales as List) {
          final items = s['sale_items'] as List?;
          if (items != null && items.isNotEmpty) {
            for (var item in items) {
              final pName = item['products']?['name'] ?? 'Product';
              final qty = (item['quantity'] ?? 0).toDouble();
              final rate = (item['rate'] ?? 0).toDouble();
              final total = (item['total_amount'] ?? (qty * rate)).toDouble();
              billingList.add({
                'date': s['sale_date'],
                'product_name': 'Purchase: $pName',
                'quantity': qty,
                'price': rate,
                'total': total,
              });
            }
          }
        }
        
        final payments = await supabase.from('payments')
          .select('payment_date, amount, payment_mode, reference_no')
          .eq('party_type', 'Farmer')
          .eq('farmer_id', _selectedPartyId as Object)
          .gte('payment_date', startStr)
          .lte('payment_date', endStr)
          .order('payment_date');
          
        for (var p in payments as List) {
          final mode = p['payment_mode'] ?? 'Cash';
          paymentList.add({
            'date': p['payment_date'],
            'particulars': 'Payment Paid ($mode)',
            'amount': (p['amount'] ?? 0).toDouble(),
          });
        }
        
        final asyncVal = ref.read(farmersProvider);
        if (asyncVal.value != null) {
          final f = asyncVal.value!.firstWhere((x) => x.id == _selectedPartyId);
          calculatedClosing = f.currentBalance; 
        }

      } else if (widget.partyType == 'Customer') {
        // Sales to Customer (Rate is Selling Rate)
        final sales = await supabase.from('sales')
          .select('sale_date, invoice_no, grand_total, paid_amount, sale_items(quantity, rate, total_amount, products(name, selling_rate))')
          .eq('customer_id', _selectedPartyId as Object)
          .gte('sale_date', startStr)
          .lte('sale_date', endStr)
          .order('sale_date');
          
        for (var s in sales as List) {
          final date = s['sale_date'];
          final items = s['sale_items'] as List?;
          if (items != null && items.isNotEmpty) {
            for (var item in items) {
              final pName = item['products']?['name'] ?? 'Product';
              final qty = (item['quantity'] ?? 0).toDouble();
              final price = (item['rate'] ?? item['products']?['selling_rate'] ?? 0).toDouble();
              final total = (item['total_amount'] ?? (qty * price)).toDouble();
              billingList.add({
                'date': date,
                'product_name': pName,
                'quantity': qty,
                'price': price,
                'total': total,
              });
            }
          } else {
            billingList.add({
              'date': date,
              'product_name': 'Sale Inv #${s['invoice_no']}',
              'quantity': 1.0,
              'price': (s['grand_total'] ?? 0).toDouble(),
              'total': (s['grand_total'] ?? 0).toDouble(),
            });
          }
          
          final paidAtSale = (s['paid_amount'] ?? 0).toDouble();
          if (paidAtSale > 0) {
            paymentList.add({
              'date': date,
              'particulars': 'Payment at Sale (Inv #${s['invoice_no']})',
              'amount': paidAtSale,
            });
          }
        }
        
        // Payments Received from Customer
        final payments = await supabase.from('payments')
          .select('payment_date, amount, payment_mode, reference_no, remarks')
          .eq('party_type', 'Customer')
          .eq('customer_id', _selectedPartyId as Object)
          .gte('payment_date', startStr)
          .lte('payment_date', endStr)
          .order('payment_date');
          
        for (var p in payments as List) {
          final mode = p['payment_mode'] ?? 'Cash';
          final refNo = p['reference_no'] != null && p['reference_no'].toString().isNotEmpty ? ' (${p['reference_no']})' : '';
          paymentList.add({
            'date': p['payment_date'],
            'particulars': 'Payment Received - $mode$refNo',
            'amount': (p['amount'] ?? 0).toDouble(),
          });
        }
        
        final asyncVal = ref.read(customersProvider);
        if (asyncVal.value != null) {
          final c = asyncVal.value!.firstWhere((x) => x.id == _selectedPartyId);
          calculatedClosing = c.currentBalance; 
        }
        
      } else if (widget.partyType == 'Dealer') {
        // Purchases from Dealer (Rate is Purchase Rate)
        final purchases = await supabase.from('purchases')
          .select('purchase_date, invoice_no, grand_total, paid_amount, purchase_items(quantity, purchase_rate, products(name, purchase_rate))')
          .eq('supplier_id', _selectedPartyId as Object)
          .gte('purchase_date', startStr)
          .lte('purchase_date', endStr)
          .order('purchase_date');
          
        for (var p in purchases as List) {
          final date = p['purchase_date'];
          final items = p['purchase_items'] as List?;
          if (items != null && items.isNotEmpty) {
            for (var item in items) {
              final pName = item['products']?['name'] ?? 'Stock Item';
              final qty = (item['quantity'] ?? 0).toDouble();
              final price = (item['purchase_rate'] ?? item['products']?['purchase_rate'] ?? 0).toDouble();
              final total = qty * price;
              billingList.add({
                'date': date,
                'product_name': pName,
                'quantity': qty,
                'price': price,
                'total': total > 0 ? total : (p['grand_total'] ?? 0).toDouble(),
              });
            }
          } else {
            billingList.add({
              'date': date,
              'product_name': 'Purchase Inv #${p['invoice_no']}',
              'quantity': 1.0,
              'price': (p['grand_total'] ?? 0).toDouble(),
              'total': (p['grand_total'] ?? 0).toDouble(),
            });
          }
          
          final paidOnPur = (p['paid_amount'] ?? 0).toDouble();
          if (paidOnPur > 0) {
            paymentList.add({
              'date': date,
              'particulars': 'Payment on Purchase (Inv #${p['invoice_no']})',
              'amount': paidOnPur,
            });
          }
        }
        
        // Payments Paid to Dealer
        final payments = await supabase.from('payments')
          .select('payment_date, amount, payment_mode, reference_no, remarks')
          .eq('party_type', 'Supplier')
          .eq('supplier_id', _selectedPartyId as Object)
          .gte('payment_date', startStr)
          .lte('payment_date', endStr)
          .order('payment_date');
          
        for (var p in payments as List) {
          final mode = p['payment_mode'] ?? 'Cash';
          final refNo = p['reference_no'] != null && p['reference_no'].toString().isNotEmpty ? ' (${p['reference_no']})' : '';
          paymentList.add({
            'date': p['payment_date'],
            'particulars': 'Payment Paid - $mode$refNo',
            'amount': (p['amount'] ?? 0).toDouble(),
          });
        }
        
        final asyncVal = ref.read(supplierProvider);
        if (asyncVal.value != null) {
          final s = asyncVal.value!.firstWhere((x) => x.id == _selectedPartyId);
          calculatedClosing = s.currentBalance; 
        }
      }

      billingList.sort((a, b) => a['date'].compareTo(b['date']));
      paymentList.sort((a, b) => a['date'].compareTo(b['date']));

      setState(() {
        _billingEntries = billingList;
        _paymentEntries = paymentList;
        _closingBalance = calculatedClosing;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePdf(dynamic party) async {
    if (_billingEntries.isEmpty && _paymentEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No ledger data to print.')));
      return;
    }
    
    final settingsAsync = ref.read(settingsProvider);
    final dairyName = settingsAsync.value?.dairyName ?? 'Shree Ganesh Dairy';
    final ownerName = settingsAsync.value?.ownerName ?? 'Owner Name';
    final phone = settingsAsync.value?.mobile ?? '1234567890';
    final address = settingsAsync.value?.address ?? 'Dairy Address';
    
    pw.MemoryImage? logoImage;
    if (settingsAsync.value?.logoBytes != null) {
      logoImage = pw.MemoryImage(settingsAsync.value!.logoBytes!);
    }
    
    String pName = 'Unknown';
    String pMobile = '';
    
    if (party != null) {
      if (party is String) {
        pName = party;
      } else {
        try { pName = party.name ?? 'Unknown'; } catch (_) {}
        try { pMobile = party.mobile ?? ''; } catch (_) {}
      }
    }
    
    final totalBilling = _totalBilling;
    final totalPaid = _totalPaid;
    final totalRemaining = _totalRemaining;
    
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null)
                  pw.Container(width: 60, height: 60, child: pw.Image(logoImage)),
                if (logoImage == null)
                  pw.SizedBox(width: 60),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(dairyName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Owner: $ownerName | Phone: $phone'),
                      pw.Text('Address: $address'),
                      pw.SizedBox(height: 12),
                      pw.Text('${widget.partyType} Ledger Report', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
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
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Party Name: $pName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    if (pMobile.isNotEmpty) pw.Text('Mobile: $pMobile'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date Range: ${DateFormat('dd/MM/yyyy').format(_startDate!)} to ${DateFormat('dd/MM/yyyy').format(_endDate!)}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            
            // 1. BILLING DETAILS TABLE
            pw.Text(
              '1. Billing Details (${widget.partyType == 'Dealer' ? 'Purchases' : 'Sales'})',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            if (_billingEntries.isEmpty)
              pw.Text('No billing records recorded in this period.', style: const pw.TextStyle(fontSize: 10))
            else
              pw.TableHelper.fromTextArray(
                context: context,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headerHeight: 25,
                cellHeight: 22,
                headers: ['Date', 'Product Name', 'Quantity', 'Price (Rs)', 'Total (Rs)'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
                data: [
                  ..._billingEntries.map((e) => [
                    e['date'],
                    e['product_name'],
                    (e['quantity'] as double).toStringAsFixed(2),
                    (e['price'] as double).toStringAsFixed(2),
                    (e['total'] as double).toStringAsFixed(2),
                  ]),
                  [
                    '',
                    '',
                    '',
                    'Total Billing Value:',
                    totalBilling.toStringAsFixed(2),
                  ],
                ],
              ),
              
            pw.SizedBox(height: 20),
            
            // 2. PAYMENT HISTORY TABLE
            pw.Text(
              '2. Payment History',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            if (_paymentEntries.isEmpty)
              pw.Text('No payment records found for this period.', style: const pw.TextStyle(fontSize: 10))
            else
              pw.TableHelper.fromTextArray(
                context: context,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headerHeight: 25,
                cellHeight: 22,
                headers: ['Date', 'Payment Particulars / Mode', 'Paid Amount (Rs)'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                },
                data: [
                  ..._paymentEntries.map((p) => [
                    p['date'],
                    p['particulars'],
                    (p['amount'] as double).toStringAsFixed(2),
                  ]),
                  [
                    '',
                    'Total Paid Value:',
                    totalPaid.toStringAsFixed(2),
                  ],
                ],
              ),
              
            pw.SizedBox(height: 20),
            pw.Divider(),
            
            // FINAL SUMMARY
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Total Billing Amount: Rs ${totalBilling.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Total Paid Amount: Rs ${totalPaid.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Total Remaining Amount: Rs ${totalRemaining.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: totalRemaining > 0 ? PdfColors.red800 : PdfColors.green800,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
    
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${widget.partyType}_Ledger_Report.pdf',
    );
  }

  Widget _buildPartyDropdown() {
    if (widget.partyType == 'Farmer') {
      final asyncVal = ref.watch(farmersProvider);
      return asyncVal.when(
        loading: () => const CircularProgressIndicator(),
        error: (e, s) => const Text('Error'),
        data: (list) => DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Select Farmer', border: OutlineInputBorder()),
          value: _selectedPartyId,
          items: list.map((e) => DropdownMenuItem(value: e.id, child: Text('#${e.farmerNo} - ${e.name}'))).toList(),
          onChanged: (val) {
            setState(() => _selectedPartyId = val);
            _fetchLedger();
          },
        ),
      );
    } else if (widget.partyType == 'Customer') {
      final asyncVal = ref.watch(customersProvider);
      return asyncVal.when(
        loading: () => const CircularProgressIndicator(),
        error: (e, s) => const Text('Error'),
        data: (list) => DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Select Customer', border: OutlineInputBorder()),
          value: _selectedPartyId,
          items: list.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
          onChanged: (val) {
            setState(() => _selectedPartyId = val);
            _fetchLedger();
          },
        ),
      );
    } else {
      final asyncVal = ref.watch(supplierProvider);
      return asyncVal.when(
        loading: () => const CircularProgressIndicator(),
        error: (e, s) => const Text('Error'),
        data: (list) => DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Select Dealer', border: OutlineInputBorder()),
          value: _selectedPartyId,
          items: list.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
          onChanged: (val) {
            setState(() => _selectedPartyId = val);
            _fetchLedger();
          },
        ),
      );
    }
  }
}
