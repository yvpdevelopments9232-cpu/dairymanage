import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/flutter_models.dart';
import '../providers/farmer_provider.dart';
import '../providers/farmer_report_provider.dart';
import '../providers/settings_provider.dart';
import '../services/translations.dart';
import '../providers/language_provider.dart';

class FarmerReportScreen extends ConsumerWidget {
  const FarmerReportScreen({super.key});

  pw.Document _buildPdfDoc(List<FarmerReportData> dataList, DateTime start, DateTime end, dynamic settings) {
    final pdf = pw.Document();

    final dairyName = settings?.dairyName ?? 'Shree Ganesh Dairy';
    final ownerName = settings?.ownerName ?? 'Owner Name';
    final phone = settings?.mobile ?? '1234567890';
    final address = settings?.address ?? 'Dairy Address';

    final dateStr = '${DateFormat('dd/MM/yyyy').format(start)} to ${DateFormat('dd/MM/yyyy').format(end)}';

    for (var data in dataList) {
    
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

            pw.Text(dairyName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 4),
            pw.Text('Owner: $ownerName | Phone: $phone'),
            pw.Text('Address: $address'),
            pw.SizedBox(height: 8),
            pw.Text('Period: $dateStr'),
            pw.SizedBox(height: 16),
          
            ],
          ),
        ),
        pw.SizedBox(width: 60),
      ],
    );
    }

    pw.Widget _buildFarmerDetails() {
      return pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
        child: pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              color: PdfColors.blue900,
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('FARMER DETAILS', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Row(
              children: [
                pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(4), color: PdfColors.blue900, child: pw.Text('Farmer Name', style: pw.TextStyle(color: PdfColors.white)))),
                pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('${data.farmer.name} (#${data.farmer.farmerNo})'))),
                pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(4), color: PdfColors.blue900, child: pw.Text('Animal Type', style: pw.TextStyle(color: PdfColors.white)))),
                pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(data.animalType))),
                pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(4), color: PdfColors.blue900, child: pw.Text('Mobile Number', style: pw.TextStyle(color: PdfColors.white)))),
                pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(data.farmer.mobile ?? '-'))),
              ]
            )
          ]
        )
      );
    }

    pw.Widget _buildMilkTables() {
      final headers = [
        'Date',
        'Liter\n(Ltr.)', 'Fat\n(%)', 'SNF\n(%)', 'Rate\n(Rs/Ltr)', 'Total\nAmount (Rs)',
        'Liter\n(Ltr.)', 'Fat\n(%)', 'SNF\n(%)', 'Rate\n(Rs/Ltr)', 'Total\nAmount (Rs)'
      ];
      
      List<List<String>> tableData = data.dailyEntries.map((e) => [
        e.date,
        e.morning.liter > 0 ? e.morning.liter.toStringAsFixed(2) : '0.00',
        e.morning.fat > 0 ? e.morning.fat.toStringAsFixed(1) : '-',
        e.morning.snf > 0 ? e.morning.snf.toStringAsFixed(1) : '-',
        e.morning.rate > 0 ? e.morning.rate.toStringAsFixed(2) : '-',
        e.morning.totalAmount > 0 ? e.morning.totalAmount.toStringAsFixed(2) : '0.00',
        e.evening.liter > 0 ? e.evening.liter.toStringAsFixed(2) : '0.00',
        e.evening.fat > 0 ? e.evening.fat.toStringAsFixed(1) : '-',
        e.evening.snf > 0 ? e.evening.snf.toStringAsFixed(1) : '-',
        e.evening.rate > 0 ? e.evening.rate.toStringAsFixed(2) : '-',
        e.evening.totalAmount > 0 ? e.evening.totalAmount.toStringAsFixed(2) : '0.00',
      ]).toList();

      tableData.add([
        'TOTAL', 
        data.morningLiter.toStringAsFixed(2), '-', '-', '-', data.morningAmount.toStringAsFixed(2),
        data.eveningLiter.toStringAsFixed(2), '-', '-', '-', data.eveningAmount.toStringAsFixed(2)
      ]);

      return pw.Column(
        children: [
          pw.Row(
            children: [
              pw.Expanded(flex: 12, child: pw.SizedBox()),
              pw.Expanded(flex: 48, child: pw.Text('MORNING', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800))),
              pw.Expanded(flex: 48, child: pw.Text('EVENING', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800))),
            ]
          ),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: tableData,
            columnWidths: const {
              0: pw.FlexColumnWidth(12),
              1: pw.FlexColumnWidth(10), 2: pw.FlexColumnWidth(8), 3: pw.FlexColumnWidth(8), 4: pw.FlexColumnWidth(10), 5: pw.FlexColumnWidth(12),
              6: pw.FlexColumnWidth(10), 7: pw.FlexColumnWidth(8), 8: pw.FlexColumnWidth(8), 9: pw.FlexColumnWidth(10), 10: pw.FlexColumnWidth(12),
            },
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
            border: pw.TableBorder.all(color: PdfColors.grey),
          )
        ]
      );
    }
    
    pw.Widget _buildProductTable() {
      if (data.products.isEmpty) return pw.SizedBox();

      final headers = ['Date', 'Item Details', 'Rate', 'Quantity', 'Amount'];
      List<List<String>> rows = data.products.map((p) => [
        p.date,
        p.productName,
        'Rs ${p.price.toStringAsFixed(2)}',
        p.quantity.toStringAsFixed(2),
        'Rs ${p.total.toStringAsFixed(2)}',
      ]).toList();

      rows.add(['TOTAL', '', '', '', 'Rs ${data.totalProductAmount.toStringAsFixed(2)}']);

      return pw.Column(
        children: [
          pw.Center(child: pw.Text('PRODUCT PURCHASE DETAILS', style: pw.TextStyle(color: PdfColors.blue900, fontWeight: pw.FontWeight.bold, fontSize: 14))),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            columnWidths: const {
              0: pw.FlexColumnWidth(15),
              1: pw.FlexColumnWidth(40),
              2: pw.FlexColumnWidth(15),
              3: pw.FlexColumnWidth(15),
              4: pw.FlexColumnWidth(15),
            },
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellAlignment: pw.Alignment.center,
            border: pw.TableBorder.all(color: PdfColors.grey),
          )
        ]
      );
    }

    final totalMilkAmount = data.morningAmount + data.eveningAmount;
    final totalLiter = data.morningLiter + data.eveningLiter;
    final remainingAmount = totalMilkAmount - data.totalProductAmount;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            _buildHeader(),
            _buildFarmerDetails(),
            pw.SizedBox(height: 16),
            _buildMilkTables(),
            pw.SizedBox(height: 16),
            pw.Row(
              children: [
                pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)), child: pw.Column(children: [pw.Text('TOTAL LITER (Morning + Evening)'), pw.Text('${totalLiter.toStringAsFixed(2)} Ltr.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))]))),
                pw.SizedBox(width: 8),
                pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)), child: pw.Column(children: [pw.Text('TOTAL AMOUNT (Morning + Evening)'), pw.Text('Rs ${totalMilkAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))]))),
              ]
            ),
            pw.SizedBox(height: 16),
            _buildProductTable(),
            pw.SizedBox(height: 16),
            if (data.payments.isNotEmpty) ...[
              pw.Center(child: pw.Text('PAYMENTS / ADVANCES ISSUED', style: pw.TextStyle(color: PdfColors.blue900, fontWeight: pw.FontWeight.bold, fontSize: 14))),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headers: ['Date', 'Mode', 'Remarks', 'Amount'],
                data: data.payments.map((p) => [
                  DateFormat('dd/MM/yyyy').format(DateTime.parse(p.paymentDate)),
                  p.paymentMode,
                  p.remarks ?? '-',
                  'Rs ${p.amount.toStringAsFixed(2)}',
                ]).toList(),
              ),
              pw.SizedBox(height: 16),
            ],
            pw.Container(
              decoration: pw.BoxDecoration(color: PdfColors.amber50, border: pw.Border.all(color: PdfColors.grey)),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                children: [
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Amount ( Milk Collection )'), pw.Text('Rs ${totalMilkAmount.toStringAsFixed(2)}')]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Product Purchase Amount'), pw.Text('Rs ${data.totalProductAmount.toStringAsFixed(2)}')]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Payments / Advances Given'), pw.Text('Rs ${data.totalPaymentsAmount.toStringAsFixed(2)}')]),
                  pw.Divider(),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL REMAINING AMOUNT', style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold, fontSize: 14)), pw.Text('Rs ${(remainingAmount - data.totalPaymentsAmount).toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold, fontSize: 14))]),
                ]
              )
            ),
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Report Generated On: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.blue900)),
                pw.Text('Generated By: $dairyName System', style: const pw.TextStyle(fontSize: 8)),
              ]
            )
          ];
        },
      ),
    );

    }

    return pdf;
  }

  Future<void> _generatePdf(BuildContext context, List<FarmerReportData> dataList, DateTime start, DateTime end, dynamic settings) async {
    final pdf = _buildPdfDoc(dataList, start, end, settings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: dataList.length == 1 ? 'Farmer_Report_${dataList.first.farmer.farmerNo}.pdf' : 'All_Farmers_Report.pdf',
    );
  }

  void _viewPdf(BuildContext context, List<FarmerReportData> dataList, DateTime start, DateTime end, dynamic settings) {
    final title = dataList.length == 1
        ? '${dataList.first.farmer.name} (#${dataList.first.farmer.farmerNo}) - Report'
        : 'All Farmers Report Preview';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.blue.shade900,
            foregroundColor: Colors.white,
          ),
          body: PdfPreview(
            build: (format) async {
              final pdf = _buildPdfDoc(dataList, start, end, settings);
              return pdf.save();
            },
            canChangeOrientation: false,
            canChangePageFormat: false,
            maxPageWidth: 720,
            pdfFileName: dataList.length == 1
                ? 'Farmer_Report_${dataList.first.farmer.farmerNo}.pdf'
                : 'All_Farmers_Report.pdf',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final reportAsync = ref.watch(farmerReportProvider);
    final notifier = ref.watch(farmerReportProvider.notifier);
    final settingsAsync = ref.watch(settingsProvider);
    final farmersAsync = ref.watch(farmersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Farmer Details Report'.tr, style: const TextStyle(color: Colors.black87)),
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
              children: [
                Expanded(
                  flex: 2,
                  child: farmersAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('${'Error'.tr}: $e'),
                    data: (farmers) => Autocomplete<Farmer>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<Farmer>.empty();
                        return farmers.where((f) => 
                          f.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
                          f.farmerNo.toString() == textEditingValue.text
                        );
                      },
                      displayStringForOption: (Farmer option) => '#${option.farmerNo} - ${option.name}',
                      onSelected: (Farmer selection) => notifier.setFarmer(selection),
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        // Pre-fill if already selected
                        if (notifier.selectedFarmer != null && controller.text.isEmpty) {
                          controller.text = '#${notifier.selectedFarmer!.farmerNo} - ${notifier.selectedFarmer!.name}';
                        }
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Search Farmer by Name/No'.tr, 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), 
                            prefixIcon: const Icon(Icons.search),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: InkWell(
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${DateFormat('dd/MM/yy').format(notifier.startDate)} → ${DateFormat('dd/MM/yy').format(notifier.endDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: Text('VIEW'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  ),
                  onPressed: () {
                    if (reportAsync.hasValue && reportAsync.value != null) {
                      _viewPdf(context, [reportAsync.value!], notifier.startDate, notifier.endDate, settingsAsync.value);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a farmer first.'.tr)));
                    }
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: Text('GENERATE PDF'.tr),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                  onPressed: () {
                    if (reportAsync.hasValue && reportAsync.value != null) {
                      _generatePdf(context, [reportAsync.value!], notifier.startDate, notifier.endDate, settingsAsync.value);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a farmer first.'.tr)));
                    }
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text('GENERATE ALL PDF'.tr),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
                  onPressed: () async {
                    if (farmersAsync.hasValue) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        final allReports = await ref.read(farmerReportProvider.notifier).fetchAllReports(farmersAsync.value!);
                        if (context.mounted) Navigator.pop(context); // Close dialog
                        
                        if (allReports.isEmpty) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No activity found for any farmer in this period.')));
                          return;
                        }
                        if (context.mounted) {
                          _generatePdf(context, allReports, notifier.startDate, notifier.endDate, settingsAsync.value);
                        }
                      } catch (e) {
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating bulk report: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('${'Error'.tr}: $e')),
              data: (data) {
                if (data == null) return Center(child: Text('Search and select a farmer to view the report.'.tr));
                
                final totalMilkAmount = data.morningAmount + data.eveningAmount;
                final totalLiter = data.morningLiter + data.eveningLiter;
                final remainingAmount = totalMilkAmount - data.totalProductAmount;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('${'Farmer Details'.tr}: ${data.farmer.name} (#${data.farmer.farmerNo})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const Divider(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _statBox('Total Liter'.tr, '${totalLiter.toStringAsFixed(2)} ${'Ltr'.tr}'),
                              _statBox('Total Milk Amount'.tr, '₹${totalMilkAmount.toStringAsFixed(2)}'),
                              _statBox('Total Product Purchase'.tr, '₹${data.totalProductAmount.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.red.shade50,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${'TOTAL REMAINING PAYABLE AMOUNT'.tr}: ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('₹${remainingAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('Detailed breakdown is beautifully formatted in the PDF Export.'.tr, style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.visibility, size: 20),
                            label: Text('VIEW REPORT (PDF PREVIEW)'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              _viewPdf(context, [data], notifier.startDate, notifier.endDate, settingsAsync.value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            ),
          )
        ],
      ),
    );
  }

  Widget _statBox(String title, String val) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
