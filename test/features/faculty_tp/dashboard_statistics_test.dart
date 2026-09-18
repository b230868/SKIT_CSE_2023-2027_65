import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/domain/entities/dashboard_statistics.dart';

void main() {
  test('dashboard statistics stores correct values', () {
    const statistics = DashboardStatistics(
      pendingApprovals: 10,
      approvedInternships: 20,
      rejectedApplications: 3,
      studentsRequiringReview: 5,
    );

    expect(statistics.pendingApprovals, 10);
    expect(statistics.approvedInternships, 20);
    expect(statistics.rejectedApplications, 3);
    expect(statistics.studentsRequiringReview, 5);
  });
}