class AppNotification {
  final String id, title, body, type;
  final bool isRead;
  final DateTime createdAt;

  /// Set for notifications that belong to an application or internship, so
  /// tapping them can open that item directly.
  final String? applicationId;

  String? get internshipId => applicationId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    String? applicationId,
    String? internshipId,
  }) : applicationId = applicationId ?? internshipId;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        title: m['title'] as String,
        body: (m['body'] ?? '') as String,
        type: (m['type'] ?? 'general') as String,
        isRead: (m['is_read'] ?? false) as bool,
        createdAt: DateTime.parse(m['created_at'] as String),
        applicationId: (m['internship_id'] ?? m['application_id']) as String?,
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
/// Refined this week: student name, notification statistics, a baseline for
/// time-window analytics, and week-by-week gain calculations.
/// `progressHistory` must be sorted by week number (ReportService does this).
class ReportSummary {
  final int totalApplications, approved, pending, rejected, completed;
  final int documentsUploaded;
  final int latestProgress;
  final Map<String, int> documentsByType;
  final List<ProgressPoint> progressHistory;

  // new this week
  final String? studentName;
  final int unreadNotifications;
  final Map<String, int> notificationsByType;

  /// Progress reached before the first entry in [progressHistory].
  /// 0 for the full history; set when a shorter time window is selected.
  final int baselineProgress;

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
    this.studentName,
    this.unreadNotifications = 0,
    this.notificationsByType = const {},
    this.baselineProgress = 0,
  });

  factory ReportSummary.empty() => const ReportSummary(
        totalApplications: 0,
        approved: 0,
        pending: 0,
        rejected: 0,
        completed: 0,
        documentsUploaded: 0,
        latestProgress: 0,
      );

  factory ReportSummary.fromMap(Map<String, dynamic> j) {
    int toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
    DateTime? toDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    final docs = <String, int>{};
    final rawDocs = j['documents_by_type'];
    if (rawDocs is Map) {
      rawDocs.forEach((k, v) => docs[k.toString()] = toInt(v));
    }

    final history = <ProgressPoint>[];
    final rawProgress = j['progress'];
    if (rawProgress is List) {
      for (final p in rawProgress) {
        if (p is Map) {
          final m = Map<String, dynamic>.from(p);
          history.add(ProgressPoint(
            weekNo: toInt(m['week_no']),
            progress: toInt(m['progress']),
            recordedAt: toDate(m['recorded_at'] ?? m['created_at']),
          ));
        }
      }
      history.sort((a, b) => a.weekNo.compareTo(b.weekNo));
    }

    final notifs = <String, int>{};
    final rawNotifs = j['notifications_by_type'];
    if (rawNotifs is Map) {
      rawNotifs.forEach((k, v) => notifs[k.toString()] = toInt(v));
    }

    var latest = toInt(j['latest_progress']);
    if (latest == 0 && history.isNotEmpty) {
      for (final p in history) {
        if (p.progress > latest) latest = p.progress;
      }
    }

    final docCount = j.containsKey('documents_uploaded')
        ? toInt(j['documents_uploaded'])
        : docs.values.fold<int>(0, (a, b) => a + b);

    return ReportSummary(
      totalApplications: toInt(j['total_applications']),
      approved: toInt(j['approved']),
      pending: toInt(j['pending']),
      rejected: toInt(j['rejected']),
      completed: toInt(j['completed']),
      documentsUploaded: docCount,
      latestProgress: latest,
      documentsByType: docs,
      progressHistory: history,
      studentName: j['student_name'] as String?,
      unreadNotifications: toInt(j['unread_notifications']),
      notificationsByType: notifs,
      baselineProgress: toInt(j['baseline_progress']),
    );
  }

  // ---- time window ----

  /// A copy limited to the last [n] logged weeks. Gains inside the window
  /// are measured from the progress reached just before it.
  ReportSummary lastWeeks(int n) {
    if (n <= 0 || progressHistory.length <= n) return this;
    final start = progressHistory.length - n;
    return ReportSummary(
      totalApplications: totalApplications,
      approved: approved,
      pending: pending,
      rejected: rejected,
      completed: completed,
      documentsUploaded: documentsUploaded,
      latestProgress: latestProgress,
      documentsByType: documentsByType,
      progressHistory: progressHistory.sublist(start),
      studentName: studentName,
      unreadNotifications: unreadNotifications,
      notificationsByType: notificationsByType,
      baselineProgress: progressHistory[start - 1].progress,
    );
  }

  // ---- analytics ----

  int get weeksLogged => progressHistory.length;

  /// Progress gained in each logged week (percentage points).
  List<int> get weeklyGains {
    final gains = <int>[];
    var previous = baselineProgress;
    for (final p in progressHistory) {
      gains.add(p.progress - previous);
      previous = p.progress;
    }
    return gains;
  }

  /// Average progress gained per logged week.
  double get averageWeeklyGain =>
      weeksLogged == 0 ? 0 : (latestProgress - baselineProgress) / weeksLogged;

  /// Change since the previous logged week; null with fewer than two entries.
  int? get weekOverWeekGain {
    final g = weeklyGains;
    return g.length < 2 ? null : g.last;
  }

  /// Week number with the largest gain; null when nothing was gained.
  int? get bestWeek {
    final g = weeklyGains;
    var best = 0;
    int? week;
    for (var i = 0; i < g.length; i++) {
      if (g[i] > best) {
        best = g[i];
        week = progressHistory[i].weekNo;
      }
    }
    return week;
  }

  /// Logged weeks in which progress did not increase.
  int get stalledWeeks => weeklyGains.where((g) => g <= 0).length;

  /// Share of applications that were approved, in percent.
  double get approvalRate =>
      totalApplications == 0 ? 0 : approved * 100 / totalApplications;

  int get totalNotifications => notificationsByType.values.fold(0, (a, b) => a + b);

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