import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/itr/data/models/itr_model.dart';

void main() {
  group('ItrModel Unit Tests', () {
    test('serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime(2026, 9, 15, 10, 30);
      final original = ItrModel(
        id: 'itr-501',
        internshipId: 'intern-501',
        studentId: 'student-501',
        studentName: 'Amit Patel',
        internshipTitle: 'Mobile App Developer',
        companyName: 'Infosys Ltd',
        status: 'submitted',
        content: 'Completed assigned Flutter widgets',
        workDone: 'Designed responsive screens and integrated APIs',
        technologiesUsed: 'Flutter, Dart, Provider',
        keyLearnings: 'Mobile UX patterns, state lifecycle',
        challengesFaced: 'Device responsiveness and offline caching',
        documentPath: 'docs/report.pdf',
        projectZipPath: 'project/source.zip',
        presentationPath: 'presentation/slides.pptx',
        submittedAt: now,
        reviewerName: 'Lead Architect',
        remarks: 'Very thorough report',
        certificateStatus: 'verified',
        certificateUrl: 'https://example.com/cert.pdf',
        evaluationScore: 88.0,
        evaluationGrade: 'A',
      );

      final map = original.toMap();
      final fromMap = ItrModel.fromMap(map);

      expect(fromMap.id, equals(original.id));
      expect(fromMap.internshipId, equals(original.internshipId));
      expect(fromMap.studentName, equals(original.studentName));
      expect(fromMap.companyName, equals(original.companyName));
      expect(fromMap.status, equals(original.status));
      expect(fromMap.content, equals(original.content));
      expect(fromMap.projectZipPath, equals(original.projectZipPath));
      expect(fromMap.presentationPath, equals(original.presentationPath));
      expect(fromMap.evaluationScore, equals(88.0));
      expect(fromMap.evaluationGrade, equals('A'));
      expect(fromMap.isCertificateVerified, isTrue);
    });

    test('copyWith preserves unmodified fields and updates targets', () {
      const initial = ItrModel(
        id: 'itr-1',
        internshipId: 'intern-1',
        studentId: 'student-1',
        studentName: 'Student Name',
        internshipTitle: 'Internship',
        companyName: 'Company',
        status: 'draft',
      );

      final updated = initial.copyWith(
        status: 'submitted',
        evaluationScore: 92.0,
        evaluationGrade: 'A+',
        certificateStatus: 'verified',
      );

      expect(updated.id, equals('itr-1'));
      expect(updated.studentName, equals('Student Name'));
      expect(updated.status, equals('submitted'));
      expect(updated.evaluationScore, equals(92.0));
      expect(updated.evaluationGrade, equals('A+'));
      expect(updated.isCertificateVerified, isTrue);
    });
  });
}
