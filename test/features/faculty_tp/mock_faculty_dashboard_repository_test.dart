
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/mock_faculty_dashboard_repository.dart';

void main() {
  test('returns dashboard statistics', () async {
    final repository = MockFacultyDashboardRepository();

    final statistics = await repository.getDashboardStatistics();

    expect(statistics.pendingApprovals, 12);
    expect(statistics.approvedInternships, 28);
    expect(statistics.rejectedApplications, 4);
    expect(statistics.studentsRequiringReview, 6);
  });
}

