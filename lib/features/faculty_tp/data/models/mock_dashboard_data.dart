import '../../domain/entities/dashboard_statistics.dart';

class MockDashboardData {
  static const DashboardStatistics statistics = DashboardStatistics(
    pendingApprovals: 12,
    approvedInternships: 28,
    rejectedApplications: 4,
    studentsRequiringReview: 6,
  );
}