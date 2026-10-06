import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_models.dart';

abstract interface class ReportDataSource {
  Future<ReportSummary> studentSummary();
}

/// Builds the student's report summary from existing tables.
/// This is a first pass for the interface design; charts and PDF export
/// are planned once this data shape is confirmed.
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
