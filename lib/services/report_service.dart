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
              headers: const ['Total', 'Approved', 'Pending', 'Rejected'],
              data: [
                [
                  summary.totalApplications,
                  summary.approved,
                  summary.pending,
                  summary.rejected,
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
  final SupabaseClient _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  @override
  Future<ReportSummary> studentSummary() async {
    final internships = await _db
        .from('internships')
        .select('id, status')
        .eq('student_id', _uid);
    final docs = await _db
        .from('documents')
        .select('id')
        .eq('student_id', _uid);
    final progress = await _db
        .from('progress_logs')
        .select('progress')
        .eq('student_id', _uid)
        .order('created_at', ascending: false)
        .limit(1);

    int count(String status) =>
        internships.where((item) => item['status'] == status).length;

    return ReportSummary(
      totalApplications: internships.length,
      approved: count('approved'),
      pending: count('pending'),
      rejected: count('rejected'),
      documentsUploaded: docs.length,
      latestProgress: progress.isEmpty
          ? 0
          : (progress.first['progress'] as int),
    );
  }
}
