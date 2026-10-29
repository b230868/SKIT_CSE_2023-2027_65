class AppNotification {
  final String id, title, body, type;
  final bool isRead;
  final DateTime createdAt;

  final String? internshipId;

  String? get applicationId => internshipId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    String? internshipId,
    String? applicationId,
  }) : internshipId = internshipId ?? applicationId;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    id: m['id'] as String,
    title: m['title'] as String,
    body: (m['body'] ?? '') as String,
    type: (m['type'] ?? 'general') as String,
    isRead: (m['is_read'] ?? false) as bool,
    createdAt: DateTime.parse(m['created_at'] as String),
    internshipId: (m['internship_id'] ?? m['application_id']) as String?,
  );
}

/// One weekly progress entry, used by the trend chart and the PDF.
class ProgressPoint {
  final int weekNo;
  final int progress;
  final DateTime? recordedAt;

  const ProgressPoint({
    required this.weekNo,
    required this.progress,
    this.recordedAt,
  });
}

/// Report data for the signed-in student.
/// New this week: weekly history and documents-by-type, plus values derived
/// from them (analytics). The first six fields are unchanged, so existing
/// code that builds a ReportSummary keeps working.
class ReportSummary {
  final int totalApplications, approved, pending, rejected, completed;
  final int documentsUploaded;
  final int latestProgress;
  final Map<String, int> documentsByType;
  final List<ProgressPoint> progressHistory;

  const ReportSummary({
    required this.totalApplications,
    required this.approved,
    required this.pending,
    required this.rejected,
    this.completed = 0,
    required this.documentsUploaded,
    required this.latestProgress,
    this.documentsByType = const {},
    this.progressHistory = const [],
  });

  factory ReportSummary.fromMap(Map<String, dynamic> map) {
    int readCount(String key) {
      final value = map[key];
      if (value is! num) {
        throw FormatException('Analytics response is missing $key.');
      }
      return value.toInt();
    }

    final documentsByType = <String, int>{};
    final rawDocuments = map['documents_by_type'];
    if (rawDocuments is Map) {
      for (final entry in rawDocuments.entries) {
        if (entry.value is! num) {
          throw const FormatException('Document analytics are invalid.');
        }
        documentsByType[entry.key.toString()] = (entry.value as num).toInt();
      }
    } else if (rawDocuments != null) {
      throw const FormatException('Document analytics are invalid.');
    }

    final rawProgress = map['progress'];
    if (rawProgress != null && rawProgress is! List) {
      throw const FormatException('Progress analytics are invalid.');
    }
    final progressHistory = <ProgressPoint>[];
    for (final item in (rawProgress as List? ?? const [])) {
      if (item is! Map || item['week_no'] is! num || item['progress'] is! num) {
        throw const FormatException('Progress analytics are invalid.');
      }
      final recordedAt = item['recorded_at'];
      progressHistory.add(
        ProgressPoint(
          weekNo: (item['week_no'] as num).toInt(),
          progress: (item['progress'] as num).toInt(),
          recordedAt: recordedAt == null
              ? null
              : DateTime.parse(recordedAt as String),
        ),
      );
    }

    final documentCount = map['documents_uploaded'];
    if (documentCount != null && documentCount is! num) {
      throw const FormatException('Document analytics are invalid.');
    }

    return ReportSummary(
      totalApplications: readCount('total_applications'),
      approved: readCount('approved'),
      pending: readCount('pending'),
      rejected: readCount('rejected'),
      completed: readCount('completed'),
      documentsUploaded:
          (documentCount as num?)?.toInt() ??
          documentsByType.values.fold<int>(0, (total, count) => total + count),
      latestProgress: readCount('latest_progress'),
      documentsByType: documentsByType,
      progressHistory: progressHistory,
    );
  }

  factory ReportSummary.empty() => const ReportSummary(
    totalApplications: 0,
    approved: 0,
    pending: 0,
    rejected: 0,
    completed: 0,
    documentsUploaded: 0,
    latestProgress: 0,
  );

  // ---- analytics derived from the data above ----

  int get weeksLogged => progressHistory.length;

  /// Average progress gained per logged week (percentage points).
  double get averageWeeklyGain =>
      weeksLogged == 0 ? 0 : latestProgress / weeksLogged;

  /// Share of applications that were approved, in percent.
  double get approvalRate =>
      totalApplications == 0 ? 0 : approved * 100 / totalApplications;

  DateTime? get lastUpdate {
    DateTime? last;
    for (final p in progressHistory) {
      final d = p.recordedAt;
      if (d != null && (last == null || d.isAfter(last))) last = d;
    }
    return last;
  }

  int? get daysSinceLastUpdate {
    final d = lastUpdate;
    return d == null ? null : DateTime.now().difference(d).inDays;
  }

  /// Weeks still needed to reach 100% at the current average pace.
  int? get estimatedWeeksLeft {
    if (weeksLogged == 0 || averageWeeklyGain <= 0) return null;
    if (latestProgress >= 100) return 0;
    return ((100 - latestProgress) / averageWeeklyGain).ceil();
  }
}
