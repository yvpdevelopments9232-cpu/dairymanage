import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../providers/sales_report_provider.dart';
import '../providers/settings_provider.dart';

class SalesReportScreen extends ConsumerWidget {
  const SalesReportScreen({super.key});

  Future<void> _generatePdf(BuildContext context, SalesReportData data, DateTime start, DateTime end, dynamic settings) async {
    final pdf = pw.Document();

    final dairyName = settings?.dairyName ?? 'Shree Ganesh Dairy';
    final ownerName = settings?.ownerName ?? 'Owner Name';
    final phone = settings?.mobile ?? '1234567890';
    final address = settings?.address ?? 'Dairy Address';

    final dateStr = '${DateFormat('dd/MM/yyyy').format(start)} to ${DateFormat('dd/MM/yyyy').format(end)}';

    
    pw.MemoryImage? logoImage;
    if (settings?.logoBytes != null) {
      logoImage = pw.MemoryImage(settings!.logoBytes!);
    }
    
    pw.Widget _buildHeader() {
      return pw.Row(
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
            pw.Text('PRODUCT SALES REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
            pw.Text('Period: $dateStr'),
            pw.SizedBox(height: 16),
          
            ],
          ),
        ),
        pw.SizedBox(width: 60),
      ],
    );
    }

    final mainHeaders = ['Date', 'Buyer Name', 'Product Name', 'Quantity', 'Price (Rs)', 'Total (Rs)'];
    final mainData = data.entries.map((e) => [
      e.date, e.buyerName, e.productName, e.quantity.toStringAsFixed(2), e.price.toStringAsFixed(2), e.total.toStringAsFixed(2)
    ]).toList();

    final summaryHeaders = ['Product Name', 'Total Quantity Sold', 'Total Amount (Rs)'];
    final summaryData = data.productSummaries.map((s) => [
      s.productName, s.totalQuantity.toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)
    ]).toList();
    
    // Add Grand Total row to summary
    summaryData.add(['GRAND TOTAL', '', data.grandTotalAmount.toStringAsFixed(2)]);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(),
            
            // MAIN SALES TABLE
            pw.Text('All Sales Transactions:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: mainHeaders,
              data: mainData,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
            ),
            
            pw.SizedBox(height: 24),
            
            // PRODUCT WISE SUMMARY TABLE
            pw.Text('Product-Wise Sales Summary:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: summaryHeaders,
              data: summaryData,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
            ),
            
            pw.SizedBox(height: 32),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Report Generated On: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Generated By: $dairyName', style: const pw.TextStyle(fontSize: 9)),
              ]
            )
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Sales_Report.pdf',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(salesReportProvider);
    final notifier = ref.watch(salesReportProvider.notifier);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(start: notifier.startDate, end: notifier.endDate),
                    );
                    if (picked != null) {
                      notifier.setDateRange(picked.start, picked.end);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.blue),
                        const SizedBox(width: 12),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(notifier.startDate)}  →  ${DateFormat('dd/MM/yyyy').format(notifier.endDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('GENERATE PDF / PRINT'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                  onPressed: () {
                    if (reportAsync.hasValue) {
                      _generatePdf(context, reportAsync.value!, notifier.startDate, notifier.endDate, settingsAsync.value);
                    }
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (data) {
                if (data.entries.isEmpty) return const Center(child: Text('No sales found for this date range.'));

                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Product-Wise Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text('GRAND TOTAL: ₹${data.grandTotalAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Card(
                          elevation: 2,
                          child: ListView.separated(
                            itemCount: data.productSummaries.length,
                            separatorBuilder: (c, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final summary = data.productSummaries[index];
                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.shopping_bag)),
                                title: Text(summary.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Total Qty Sold: ${summary.totalQuantity.toStringAsFixed(2)}'),
                                trailing: Text('₹${summary.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            ),
          )
        ],
      ),
    );
  }
}
