import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoicePdfService {
  static Future<void> generateAndPrintInvoice({
    required String dairyName,
    required String customerEmail,
    required String planName,
    required double amount,
    required String transactionId,
    required String subscriptionId,
    required DateTime paymentDate,
    required DateTime startDate,
    required DateTime endDate,
    required String paymentMethod,
    String? invoiceNo,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final dateOnlyFormat = DateFormat('dd MMM yyyy');

    final effectiveInvoiceNo = invoiceNo ?? 'INV-${DateFormat('yyyyMMdd').format(paymentDate)}-${transactionId.substring(transactionId.length > 4 ? transactionId.length - 4 : 0)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey200, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              color: PdfColors.white,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. Header Banner
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DAIRY MANAGEMENT',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.Text(
                          'Smart Dairy, Better Tomorrow',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Official Software License & Subscription Receipt',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal800,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        border: pw.Border.all(color: PdfColors.green400, width: 1.5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'PAYMENT STATUS',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                          ),
                          pw.Text(
                            'PAID / ACTIVE',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 12),

                // 2. Invoice Meta Details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILLED TO:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(dairyName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.Text(customerEmail, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE NO: $effectiveInvoiceNo', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.SizedBox(height: 3),
                        pw.Text('DATE: ${dateFormat.format(paymentDate)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('TXN ID: $transactionId', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // 3. Subscription License Summary Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('SUBSCRIPTION ID', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text(subscriptionId, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('VALIDITY PERIOD', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text('${dateOnlyFormat.format(startDate)}  TO  ${dateOnlyFormat.format(endDate)}',
                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('DURATION', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text('365 Days (1 Year)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 24),

                // 4. Line Items Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(4),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                      children: [
                        _buildTableHeader('#'),
                        _buildTableHeader('Description & Plan Details'),
                        _buildTableHeader('Payment Method'),
                        _buildTableHeader('Total (INR)'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('1', align: pw.TextAlign.center),
                        _buildTableCell(
                          '$planName - 1 Year Software License\nIncludes complete access to modules, cloud sync, automated backups & mobile/desktop apps.',
                        ),
                        _buildTableCell(paymentMethod, align: pw.TextAlign.center),
                        _buildTableCell('INR ${amount.toStringAsFixed(2)}', align: pw.TextAlign.right, bold: true),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),

                // 5. Total Calculations
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 200,
                      child: pw.Column(
                        children: [
                          _buildPriceRow('Subtotal:', 'INR ${amount.toStringAsFixed(2)}'),
                          _buildPriceRow('Taxes & GST (0%):', 'INR 0.00'),
                          pw.Divider(thickness: 1, color: PdfColors.grey400),
                          _buildPriceRow('Grand Total:', 'INR ${amount.toStringAsFixed(2)}', isGrandTotal: true),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // 6. Footer Notes
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('1. This receipt is computer-generated and confirms your software license activation.', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                      pw.Text('2. Subscription entitles the subscriber to all features of the selected plan for 365 days from activation date.', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                      pw.Text('3. For technical support and renewals, contact your Dairy Management technical support team.', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text('Thank you for choosing Dairy Management System!', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'DairyManagement_Invoice_$effectiveInvoiceNo.pdf',
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: PdfColors.black),
      ),
    );
  }

  static pw.Widget _buildPriceRow(String label, String value, {bool isGrandTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: isGrandTotal ? 11 : 9, fontWeight: isGrandTotal ? pw.FontWeight.bold : pw.FontWeight.normal, color: isGrandTotal ? PdfColors.blue900 : PdfColors.grey800),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: isGrandTotal ? 11 : 9, fontWeight: isGrandTotal ? pw.FontWeight.bold : pw.FontWeight.normal, color: isGrandTotal ? PdfColors.blue900 : PdfColors.black),
          ),
        ],
      ),
    );
  }
}
