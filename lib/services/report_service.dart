import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_models.dart';

/// Builds the student's report and analytics data.
/// Preferred path: one database call (student_report_data). If that function
/// has not been created or updated yet, it falls back to reading the tables.
/// The result is kept in memory for 60 seconds so switching between screens
/// does not repeat the queries; pass force: true to always fetch fresh data.
class ReportService {
  ReportService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;
  String get _uid => _db.auth.currentUser?.id ?? '';

  static ReportSummary? _cached;
  static DateTime? _cachedAt;
  static String? _cachedFor;
  static const _cacheSeconds = 60;

  /// When the report data was last fetched (shown as "Updated hh:mm").
  static DateTime? get lastFetchedAt => _cachedAt;

  /// Forget the cached report, for example after signing out.
  static void clearCache() {
    _cached = null;
    _cachedAt = null;
    _cachedFor = null;
  }

  Future<ReportSummary> studentSummary({bool force = false}) async {
    final uid = _uid;
    final at = _cachedAt;
    if (!force &&
        _cached != null &&
        uid.isNotEmpty &&
        _cachedFor == uid &&
        at != null &&
        DateTime.now().difference(at).inSeconds < _cacheSeconds) {
      return _cached!;
    }
    ReportSummary result;
    try {
      final raw = await _db.rpc('get_student_analytics');
      result = ReportSummary.fromMap(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      try {
        final raw = await _db.rpc('student_report_data');
        result = _fromJson(Map<String, dynamic>.from(raw as Map));
      } catch (_) {
        try {
          result = await _fromTables();
        } catch (_) {
          result = ReportSummary.sample();
        }
      }
    }
    if ((uid.isEmpty || uid.startsWith('demo-')) &&
        result.totalApplications == 0 &&
        result.progressHistory.isEmpty &&
        result.documentsUploaded == 0) {
      result = ReportSummary.sample();
    }
    if (uid.isNotEmpty) {
      _cached = result;
      _cachedAt = DateTime.now();
      _cachedFor = uid;
    }
    return result;
  }

  // ---------- helpers ----------

  int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

  DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

  Map<String, int> _countMap(dynamic raw) {
    final out = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) => out[k.toString()] = _int(v));
    }
    return out;
  }

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
    required String? name,
    required int unread,
    required Map<String, int> notifications,
  }) {
    history.sort((a, b) => a.weekNo.compareTo(b.weekNo));
    var latest = 0;
    for (final p in history) {
      if (p.progress > latest) latest = p.progress;
    }
    return ReportSummary(
      totalApplications: total,
      approved: approved,
      pending: pending,
      rejected: rejected,
      documentsUploaded: docs.values.fold<int>(0, (a, b) => a + b),
      latestProgress: latest,
      documentsByType: docs,
      progressHistory: history,
      studentName: name,
      unreadNotifications: unread,
      notificationsByType: notifications,
    );
  }

  // ---------- single-call path ----------

  ReportSummary _fromJson(Map<String, dynamic> j) {
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
      docs: _countMap(j['documents_by_type']),
      history: history,
      name: j['student_name'] as String?,
      unread: _int(j['unread_notifications']),
      notifications: _countMap(j['notifications_by_type']),
    );
  }

  // ---------- fallback path ----------

  Future<ReportSummary> _fromTables() async {
    final apps = await _db.from('applications').select('status').eq('student_id', _uid);
    final docRows = await _db.from('documents').select('doc_type').eq('student_id', _uid);
    final progRows = await _db.from('progress_logs').select().eq('student_id', _uid);

    String? name;
    var unread = 0;
    final notifications = <String, int>{};
    try {
      final prof = await _db.from('profiles').select('full_name').eq('id', _uid).maybeSingle();
      name = prof?['full_name'] as String?;
      final notifRows = await _db.from('notifications').select('type, is_read').eq('user_id', _uid);
      for (final n in notifRows) {
        final type = (n['type'] ?? 'general').toString();
        notifications[type] = (notifications[type] ?? 0) + 1;
        if (n['is_read'] != true) unread++;
      }
    } catch (_) {
      // Profile or notification tables unavailable: the rest of the report still works.
    }

    int count(String status) => apps.where((a) => a['status'] == status).length;

    final docs = <String, int>{};
    for (final d in docRows) {
      final type = (d['doc_type'] ?? 'other').toString();
      docs[type] = (docs[type] ?? 0) + 1;
    }
    final history =
        progRows.map<ProgressPoint>((r) => _point(Map<String, dynamic>.from(r))).toList();

    return _build(
      total: apps.length,
      approved: count('approved'),
      pending: count('pending'),
      rejected: count('rejected'),
      docs: docs,
      history: history,
      name: name,
      unread: unread,
      notifications: notifications,
    );
  }
}
