import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/industry_dashboard_data.dart';
import 'package:prashikshan/features/industry/data/models/industry_internship_model.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_repository.dart';

void main() {
  group('MockIndustryRepository Unit Tests', () {
    test('returns default internships correctly', () async {
      final repo = MockIndustryRepository();
      final internships = await repo.getIndustryInternships();

      expect(internships, isNotEmpty);
      expect(internships.length, equals(3));
      expect(internships.first.studentName, equals('Rahul Sharma'));
      expect(internships.first.status, equals('active'));
    });

    test('returns default dashboard data correctly', () async {
      final repo = MockIndustryRepository();
      final data = await repo.getDashboardData();

      expect(data.industryName, equals('TechNova Solutions'));
      expect(data.totalInterns, equals(24));
      expect(data.activeInterns, equals(18));
      expect(data.completedInternships, equals(6));
    });

    test('supports custom mock data injection for tests', () async {
      const customInternships = [
        IndustryInternshipModel(
          id: 'custom-1',
          studentName: 'Custom Student',
          internshipTitle: 'AI Research Intern',
          status: 'completed',
          progress: 100,
          itrStatus: 'approved',
          evaluationStatus: 'verified',
        ),
      ];

      const customDashboard = IndustryDashboardData(
        industryName: 'Custom Labs',
        totalInterns: 1,
        activeInterns: 0,
        completedInternships: 1,
        pendingItrs: 0,
        submittedItrs: 1,
        pendingEvaluations: 0,
        completedEvaluations: 1,
      );

      final repo = MockIndustryRepository(
        internships: customInternships,
        dashboardData: customDashboard,
      );

      final internships = await repo.getIndustryInternships();
      final dashboard = await repo.getDashboardData();

      expect(internships.length, equals(1));
      expect(internships.first.studentName, equals('Custom Student'));
      expect(dashboard.industryName, equals('Custom Labs'));
      expect(dashboard.completionRate, equals(100.0));
    });
  });
}
