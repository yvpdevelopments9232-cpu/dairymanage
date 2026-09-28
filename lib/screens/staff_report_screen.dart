import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/staff_report_provider.dart';
import '../providers/staff_provider.dart';
import '../providers/settings_provider.dart';

class StaffReportScreen extends ConsumerStatefulWidget {
  const StaffReportScreen({super.key});

  @override
  ConsumerState<StaffReportScreen> createState() => _StaffReportScreenState();
}

class _StaffReportScreenState extends ConsumerState<StaffReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStaffId;

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
      _applyFilter();
    }
  }

  void _applyFilter() {
    if (_startDate != null && _endDate != null && _selectedStaffId != null) {
      ref.read(staffReportProvider.notifier).setFilter(
        _selectedStaffId!,
        DateFormat('yyyy-MM-dd').format(_startDate!),
        DateFormat('yyyy-MM-dd').format(_endDate!),
      );
    }
  }

  Future<void> _printPdf(StaffReportState report) async {
    if (_startDate == null || _endDate == null || report.staff == null) return;
    
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
                      pw.Text('Owner: ${ownerName} | Phone: ${phone}'),
                      pw.Text('Address: ${address}'),
                      pw.SizedBox(height: 12),
                      pw.Text('Staff Salary & Attendance Report', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                      pw.SizedBox(height: 8),
                      pw.Text('Staff Name: ${report.staff!.name}  |  Role: ${report.staff!.role ?? 'N/A'}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date Range: $dateStr', style: const pw.TextStyle(fontSize: 12)),
                    ]
                  ),
                ),
                pw.SizedBox(width: 60),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text('Attendance History', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (report.attendanceList.isEmpty)
              pw.Text('No attendance records found.')
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headers: ['Date', 'Status'],
                data: report.attendanceList.map((a) => [
                  DateFormat('dd-MMM-yyyy').format(DateTime.parse(a.attendanceDate)),
                  a.status,
                ]).toList(),
              ),
            pw.SizedBox(height: 20),
            pw.Text('Advances History', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (report.advanceList.isEmpty)
              pw.Text('No advances taken in this period.')
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headers: ['Date', 'Remarks', 'Amount (Rs)'],
                data: report.advanceList.map((a) => [
                  DateFormat('dd-MMM-yyyy').format(DateTime.parse(a.transactionDate)),
                  a.remarks ?? '-',
                  a.amount.toStringAsFixed(2),
                ]).toList(),
              ),
            pw.SizedBox(height: 20),
            pw.Text('Salary Calculation', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerRight,
              data: [
                ['Description', 'Value'],
                ['Total Present Days', report.totalPresentDays.toString()],
                ['Base Wage (${report.staff!.salaryType})', report.staff!.salaryAmount.toStringAsFixed(2)],
                ['Calculated Gross Salary', 'Rs. ${report.calculatedSalary.toStringAsFixed(2)}'],
                ['Total Advances Taken', '(-) Rs. ${report.totalAdvances.toStringAsFixed(2)}'],
                ['NET PAYABLE', 'Rs. ${report.netPayable.toStringAsFixed(2)}'],
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      width: 200,
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
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffListAsync = ref.watch(staffProvider);
    final reportAsync = ref.watch(staffReportProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Salary Report', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: staffListAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('Error: $e'),
                    data: (staffs) => DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Select Staff', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      value: _selectedStaffId,
                      items: staffs.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (val) {
                        setState(() => _selectedStaffId = val);
                        _applyFilter();
                      },
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(_startDate == null ? 'Select Dates' : '${DateFormat('dd-MMM-yyyy').format(_startDate!)} to ${DateFormat('dd-MMM-yyyy').format(_endDate!)}'),
                ),
                if (reportAsync.hasValue && reportAsync.value!.staff != null)
                  ElevatedButton.icon(
                    onPressed: () => _printPdf(reportAsync.value!),
                    icon: const Icon(Icons.print),
                    label: const Text('PRINT REPORT'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
              data: (report) {
                if (report.staff == null) return const Center(child: Text('Select staff and date range to generate report.'));

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Salary Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 16),
                      Wrap(
                        children: [
                          _buildSummaryCard('Present Days', report.totalPresentDays.toString(), Colors.blue),
                          _buildSummaryCard('Gross Salary', '₹ ${report.calculatedSalary.toStringAsFixed(2)}', Colors.green),
                          _buildSummaryCard('Advances Taken', '₹ ${report.totalAdvances.toStringAsFixed(2)}', Colors.orange),
                          _buildSummaryCard('Net Payable', '₹ ${report.netPayable.toStringAsFixed(2)}', report.netPayable >= 0 ? Colors.teal : Colors.red),
                        ],
                      ),
                      // Just rendering the UI summary
                      const SizedBox(height: 24),
                      Text('Recent Advances', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                      if (report.advanceList.isEmpty) const Text('No advances.') else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: report.advanceList.length,
                        itemBuilder: (ctx, i) {
                          final a = report.advanceList[i];
                          return ListTile(
                            title: Text('Advance - ${a.remarks ?? ''}'),
                            subtitle: Text(DateFormat('dd-MMM-yyyy').format(DateTime.parse(a.transactionDate))),
                            trailing: Text('₹${a.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                          );
                        },
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
