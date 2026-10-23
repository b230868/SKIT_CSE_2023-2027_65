import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/evaluation_model.dart';
import 'package:prashikshan/features/itr/data/models/itr_model.dart';
import 'package:prashikshan/features/itr/data/repositories/mock_itr_repository.dart';

void main() {
  group('MockItrRepository Unit Tests', () {
    late MockItrRepository repo;

    setUp(() {
      repo = MockItrRepository();
    });

    test('retrieves default ITR lists', () async {
      final itrs = await repo.getItrs();
      expect(itrs, isNotEmpty);
      expect(itrs.length, equals(3));
      expect(itrs.first.id, equals('itr-001'));
      expect(itrs.first.status, equals('submitted'));
    });

    test('retrieves ITR by ID and by Internship ID', () async {
      final itr1 = await repo.getItrById('itr-001');
      expect(itr1, isNotNull);
      expect(itr1!.studentName, equals('Rahul Sharma'));

      final itrByIntern = await repo.getItrByInternshipId('internship-002');
      expect(itrByIntern, isNotNull);
      expect(itrByIntern!.studentName, equals('Priya Singh'));

      final notFound = await repo.getItrById('non-existent');
      expect(notFound, isNull);
    });

    test('submits new ITR and updates status', () async {
      const newItr = ItrModel(
        id: 'itr-new-99',
        internshipId: 'intern-99',
        studentId: 'student-99',
        studentName: 'New Student',
        internshipTitle: 'Flutter Tester',
        companyName: 'Quality Inc',
        status: 'draft',
      );

      await repo.submitItr(newItr);
      final retrieved = await repo.getItrById('itr-new-99');
      expect(retrieved, isNotNull);
      expect(retrieved!.studentName, equals('New Student'));

      await repo.updateItrStatus('itr-new-99', 'submitted');
      final updated = await repo.getItrById('itr-new-99');
      expect(updated!.status, equals('submitted'));
    });

    test('simulates file upload for ZIP and presentation', () async {
      final zipBytes = Uint8List.fromList([1, 2, 3, 4]);
      final pptBytes = Uint8List.fromList([5, 6, 7, 8]);

      final zipPath = await repo.uploadProjectZip(
        itrId: 'itr-001',
        fileName: 'project.zip',
        fileBytes: zipBytes,
      );
      final pptPath = await repo.uploadProjectPresentation(
        itrId: 'itr-001',
        fileName: 'slides.pptx',
        fileBytes: pptBytes,
      );

      expect(zipPath, contains('project.zip'));
      expect(pptPath, contains('slides.pptx'));

      final updated = await repo.getItrById('itr-001');
      expect(updated!.projectZipPath, equals(zipPath));
      expect(updated.presentationPath, equals(pptPath));

      final fileUrl = await repo.getFileUrl(zipPath);
      expect(fileUrl, isNotNull);
      expect(fileUrl, contains('https://'));
    });

    test(
      'submits evaluation and updates ITR record and certificate verification',
      () async {
        final eval = EvaluationModel(
          id: 'eval-itr-001',
          itrId: 'itr-001',
          internshipId: 'internship-001',
          studentId: 'student-001',
          evaluatorId: 'mentor-1',
          evaluatorName: 'Supervisor Jane',
          technicalScore: 23,
          workQualityScore: 24,
          punctualityScore: 25,
          presentationScore: 22,
          remarks: 'Excellent work across the board.',
          certificateStatus: 'verified',
          evaluatedAt: DateTime.now(),
        );

        await repo.saveEvaluation(eval);

        final savedEval = await repo.getEvaluationByItrId('itr-001');
        expect(savedEval, isNotNull);
        expect(savedEval!.totalScore, equals(94.0));
        expect(savedEval.grade, equals('A+'));
        expect(savedEval.isCertificateVerified, isTrue);

        final updatedItr = await repo.getItrById('itr-001');
        expect(updatedItr!.evaluationScore, equals(94.0));
        expect(updatedItr.evaluationGrade, equals('A+'));
        expect(updatedItr.certificateStatus, equals('verified'));
        expect(updatedItr.isCertificateVerified, isTrue);
      },
    );

    test('updates certificate status directly', () async {
      await repo.updateCertificateStatus(
        itrId: 'itr-001',
        status: 'verified',
        certificateUrl: 'https://example.com/certificate-verified.pdf',
      );

      final itr = await repo.getItrById('itr-001');
      expect(itr!.certificateStatus, equals('verified'));
      expect(
        itr.certificateUrl,
        equals('https://example.com/certificate-verified.pdf'),
      );
    });
  });
}
