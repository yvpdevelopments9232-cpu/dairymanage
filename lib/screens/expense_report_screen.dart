import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/expense_report_provider.dart';
import '../providers/settings_provider.dart';
import '../services/translations.dart';
import '../providers/language_provider.dart';
import '../providers/display_mode_provider.dart';

class ExpenseReportScreen extends ConsumerStatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  ConsumerState<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends ConsumerState<ExpenseReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      ref.read(expenseReportProvider.notifier).setDateRange(
        DateFormat('yyyy-MM-dd').format(range.start),
        DateFormat('yyyy-MM-dd').format(range.end),
      );
    }
  }

  Future<void> _printPdf(ExpenseReportState report) async {
    if (_startDate == null || _endDate == null) return;
    
    final settingsAsync = ref.read(settingsProvider);
    final dairyName = settingsAsync.value?.dairyName ?? 'Shree Ganesh Dairy';
    final ownerName = settingsAsync.value?.ownerName ?? 'Owner Name';
    final phone = settingsAsync.value?.mobile ?? '1234567890';
    final address = settingsAsync.value?.address ?? 'Dairy Address';
    
    pw.MemoryImage? logoImage;
    if (settingsAsync.value?.logoBytes != null) {
      logoImage = pw.MemoryImage(settingsAsync.value!.logoBytes!);
    }

    final pdf = pw.Document();
    final dateStr = '${DateFormat('dd-MMM-yyyy').format(_startDate!)} to ${DateFormat('dd-MMM-yyyy').format(_endDate!)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
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
                      pw.Text('Profit & Loss Statement (Expense Report)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                      pw.Text('Date Range: $dateStr', style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(height: 8),
                    ],
                  ),
                ),
                pw.SizedBox(width: 60),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 16),
            pw.Text('Financial Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerRight,
              data: [
                ['Description', 'Amount (Rs)'],
                ['Total Sales Revenue', report.totalRevenue.toStringAsFixed(2)],
                ['Profit on Product Sales', report.productProfit.toStringAsFixed(2)],
                ['Milk Sale Cost (Main Dairy Sales)', report.milkSaleCost.toStringAsFixed(2)],
                ['Total Milk Purchase Cost', report.milkCost.toStringAsFixed(2)],
                ['Profit on Milk (Sale Cost - Purchase Cost)', report.milkProfit.toStringAsFixed(2)],
                ['Total Stock Purchase Cost', report.purchaseCost.toStringAsFixed(2)],
                ['Total Operational Expenses', report.expenseCost.toStringAsFixed(2)],
                ['NET PROFIT', report.netProfit.toStringAsFixed(2)],
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Text('Operational Expenses Breakdown', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (report.expenses.isEmpty)
              pw.Text('No expenses recorded in this period.', style: const pw.TextStyle(fontSize: 12))
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headers: ['Date', 'Category', 'Payment Mode', 'Remarks', 'Amount', 'Sign'],
                data: report.expenses.map((e) => [
                  DateFormat('dd-MMM-yyyy').format(DateTime.parse(e.expenseDate)),
                  e.category,
                  e.paymentMode,
                  e.description ?? e.remarks ?? '-',
                  e.amount.toStringAsFixed(2),
                  '', // Empty for sign
                ]).toList(),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Widget _buildSummaryCard(String title, double amount, Color color, bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : 200,
      margin: const EdgeInsets.only(bottom: 16, right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text('₹ ${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final displayMode = ref.watch(displayModeProvider);
    final isMobile = displayMode == DisplayMode.mobile;
    final reportAsync = ref.watch(expenseReportProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profit & Expense Report'.tr, style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Header / Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _startDate == null ? 'Select Date Range'.tr : '${DateFormat('dd-MMM-yyyy').format(_startDate!)} to ${DateFormat('dd-MMM-yyyy').format(_endDate!)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickDateRange,
                              icon: const Icon(Icons.date_range),
                              label: Text('FILTER'.tr),
                            ),
                          ),
                          if (reportAsync.hasValue) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _printPdf(reportAsync.value!),
                                icon: const Icon(Icons.print),
                                label: Text('PRINT'.tr),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          _startDate == null ? 'Select Date Range'.tr : '${DateFormat('dd-MMM-yyyy').format(_startDate!)} to ${DateFormat('dd-MMM-yyyy').format(_endDate!)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range),
                        label: Text('FILTER'.tr),
                      ),
                      const SizedBox(width: 8),
                      if (reportAsync.hasValue)
                        ElevatedButton.icon(
                          onPressed: () => _printPdf(reportAsync.value!),
                          icon: const Icon(Icons.print),
                          label: Text('PRINT'.tr),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        ),
                    ],
                  ),
          ),
          
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('${'Error'.tr}: $e')),
              data: (report) {
                if (_startDate == null) {
                  return Center(child: Text('Please select a date range to generate the report.'.tr));
                }

                return SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Financial Overview'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 16),
                      Wrap(
                        children: [
                          _buildSummaryCard('Total Sales (Revenue)'.tr, report.totalRevenue, Colors.green, isMobile),
                          _buildSummaryCard('Profit on Sales'.tr, report.productProfit, Colors.teal, isMobile),
                          _buildSummaryCard('Milk Sale Cost'.tr, report.milkSaleCost, Colors.blue.shade700, isMobile),
                          _buildSummaryCard('Milk Purchase Cost'.tr, report.milkCost, Colors.purple, isMobile),
                          _buildSummaryCard('Profit on Milk'.tr, report.milkProfit, report.milkProfit >= 0 ? Colors.green.shade700 : Colors.red, isMobile),
                          _buildSummaryCard('Stock Purchase Cost'.tr, report.purchaseCost, Colors.indigo, isMobile),
                          _buildSummaryCard('Operational Expenses'.tr, report.expenseCost, Colors.orange, isMobile),
                          _buildSummaryCard('NET PROFIT'.tr, report.netProfit, report.netProfit >= 0 ? Colors.blue.shade900 : Colors.red.shade900, isMobile),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Detailed Expenses'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 16),
                      if (report.expenses.isEmpty)
                        Text('No expenses recorded in this date range.'.tr)
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                            columns: [
                              DataColumn(label: Text('Date'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Category'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Description'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Pay Mode'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Amount (₹)'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: report.expenses.map((e) => DataRow(cells: [
                              DataCell(Text(DateFormat('dd-MMM-yyyy').format(DateTime.parse(e.expenseDate)))),
                              DataCell(Text(e.category)),
                              DataCell(Text(e.description ?? e.remarks ?? '-')),
                              DataCell(Text(e.paymentMode)),
                              DataCell(Text(e.amount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                            ])).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
