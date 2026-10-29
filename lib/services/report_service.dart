import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_models.dart';

abstract interface class ReportDataSource {
  Future<ReportSummary> studentSummary();
}

abstract interface class ReportPdfExporter {
  Future<void> export(ReportSummary summary);
}

class PrintingReportPdfExporter implements ReportPdfExporter {
  @override
  Future<void> export(ReportSummary summary) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Prashikshan - Internship Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated '
              '${DateTime.now().toLocal().toString().split('.').first}',
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Application summary',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Total',
                'Approved',
                'Pending',
                'Rejected',
                'Completed',
              ],
              data: [
                [
                  summary.totalApplications,
                  summary.approved,
                  summary.pending,
                  summary.rejected,
                  summary.completed,
                ].map((value) => '$value').toList(),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Internship progress',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Latest progress: ${summary.latestProgress}%'),
            pw.Text('${summary.documentsUploaded} document(s) uploaded'),
          ],
        ),
      ),
    );
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'prashikshan_report.pdf',
    );
  }
}

/// Builds the student's report summary from existing student tables.
class ReportService implements ReportDataSource {
  ReportService({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  @override
  Future<ReportSummary> studentSummary() async {
    final response = await _db.rpc('get_student_analytics');
    if (response is! Map) {
      throw const FormatException('Student analytics response is invalid.');
    }
    return ReportSummary.fromMap(Map<String, dynamic>.from(response));
  }
}
