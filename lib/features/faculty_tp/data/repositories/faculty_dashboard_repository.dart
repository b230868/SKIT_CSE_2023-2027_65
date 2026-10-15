import '../../../approval/domain/entities/approval_review_stage.dart';
import '../../domain/entities/dashboard_statistics.dart';

abstract class FacultyDashboardRepository {
  Future<DashboardStatistics> getDashboardStatistics({
    ApprovalReviewStage? stage,
  });
}