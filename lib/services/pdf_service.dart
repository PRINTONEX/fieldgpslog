import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/gps_log.dart';

class PdfService {
  Future<void> generateAndPrintReport(GpsLog log, String vehicleName) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Driving Log Report',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Vehicle: $vehicleName'),
                    pw.Text('Date: ${dateFormat.format(log.startTime)}'),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Column(
                    children: [
                      _row('Total Distance:',
                          '${log.totalDistance.toStringAsFixed(2)} km'),
                      _row('Rate Applied:', 'RS ${log.rateApplied}/km'),
                      pw.Divider(),
                      _row('Total Fare:',
                          'RS ${log.totalFare.toStringAsFixed(2)}',
                          isBold: true),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Stay Points (Stops)',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  headers: ['Arrival', 'Departure', 'Duration'],
                  data: log.stays
                      .map((stay) => [
                            dateFormat.format(stay.arrivalTime!),
                            dateFormat.format(stay.departureTime!),
                            '${stay.durationMinutes} mins',
                          ])
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _row(String label, String value, {bool isBold = false}) {
    final style = pw.TextStyle(
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
