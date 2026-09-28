import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/flutter_models.dart';
import '../providers/settings_provider.dart';

class BonusPdfService {
  static Future<void> printReceipt({
    required BonusTransaction txn,
    AppSettingsModel? settings,
  }) async {
    final pdf = pw.Document();

    final dairyName = settings?.dairyName ?? 'Shree Krishna Dairy';
    final dairyAddress = settings?.address ?? 'At Post, Tal - Khed, Dist - Pune';
    final dairyMobile = settings?.mobile ?? '+91 9876543210';
    final tagline = 'Fresh Milk - Healthy Life';

    pw.MemoryImage? logoImg;
    if (settings?.logoBytes != null) {
      try {
        logoImg = pw.MemoryImage(settings!.logoBytes!);
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey200, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              color: PdfColors.white,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. Header
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Dairy Logo & Name
                    pw.Row(
                      children: [
                        if (logoImg != null)
                          pw.Container(
                            width: 50,
                            height: 50,
                            margin: const pw.EdgeInsets.only(right: 12),
                            child: pw.ClipOval(child: pw.Image(logoImg, fit: pw.BoxFit.cover)),
                          )
                        else
                          pw.Container(
                            width: 50,
                            height: 50,
                            margin: const pw.EdgeInsets.only(right: 12),
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.blue800,
                              shape: pw.BoxShape.circle,
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                '🥛',
                                style: const pw.TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              dairyName,
                              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              tagline,
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600, fontStyle: pw.FontStyle.italic),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Main Dairy & Contact info
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Main Dairy Management System',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                        ),
                        pw.Text(
                          'Local Dairy',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Address : $dairyAddress',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
                        ),
                        pw.Text(
                          'Mobile : $dairyMobile',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1, color: PdfColors.blueGrey100),
                pw.SizedBox(height: 12),

                // 2. Farmer Details & Bonus Period Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey200),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Farmer Details
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Farmer Details',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            txn.farmerName,
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                          ),
                          if (txn.farmerNo != null && txn.farmerNo!.isNotEmpty)
                            pw.Text(
                              'ID : ${txn.farmerNo}',
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                            ),
                          pw.Text(
                            'Animal Type : ${txn.animalType}',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey800),
                          ),
                        ],
                      ),
                      // Bonus Period
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Bonus Period',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Row(
                            children: [
                              pw.Text('From : ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                              pw.Text(
                                _formatDate(txn.fromDate),
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 2),
                          pw.Row(
                            children: [
                              pw.Text('To     : ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                              pw.Text(
                                _formatDate(txn.toDate),
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // 3. Two Columns: Milk & Bonus Details vs Payment Details
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left Column: Milk & Bonus Details
                    pw.Expanded(
                      flex: 5,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.blue100),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          color: PdfColors.white,
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Milk & Bonus Details',
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                            ),
                            pw.SizedBox(height: 8),
                            _buildInfoRow('Total Milk Collection', '${txn.milkQuantity.toStringAsFixed(2)} L'),
                            _buildInfoRow('Bonus Rate', '₹ ${txn.bonusRate.toStringAsFixed(2)} / L'),
                            _buildInfoRow('Total Bonus Amount', '₹ ${txn.totalBonus.toStringAsFixed(2)}'),
                            _buildInfoRow('Previously Paid', '₹ ${txn.previousPaid.toStringAsFixed(2)}'),
                            _buildInfoRow('Current Paid Amount', '₹ ${txn.paidAmount.toStringAsFixed(2)}', isBold: true, color: PdfColors.green800),
                            _buildInfoRow('Remaining Bonus', '₹ ${txn.remainingBonus.toStringAsFixed(2)}', isBold: true, color: txn.remainingBonus > 0 ? PdfColors.orange800 : PdfColors.grey700),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    // Right Column: Payment Details
                    pw.Expanded(
                      flex: 5,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.purple100),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          color: PdfColors.white,
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Payment Details',
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900),
                            ),
                            pw.SizedBox(height: 8),
                            _buildInfoRow('Payment Date', _formatDate(txn.paymentDate)),
                            _buildInfoRow('Payment Mode', txn.paymentMode),
                            _buildInfoRow('Transaction No', txn.transactionNumber ?? 'N/A'),
                            _buildInfoRow('Remarks', txn.remarks ?? 'Bonus Payment'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 18),

                // 4. Summary Box at Bottom Right
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 220,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        border: pw.Border.all(color: PdfColors.blue300, width: 1.2),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        children: [
                          _buildSummaryRow('Total Bonus', '₹ ${txn.totalBonus.toStringAsFixed(2)}', false),
                          pw.SizedBox(height: 4),
                          _buildSummaryRow('Paid Amount', '₹ ${txn.paidAmount.toStringAsFixed(2)}', false, color: PdfColors.green800),
                          pw.SizedBox(height: 4),
                          pw.Divider(thickness: 0.8, color: PdfColors.blue200),
                          pw.SizedBox(height: 4),
                          _buildSummaryRow('Remaining', '₹ ${txn.remainingBonus.toStringAsFixed(2)}', true, color: txn.remainingBonus > 0 ? PdfColors.orange900 : PdfColors.blueGrey800),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // 5. Decorative Footer
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFE8F5E9),
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Thank you for being a valuable part of our dairy family!',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green900,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Bonus_Receipt_${txn.farmerName}_${txn.paymentDate}.pdf',
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, bool isTotal, {PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isTotal ? 11 : 10,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.grey800,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isTotal ? 12 : 10,
            fontWeight: pw.FontWeight.bold,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }

  static String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('dd-MM-yyyy').format(dt);
    } catch (_) {
      return isoDate;
    }
  }
}
