class DashboardStatistics {
  final int pendingApprovals;
  final int approvedInternships;
  final int rejectedApplications;
  final int studentsRequiringReview;

  const DashboardStatistics({
    required this.pendingApprovals,
    required this.approvedInternships,
    required this.rejectedApplications,
    required this.studentsRequiringReview,
  });
}