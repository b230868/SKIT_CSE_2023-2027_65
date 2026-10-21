import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/evaluation_model.dart';

void main() {
  group('EvaluationModel Unit Tests', () {
    test('calculates totalScore and grade correctly for excellent score', () {
      final evaluation = EvaluationModel(
        id: 'eval-1',
        itrId: 'itr-1',
        internshipId: 'intern-1',
        studentId: 'student-1',
        evaluatorId: 'mentor-1',
        evaluatorName: 'Dr. Jane Smith',
        technicalScore: 24,
        workQualityScore: 23,
        punctualityScore: 25,
        presentationScore: 23,
        remarks: 'Outstanding project performance',
        certificateStatus: 'verified',
        evaluatedAt: DateTime(2026, 9, 30),
      );

      expect(evaluation.totalScore, equals(95.0));
      expect(evaluation.grade, equals('A+'));
      expect(evaluation.isCertificateVerified, isTrue);
    });

    test('calculates correct grades across all boundaries', () {
      EvaluationModel createWithTotal(double scorePerCriterion) {
        return EvaluationModel(
          id: 'eval-x',
          itrId: 'itr-x',
          internshipId: 'intern-x',
          studentId: 'student-x',
          evaluatorId: 'mentor-x',
          evaluatorName: 'Mentor',
          technicalScore: scorePerCriterion,
          workQualityScore: scorePerCriterion,
          punctualityScore: scorePerCriterion,
          presentationScore: scorePerCriterion,
          remarks: 'Testing',
          evaluatedAt: DateTime.now(),
        );
      }

      expect(createWithTotal(21.25).grade, equals('A')); // 85%
      expect(createWithTotal(18.75).grade, equals('B')); // 75%
      expect(createWithTotal(16.25).grade, equals('C')); // 65%
      expect(createWithTotal(13.75).grade, equals('D')); // 55%
      expect(createWithTotal(10.0).grade, equals('F')); // 40%
    });

    test('serializes toMap and deserializes fromMap correctly', () {
      final original = EvaluationModel(
        id: 'eval-101',
        itrId: 'itr-101',
        internshipId: 'intern-101',
        studentId: 'student-101',
        evaluatorId: 'mentor-101',
        evaluatorName: 'Supervisor Mark',
        technicalScore: 22.5,
        workQualityScore: 21.0,
        punctualityScore: 24.0,
        presentationScore: 20.5,
        remarks: 'Great teamwork and delivery',
        certificateStatus: 'verified',
        certificateVerifiedAt: DateTime(2026, 10, 1),
        evaluatedAt: DateTime(2026, 10, 1),
      );

      final map = original.toMap();
      final reconstructed = EvaluationModel.fromMap(map);

      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.itrId, equals(original.itrId));
      expect(reconstructed.totalScore, equals(original.totalScore));
      expect(reconstructed.grade, equals(original.grade));
      expect(reconstructed.certificateStatus, equals('verified'));
      expect(reconstructed.isCertificateVerified, isTrue);
    });

    test('copyWith updates specified fields only', () {
      final initial = EvaluationModel(
        id: 'eval-1',
        itrId: 'itr-1',
        internshipId: 'intern-1',
        studentId: 'student-1',
        evaluatorId: 'mentor-1',
        evaluatorName: 'Mentor',
        technicalScore: 15,
        workQualityScore: 15,
        punctualityScore: 15,
        presentationScore: 15,
        remarks: 'Needs improvement',
        certificateStatus: 'pending',
        evaluatedAt: DateTime.now(),
      );

      final updated = initial.copyWith(
        technicalScore: 22,
        certificateStatus: 'verified',
      );

      expect(updated.technicalScore, equals(22));
      expect(updated.workQualityScore, equals(15));
      expect(updated.certificateStatus, equals('verified'));
      expect(updated.isCertificateVerified, isTrue);
    });
  });
}
