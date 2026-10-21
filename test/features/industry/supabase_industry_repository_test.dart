import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/industry_dashboard_data.dart';
import 'package:prashikshan/features/industry/data/models/industry_internship_model.dart';
import 'package:prashikshan/features/industry/data/repositories/supabase_industry_repository.dart';

void main() {
  group('SupabaseIndustryRepository & Model Parsing Unit Tests', () {
    test(
      'IndustryInternshipModel.fromMap parses standard payload correctly',
      () {
        final map = {
          'id': 'intern-001',
          'student_name': 'Rahul Sharma',
          'internship_title': 'Mobile Engineer Intern',
          'status': 'active',
          'progress': 75.5,
          'itr_status': 'submitted',
          'evaluation_status': 'verified',
        };

        final model = IndustryInternshipModel.fromMap(map);

        expect(model.id, equals('intern-001'));
        expect(model.studentName, equals('Rahul Sharma'));
        expect(model.internshipTitle, equals('Mobile Engineer Intern'));
        expect(model.status, equals('active'));
        expect(model.progress, equals(75.5));
        expect(model.itrStatus, equals('submitted'));
        expect(model.evaluationStatus, equals('verified'));
      },
    );

    test(
      'IndustryInternshipModel.fromMap falls back gracefully on missing keys',
      () {
        final map = <String, dynamic>{};
        final model = IndustryInternshipModel.fromMap(map);

        expect(model.id, equals(''));
        expect(model.studentName, equals('Student'));
        expect(model.internshipTitle, equals('Internship'));
        expect(model.status, equals('planned'));
        expect(model.progress, equals(0));
        expect(model.itrStatus, equals('draft'));
        expect(model.evaluationStatus, equals('pending'));
      },
    );

    test('IndustryDashboardData.fromMap calculates rates correctly', () {
      final map = {
        'industry_name': 'Tech Corp',
        'total_interns': 20,
        'active_interns': 15,
        'completed_internships': 5,
        'pending_itrs': 4,
        'submitted_itrs': 10,
        'pending_evaluations': 3,
        'completed_evaluations': 7,
      };

      final data = IndustryDashboardData.fromMap(map);

      expect(data.industryName, equals('Tech Corp'));
      expect(data.totalInterns, equals(20));
      expect(data.completionRate, equals(25.0)); // 5 / 20 * 100
      expect(data.itrSubmissionRate, equals(50.0)); // 10 / 20 * 100
      expect(data.evaluationRate, equals(70.0)); // 7 / 10 * 100
    });

    test(
      'IndustryDashboardData handles zero interns without division by zero',
      () {
        final empty = IndustryDashboardData.empty('Zero Labs');

        expect(empty.totalInterns, equals(0));
        expect(empty.completionRate, equals(0.0));
        expect(empty.itrSubmissionRate, equals(0.0));
        expect(empty.evaluationRate, equals(0.0));
      },
    );

    test('SupabaseIndustryRepository throws StateError when user is unauthenticated', () async {
      // In a unit test environment without active Supabase session
      final repo = SupabaseIndustryRepository();

      expect(() => repo.getIndustryInternships(), throwsA(isA<StateError>()));

      expect(() => repo.getDashboardData(), throwsA(isA<StateError>()));
    });
  });
}
