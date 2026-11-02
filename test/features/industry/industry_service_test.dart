import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/evaluation_model.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_repository.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';

void main() {
  group('Industry Module - Unit Tests (Sprint 5: Industry Dashboard & Management)', () {
    late MockIndustryRepository mockRepo;
    late IndustryService service;

    setUp(() {
      mockRepo = MockIndustryRepository(
        companyName: 'TechNova Solutions',
        hasVerifiedCompany: true,
      );
      service = IndustryService(repository: mockRepo);
    });

    test('Industry dashboard data computes accurate counts and metrics', () async {
      final data = await service.getDashboardData();

      expect(data.industryName, 'TechNova Solutions');
      expect(data.totalInterns, greaterThanOrEqualTo(3));
      expect(data.activeInterns, 2);
      expect(data.completedInternships, 1);
      expect(data.completionRate, inInclusiveRange(0.0, 100.0));
    });

    test('Loads industry interns scoped strictly to assigned company', () async {
      final interns = await service.getIndustryInternships();

      expect(interns.isNotEmpty, isTrue);
      for (final intern in interns) {
        expect(intern.companyName, 'TechNova Solutions');
        expect(intern.studentName.isNotEmpty, isTrue);
        expect(intern.internshipTitle.isNotEmpty, isTrue);
      }
    });

    test('Filters internships by active and completed statuses', () async {
      final interns = await service.getIndustryInternships();
      final activeInterns = interns.where((i) => i.status == 'active').toList();
      expect(activeInterns.every((i) => i.status == 'active'), isTrue);

      final completedInterns = interns.where((i) => i.status == 'completed').toList();
      expect(completedInterns.every((i) => i.status == 'completed'), isTrue);
    });

    test('Retrieves single internship detail by ID', () async {
      final interns = await service.getIndustryInternships();
      final intern = interns.firstWhere((i) => i.id == '1');

      expect(intern.id, '1');
      expect(intern.studentName, 'Rahul Sharma');
      expect(intern.itrStatus, 'submitted');
      expect(intern.attendanceRate, 92.0);
    });

    test('Records daily attendance for assigned interns successfully', () async {
      final date = DateTime.now();
      await service.markAttendance(
        internshipId: '1',
        studentId: 'student-1',
        date: date,
        status: 'present',
        remarks: 'Full day worked on feature',
      );

      final records = await service.getAttendanceRecords('1');
      expect(records.isNotEmpty, isTrue);
      expect(records.any((r) => r.status == 'present'), isTrue);
    });

    test('Calculates aggregated industry analytics accurately', () async {
      final analytics = await service.getAnalyticsData();

      expect(analytics.industryName, 'TechNova Solutions');
      expect(analytics.totalInterns, greaterThan(0));
      expect(analytics.activeInterns, greaterThanOrEqualTo(0));
      expect(analytics.attendanceRate, inInclusiveRange(0.0, 100.0));
      expect(analytics.averageScore, inInclusiveRange(0.0, 100.0));
    });
  });

  group('Industry Evaluation - Calculation & Grading Logic Tests', () {
    test('EvaluationModel correctly calculates total marks out of 100', () {
      final eval = EvaluationModel(
        id: 'eval-1',
        itrId: 'itr-1',
        internshipId: 'internship-1',
        studentId: 'student-1',
        evaluatorId: 'evaluator-1',
        evaluatorName: 'Industry Evaluator',
        technicalScore: 23.0,
        workQualityScore: 22.0,
        punctualityScore: 24.0,
        presentationScore: 21.0,
        remarks: 'Excellent performance throughout the internship.',
        evaluatedAt: DateTime.now(),
        certificateStatus: 'verified',
      );

      expect(eval.totalScore, 90.0);
      expect(eval.grade, 'A+');
      expect(eval.isCertificateVerified, isTrue);
    });

    test('Grading scale boundaries function accurately across thresholds', () {
      EvaluationModel createWithScore(double eachScore) {
        return EvaluationModel(
          id: 'test',
          itrId: 'test',
          internshipId: 'internship-test',
          studentId: 'student-test',
          evaluatorId: 'evaluator-test',
          evaluatorName: 'Test Evaluator',
          technicalScore: eachScore,
          workQualityScore: eachScore,
          punctualityScore: eachScore,
          presentationScore: eachScore,
          remarks: 'Grade test',
          evaluatedAt: DateTime.now(),
        );
      }

      expect(createWithScore(23.0).grade, 'A+'); // 92 total
      expect(createWithScore(20.5).grade, 'A');  // 82 total
      expect(createWithScore(18.0).grade, 'B');  // 72 total
      expect(createWithScore(15.5).grade, 'C');  // 62 total
      expect(createWithScore(13.0).grade, 'D');  // 52 total
      expect(createWithScore(10.0).grade, 'F');  // 40 total
    });
  });
}
