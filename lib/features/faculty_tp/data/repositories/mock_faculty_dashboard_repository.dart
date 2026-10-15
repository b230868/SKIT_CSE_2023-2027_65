import '../../../approval/domain/entities/approval_review_stage.dart';
import '../models/mock_dashboard_data.dart';
import '../../domain/entities/dashboard_statistics.dart';
import 'faculty_dashboard_repository.dart';

class MockFacultyDashboardRepository
    implements FacultyDashboardRepository {
  @override
  Future<DashboardStatistics> getDashboardStatistics({
    ApprovalReviewStage? stage,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    return MockDashboardData.statistics;
  }
}