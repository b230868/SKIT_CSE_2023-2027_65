import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_models.dart';

abstract interface class ReportDataSource {
  Future<ReportSummary> studentSummary();
}

/// Loads the authenticated student's report from the analytics RPC.
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
