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

class ReportSummary {
  final int totalApplications, approved, pending, rejected, completed;
  final int documentsUploaded;
  final int latestProgress;

  const ReportSummary({
    required this.totalApplications,
    required this.approved,
    required this.pending,
    required this.rejected,
    this.completed = 0,
    required this.documentsUploaded,
    required this.latestProgress,
  });

  factory ReportSummary.fromMap(Map<String, dynamic> map) {
    int readCount(String key) {
      final value = map[key];
      if (value is! num) {
        throw FormatException('Analytics response is missing $key.');
      }
      return value.toInt();
    }

    return ReportSummary(
      totalApplications: readCount('total_applications'),
      approved: readCount('approved'),
      pending: readCount('pending'),
      rejected: readCount('rejected'),
      completed: readCount('completed'),
      documentsUploaded: readCount('documents_uploaded'),
      latestProgress: readCount('latest_progress'),
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
}
