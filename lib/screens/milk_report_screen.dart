import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';

import '../providers/milk_report_provider.dart';
import '../providers/settings_provider.dart';
import '../services/translations.dart';
import '../providers/language_provider.dart';

class MilkReportScreen extends ConsumerWidget {
  const MilkReportScreen({super.key});

  Future<void> _generatePdf(BuildContext context, MilkReportData data, DateTime start, DateTime end, dynamic settings) async {
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
            pw.Text('MILK COLLECTION & ADVANCE REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
            pw.Text('Period: $dateStr'),
            pw.SizedBox(height: 16),
          
            ],
          ),
        ),
        pw.SizedBox(width: 60),
      ],
    );
    }

    // Black and white table headers including Signature
    final headers = [
      'Sr.No', 'Farmer Name', 'Type', 'Total Liter', 
      'Total Amt(Rs)', 'Advance(Rs)', 'Remaining(Rs)', 'Signature'
    ];

    final tableData = data.rows.map((r) => [
      r.srNo.toString(),
      r.farmerName,
      r.animalType,
      r.totalLiter.toStringAsFixed(2),
      r.totalAmount.toStringAsFixed(2),
      r.advanceAndPurchases.toStringAsFixed(2),
      r.remainingAmount.toStringAsFixed(2),
      '' // Empty column for Signature
    ]).toList();

    // Add Total Row
    tableData.add([
      '', 'TOTAL', '',
      data.summary.totalMilkLiters.toStringAsFixed(2),
      data.summary.totalAmount.toStringAsFixed(2),
      data.summary.totalAdvanceAndPurchases.toStringAsFixed(2),
      data.summary.totalRemainingAmount.toStringAsFixed(2),
      ''
    ]);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300), // Greyscale for B&W
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.center, // Signature
              },
            ),
            pw.SizedBox(height: 24),
            // Summaries at bottom
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('MILK SUMMARY (Ltr)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Divider(color: PdfColors.black, thickness: 0.5),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Cow Milk:'), pw.Text(data.summary.cowMilkLiters.toStringAsFixed(2))]),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Buffalo Milk:'), pw.Text(data.summary.buffaloMilkLiters.toStringAsFixed(2))]),
                        pw.Divider(color: PdfColors.black, thickness: 0.5),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Milk:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(data.summary.totalMilkLiters.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                      ],
                    ),
                  )
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('AMOUNT SUMMARY (Rs)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Divider(color: PdfColors.black, thickness: 0.5),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Amount:'), pw.Text(data.summary.totalAmount.toStringAsFixed(2))]),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Advance:'), pw.Text(data.summary.totalAdvanceAndPurchases.toStringAsFixed(2))]),
                        pw.Divider(color: PdfColors.black, thickness: 0.5),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Remaining:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(data.summary.totalRemainingAmount.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                      ],
                    ),
                  )
                )
              ]
            )
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Milk_Collection_Report.pdf',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final reportAsync = ref.watch(milkReportProvider);
    final notifier = ref.watch(milkReportProvider.notifier);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Milk Collection Report'.tr, style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // Header & Date Picker
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
                  label: Text('GENERATE B&W PDF / PRINT'.tr),
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
              error: (e, st) => Center(child: Text('${'Error'.tr}: $e')),
              data: (data) {
                if (data.rows.isEmpty) return Center(child: Text('No data for this date range.'.tr));

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 2,
                    child: Column(
                      children: [
                        // Data Table
                        Expanded(
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(Colors.blue.shade900),
                                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                columns: [
                                  DataColumn(label: Text('Sr.No'.tr)),
                                  DataColumn(label: Text('Farmer Name'.tr)),
                                  DataColumn(label: Text('Animal Type'.tr)),
                                  DataColumn(label: Text('Total Liter (Ltr.)'.tr)),
                                  DataColumn(label: Text('Total Amount (₹)'.tr)),
                                  DataColumn(label: Text('Advance / Purchase (₹)'.tr)),
                                  DataColumn(label: Text('Remaining Amount (₹)'.tr)),
                                ],
                                rows: data.rows.map((r) => DataRow(
                                  cells: [
                                    DataCell(Text(r.srNo.toString())),
                                    DataCell(Text(r.farmerName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: r.animalType == 'Cow' ? Colors.green.shade50 : r.animalType == 'Buffalo' ? Colors.blue.shade50 : Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(4)
                                        ),
                                        child: Text(r.animalType.tr, style: TextStyle(color: r.animalType == 'Cow' ? Colors.green : r.animalType == 'Buffalo' ? Colors.blue : Colors.orange, fontWeight: FontWeight.bold)),
                                      )
                                    ),
                                    DataCell(Text(r.totalLiter.toStringAsFixed(2))),
                                    DataCell(Text(r.totalAmount.toStringAsFixed(2))),
                                    DataCell(Text(r.advanceAndPurchases.toStringAsFixed(2))),
                                    DataCell(Text(r.remainingAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                                  ]
                                )).toList()
                                  ..add(DataRow(
                                    color: MaterialStateProperty.all(Colors.green.shade50),
                                    cells: [
                                      const DataCell(Text('')),
                                      DataCell(Text('TOTAL'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                      const DataCell(Text('')),
                                      DataCell(Text(data.summary.totalMilkLiters.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                      DataCell(Text(data.summary.totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                      DataCell(Text(data.summary.totalAdvanceAndPurchases.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                      DataCell(Text(data.summary.totalRemainingAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                    ]
                                  )),
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
