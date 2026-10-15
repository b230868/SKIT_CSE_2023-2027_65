import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_review_stage.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/faculty_dashboard_repository_factory.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/supabase_faculty_dashboard_repository.dart';

void main() {
  group('SupabaseFacultyDashboardRepository & Factory', () {
    test('SupabaseFacultyDashboardRepository falls back safely when unauthenticated', () async {
      final repository = SupabaseFacultyDashboardRepository();
      final stats = await repository.getDashboardStatistics();

      expect(stats.pendingApprovals, greaterThanOrEqualTo(0));
      expect(stats.approvedInternships, greaterThanOrEqualTo(0));
      expect(stats.rejectedApplications, greaterThanOrEqualTo(0));
      expect(stats.studentsRequiringReview, greaterThanOrEqualTo(0));
    });

    test(
      'SupabaseFacultyDashboardRepository accepts stage parameters safely',
      () async {
        final repository = SupabaseFacultyDashboardRepository();
        final facultyStats = await repository.getDashboardStatistics(
          stage: ApprovalReviewStage.faculty,
        );
        expect(facultyStats.pendingApprovals, greaterThanOrEqualTo(0));

        final tpStats = await repository.getDashboardStatistics(
          stage: ApprovalReviewStage.tpAdmin,
        );
        expect(tpStats.pendingApprovals, greaterThanOrEqualTo(0));
      },
    );

    test(
      'FacultyDashboardRepositoryFactory creates repository instance safely',
      () {
        final repository = FacultyDashboardRepositoryFactory.create();
        expect(repository, isNotNull);
      },
    );
  });
}
