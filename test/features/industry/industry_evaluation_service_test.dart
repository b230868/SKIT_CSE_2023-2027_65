import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_evaluation_repository.dart';
import 'package:prashikshan/features/industry/data/services/industry_evaluation_service.dart';

void main() {
  group('IndustryEvaluationService Tests', () {
    late MockIndustryEvaluationRepository repo;
    late IndustryEvaluationService service;

    setUp(() {
      repo = MockIndustryEvaluationRepository();
      service = IndustryEvaluationService(repository: repo);
    });

    test('getEvaluations returns list of mock evaluations', () async {
      final evals = await service.getEvaluations();
      expect(evals, isNotEmpty);
      expect(evals.length, equals(3));
      expect(evals.first.studentName, equals('Rahul Sharma'));
    });

    test('getEvaluationByInternshipId retrieves matching record', () async {
      final eval = await service.getEvaluationByInternshipId('1');
      expect(eval, isNotNull);
      expect(eval!.internshipTitle, equals('Software Development Intern'));
      expect(eval.studentName, equals('Rahul Sharma'));
    });

    test('getEvaluationByInternshipId returns null when not found', () async {
      final eval = await service.getEvaluationByInternshipId('non-existent');
      expect(eval, isNull);
    });

    test(
      'saveEvaluation computes total score and calculates grade automatically',
      () async {
        await service.saveEvaluation(
          internshipId: 'int-new',
          studentId: 'stud-new',
          studentName: 'New Student',
          internshipTitle: 'Mobile Developer',
          companyName: 'TechCorp',
          technicalSkillsScore: 19.0,
          workQualityScore: 18.0,
          attendanceScore: 19.0,
          initiativeScore: 18.0,
          communicationScore: 18.0,
          status: 'verified',
          feedback: 'Great performance',
          remarks: 'Verified',
        );

        final saved = await service.getEvaluationByInternshipId('int-new');
        expect(saved, isNotNull);
        expect(saved!.totalScore, equals(92.0));
        expect(saved.grade, equals('A+'));
        expect(saved.status, equals('verified'));
        expect(saved.feedback, equals('Great performance'));
      },
    );

    test('verifyInternship updates evaluation status to verified', () async {
      await service.verifyInternship(
        internshipId: '1',
        remarks: 'Officially verified by industry supervisor',
      );

      final updated = await service.getEvaluationByInternshipId('1');
      expect(updated, isNotNull);
      expect(updated!.status, equals('verified'));
      expect(
        updated.remarks,
        equals('Officially verified by industry supervisor'),
      );
      expect(updated.verifiedAt, isNotNull);
    });
  });
}
