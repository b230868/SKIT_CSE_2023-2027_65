import '../../../approval/domain/entities/approval_review_stage.dart';
import '../repositories/faculty_dashboard_repository.dart';
import '../../domain/entities/dashboard_statistics.dart';

class FacultyDashboardService {
  final FacultyDashboardRepository repository;

  FacultyDashboardService({
    required this.repository,
  });

  Future<DashboardStatistics> loadStatistics({
    ApprovalReviewStage? stage,
  }) async {
    return await repository.getDashboardStatistics(stage: stage);
  }
}