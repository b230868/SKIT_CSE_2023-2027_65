class AppNotification {
  final String id, title, body, type;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        title: m['title'] as String,
        body: (m['body'] ?? '') as String,
        type: (m['type'] ?? 'general') as String,
        isRead: (m['is_read'] ?? false) as bool,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// A light-weight summary used to draw the Reports screen.
/// Real numbers arrive once the report queries are implemented (next week);
/// for now this just gives the UI something typed to render.
class ReportSummary {
  final int totalApplications, approved, pending, rejected;
  final int documentsUploaded;
  final int latestProgress;

  const ReportSummary({
    required this.totalApplications,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.documentsUploaded,
    required this.latestProgress,
  });

  factory ReportSummary.empty() => const ReportSummary(
        totalApplications: 0,
        approved: 0,
        pending: 0,
        rejected: 0,
        documentsUploaded: 0,
        latestProgress: 0,
      );
}
