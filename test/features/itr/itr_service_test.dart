import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/evaluation_model.dart';
import 'package:prashikshan/features/itr/data/models/itr_model.dart';
import 'package:prashikshan/features/itr/data/repositories/mock_itr_repository.dart';
import 'package:prashikshan/features/itr/data/services/itr_service.dart';

void main() {
  group('ITR Module - Unit Tests (Sprint 5: ITR Management & Verification)', () {
    late MockItrRepository mockRepo;
    late ItrService service;

    setUp(() {
      mockRepo = MockItrRepository();
      service = ItrService(mockRepo);
    });

    test('Fetches all ITR records for authorized reviewer', () async {
      final itrs = await service.getItrs();

      expect(itrs.isNotEmpty, isTrue);
      expect(itrs.length, greaterThanOrEqualTo(3));
      expect(itrs.any((i) => i.status == 'submitted'), isTrue);
      expect(itrs.any((i) => i.status == 'under_review'), isTrue);
      expect(itrs.any((i) => i.status == 'draft'), isTrue);
    });

    test('Filters ITRs strictly by student ID', () async {
      final allItrs = await service.getItrs();
      final studentItrs = allItrs.where((i) => i.studentId == 'student-001').toList();

      expect(studentItrs.isNotEmpty, isTrue);
      expect(studentItrs.every((i) => i.studentId == 'student-001'), isTrue);
      expect(studentItrs.first.studentName, 'Rahul Sharma');
    });

    test('Retrieves single ITR report by ID', () async {
      final itr = await service.getItrById('itr-001');

      expect(itr, isNotNull);
      expect(itr!.id, 'itr-001');
      expect(itr.internshipTitle, 'Software Development Intern');
      expect(itr.technologiesUsed, contains('Flutter'));
    });

    test('Submits complete ITR with documentation and updates status to submitted', () async {
      final itrToSubmit = ItrModel(
        id: 'itr-003',
        internshipId: 'internship-003',
        studentId: 'student-003',
        studentName: 'Aman Verma',
        internshipTitle: 'Flutter Development Intern',
        companyName: 'Tech Company',
        status: 'submitted',
        submittedAt: DateTime.now(),
        content: 'Completed advanced state management and testing.',
        workDone: 'Created responsive UI and integration tests.',
        technologiesUsed: 'Flutter, SQLite, Supabase',
        keyLearnings: 'End-to-end integration and responsive layouts.',
        challengesFaced: 'Mocking complex streams in unit testing.',
      );

      await service.submitItr(itrToSubmit);
      final fetched = await service.getItrById('itr-003');

      expect(fetched, isNotNull);
      expect(fetched!.status, 'submitted');
      expect(fetched.content, contains('advanced state management'));
    });

    test('Industry Supervisor reviews ITR, enters evaluation, and updates status', () async {
      final eval = EvaluationModel(
        id: 'eval-new',
        itrId: 'itr-001',
        internshipId: 'internship-001',
        studentId: 'student-001',
        evaluatorId: 'eval-user-1',
        evaluatorName: 'Lead Architect',
        technicalScore: 24.0,
        workQualityScore: 23.0,
        punctualityScore: 25.0,
        presentationScore: 23.0,
        remarks: 'Outstanding work quality and delivered ahead of time.',
        evaluatedAt: DateTime.now(),
        certificateStatus: 'verified',
      );

      await service.saveEvaluation(eval);
      await service.reviewItr(
        itrId: 'itr-001',
        status: 'approved',
        remarks: 'Verified and approved with high distinction.',
        reviewerName: 'Lead Architect',
      );

      final reviewedItr = await service.getItrById('itr-001');
      expect(reviewedItr, isNotNull);
      expect(reviewedItr!.status, 'approved');
      expect(reviewedItr.remarks, contains('Verified and approved'));
      expect(reviewedItr.reviewerName, 'Lead Architect');
    });

    test('Certificate verification updates status and certificate url', () async {
      await service.updateCertificateStatus(
        itrId: 'itr-001',
        status: 'verified',
        certificateUrl: 'https://storage.supabase.co/certificates/cert-001.pdf',
      );

      final verifiedItr = await service.getItrById('itr-001');
      expect(verifiedItr, isNotNull);
      expect(verifiedItr!.certificateStatus, 'verified');
      expect(verifiedItr.certificateUrl, contains('cert-001.pdf'));
    });
  });

  group('ITR Model Serialization & Grade Evaluation Tests', () {
    test('Correctly maps ITR from and to database Map format', () {
      final now = DateTime.now();
      final model = ItrModel(
        id: 'itr-test',
        internshipId: 'intern-test',
        studentId: 'student-test',
        studentName: 'Test Student',
        internshipTitle: 'Mobile App Developer',
        companyName: 'Apex Systems',
        status: 'submitted',
        submittedAt: now,
        evaluationScore: 88.0,
        evaluationGrade: 'A',
        certificateStatus: 'verified',
      );

      final map = model.toMap();
      expect(map['id'], 'itr-test');
      expect(map['evaluation_score'], 88.0);
      expect(map['evaluation_grade'], 'A');
      expect(map['certificate_status'], 'verified');

      final reconstructed = ItrModel.fromMap(map);
      expect(reconstructed.id, model.id);
      expect(reconstructed.studentName, model.studentName);
      expect(reconstructed.evaluationGrade, 'A');
    });
  });
}
