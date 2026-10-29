import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_models.dart';

/// Builds the student's report and analytics data.
/// Preferred path: one database call (student_report_data) that returns
/// everything together. If that function has not been created yet, it falls
/// back to reading the tables directly, so the screen keeps working.
class ReportService {
  final SupabaseClient _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<ReportSummary> studentSummary() async {
    try {
      final raw = await _db.rpc('student_report_data');
      return _fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return _fromTables();
    }
  }

  // ---------- helpers ----------

  int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

  DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

  ProgressPoint _point(Map<String, dynamic> m) => ProgressPoint(
        weekNo: _int(m['week_no']),
        progress: _int(m['progress']),
        recordedAt: _date(m['recorded_at'] ?? m['created_at']),
      );

  ReportSummary _build({
    required int total,
    required int approved,
    required int pending,
    required int rejected,
    required Map<String, int> docs,
    required List<ProgressPoint> history,
  }) {
    history.sort((a, b) => a.weekNo.compareTo(b.weekNo));
    var latest = 0;
    for (final p in history) {
      if (p.progress > latest) latest = p.progress;
    }
    final docCount = docs.values.fold<int>(0, (a, b) => a + b);
    return ReportSummary(
      totalApplications: total,
      approved: approved,
      pending: pending,
      rejected: rejected,
      documentsUploaded: docCount,
      latestProgress: latest,
      documentsByType: docs,
      progressHistory: history,
    );
  }

  // ---------- single-call path ----------

  ReportSummary _fromJson(Map<String, dynamic> j) {
    final docs = <String, int>{};
    final rawDocs = j['documents_by_type'];
    if (rawDocs is Map) {
      rawDocs.forEach((k, v) => docs[k.toString()] = _int(v));
    }
    final history = <ProgressPoint>[];
    final rawProgress = j['progress'];
    if (rawProgress is List) {
      for (final p in rawProgress) {
        if (p is Map) history.add(_point(Map<String, dynamic>.from(p)));
      }
    }
    return _build(
      total: _int(j['total_applications']),
      approved: _int(j['approved']),
      pending: _int(j['pending']),
      rejected: _int(j['rejected']),
      docs: docs,
      history: history,
    );
  }

  // ---------- fallback path ----------

  Future<ReportSummary> _fromTables() async {
    final apps = await _db.from('applications').select('status').eq('student_id', _uid);
    final docRows = await _db.from('documents').select('doc_type').eq('student_id', _uid);
    final progRows = await _db.from('progress_logs').select().eq('student_id', _uid);

    int count(String status) => apps.where((a) => a['status'] == status).length;

    final docs = <String, int>{};
    for (final d in docRows) {
      final type = (d['doc_type'] ?? 'other').toString();
      docs[type] = (docs[type] ?? 0) + 1;
    }
    final history = progRows.map<ProgressPoint>((r) => _point(Map<String, dynamic>.from(r))).toList();

    return _build(
      total: apps.length,
      approved: count('approved'),
      pending: count('pending'),
      rejected: count('rejected'),
      docs: docs,
      history: history,
    );
  }
}
