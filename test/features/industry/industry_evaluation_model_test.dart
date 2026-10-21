import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/industry_evaluation_model.dart';

void main() {
  group('Industry Evaluation & Verification Model Tests', () {
    test('calculateGrade calculates correct academic grade thresholds', () {
      expect(IndustryEvaluationModel.calculateGrade(95.0), equals('A+'));
      expect(IndustryEvaluationModel.calculateGrade(90.0), equals('A+'));
      expect(IndustryEvaluationModel.calculateGrade(85.0), equals('A'));
      expect(IndustryEvaluationModel.calculateGrade(80.0), equals('A'));
      expect(IndustryEvaluationModel.calculateGrade(75.0), equals('B+'));
      expect(IndustryEvaluationModel.calculateGrade(70.0), equals('B+'));
      expect(IndustryEvaluationModel.calculateGrade(65.0), equals('B'));
      expect(IndustryEvaluationModel.calculateGrade(60.0), equals('B'));
      expect(IndustryEvaluationModel.calculateGrade(55.0), equals('C'));
      expect(IndustryEvaluationModel.calculateGrade(50.0), equals('C'));
      expect(IndustryEvaluationModel.calculateGrade(45.0), equals('F'));
      expect(IndustryEvaluationModel.calculateGrade(0.0), equals('F'));
    });

    test(
      'IndustryEvaluationModel.fromMap and toMap roundtrip serialization',
      () {
        final map = {
          'id': 'eval-123',
          'internship_id': 'int-456',
          'student_id': 'stud-789',
          'student_name': 'Kavya Sharma',
          'internship_title': 'Full Stack Intern',
          'company_name': 'Infosys Labs',
          'industry_id': 'ind-001',
          'evaluator_id': 'eval-999',
          'technical_skills_score': 18.0,
          'work_quality_score': 17.5,
          'attendance_score': 19.0,
          'initiative_score': 16.0,
          'communication_score': 17.5,
          'total_score': 88.0,
          'grade': 'A',
          'status': 'verified',
          'feedback': 'Excellent work across the sprint.',
          'remarks': 'Approved by mentor.',
          'evaluation_date': '2026-09-15T00:00:00.000',
          'submitted_at': '2026-09-15T10:00:00.000',
          'verified_at': '2026-09-16T12:00:00.000',
        };

        final model = IndustryEvaluationModel.fromMap(map);

        expect(model.id, equals('eval-123'));
        expect(model.internshipId, equals('int-456'));
        expect(model.studentName, equals('Kavya Sharma'));
        expect(model.technicalSkillsScore, equals(18.0));
        expect(model.totalScore, equals(88.0));
        expect(model.grade, equals('A'));
        expect(model.status, equals('verified'));
        expect(model.feedback, equals('Excellent work across the sprint.'));

        final outMap = model.toMap();
        expect(outMap['id'], equals('eval-123'));
        expect(outMap['total_score'], equals(88.0));
        expect(outMap['status'], equals('verified'));
      },
    );

    test(
      'IndustryEvaluationModel.copyWith updates specific fields properly',
      () {
        const initial = IndustryEvaluationModel(
          id: 'eval-001',
          internshipId: 'int-001',
          studentId: 'stud-001',
          studentName: 'Rohan Gupta',
          internshipTitle: 'DevOps Intern',
          companyName: 'CloudTech',
          technicalSkillsScore: 15,
          workQualityScore: 15,
          attendanceScore: 15,
          initiativeScore: 15,
          communicationScore: 15,
          totalScore: 75,
          grade: 'B+',
          status: 'pending',
        );

        final updated = initial.copyWith(
          status: 'verified',
          remarks: 'Verification approved.',
          verifiedAt: DateTime(2026, 9, 20),
        );

        expect(updated.id, equals('eval-001'));
        expect(updated.studentName, equals('Rohan Gupta'));
        expect(updated.status, equals('verified'));
        expect(updated.remarks, equals('Verification approved.'));
        expect(updated.verifiedAt, equals(DateTime(2026, 9, 20)));
        expect(updated.totalScore, equals(75));
      },
    );

    test('IndustryVerificationModel parses and maps properly', () {
      final map = {
        'id': 'ver-001',
        'internship_id': 'int-001',
        'itr_id': 'itr-001',
        'verifier_id': 'user-001',
        'status': 'verified',
        'remarks': 'Internship verified.',
        'verified_at': '2026-09-20T10:00:00.000',
      };

      final model = IndustryVerificationModel.fromMap(map);

      expect(model.id, equals('ver-001'));
      expect(model.internshipId, equals('int-001'));
      expect(model.status, equals('verified'));
      expect(model.remarks, equals('Internship verified.'));

      final out = model.toMap();
      expect(out['id'], equals('ver-001'));
      expect(out['status'], equals('verified'));
    });
  });
}
