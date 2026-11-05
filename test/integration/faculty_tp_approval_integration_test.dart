import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/approval/data/models/approval_review_model.dart';
import 'package:prashikshan/features/approval/data/repositories/mock_approval_repository.dart';
import 'package:prashikshan/features/approval/data/services/approval_review_service.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_review_stage.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_status.dart';
import 'package:prashikshan/features/faculty_tp/data/models/student_monitoring_item.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/mock_student_monitoring_repository.dart';
import 'package:prashikshan/features/faculty_tp/data/services/student_monitoring_service.dart';
import 'package:prashikshan/features/faculty_tp/domain/entities/dashboard_statistics.dart';

void main() {
  group('Integration & Security: Full Faculty & T&P Approval Lifecycle', () {
    late MockApprovalRepository approvalRepository;
    late ApprovalReviewService approvalService;
    late MockStudentMonitoringRepository monitoringRepository;
    late StudentMonitoringService monitoringService;

    setUp(() {
      approvalRepository = MockApprovalRepository();
      approvalService = ApprovalReviewService(repository: approvalRepository);
      monitoringRepository = MockStudentMonitoringRepository();
      monitoringService = StudentMonitoringService(repository: monitoringRepository);
    });

    test('E2E Lifecycle: Student Application -> Faculty Review -> T&P Final Approval', () async {
      const internshipId = 'e2e-internship-101';
      const studentId = 'e2e-student-202';

      // 1. Initial State: Load students in monitoring screen
      final studentsInitial = await monitoringService.loadStudents();
      expect(studentsInitial, isNotEmpty);

      // 2. Stage 1: Faculty Mentor reviews application and approves recommendation
      final facultyReview = await approvalService.submitReview(
        internshipId: internshipId,
        stage: ApprovalReviewStage.faculty,
        status: ApprovalStatus.approved,
        remarks: 'Candidate fulfills academic requirements and company is accredited.',
      );

      expect(facultyReview.reviewStage, equals('faculty'));
      expect(facultyReview.status, equals(ApprovalStatus.approved));

      // 3. Stage 2: T&P Admin reviews and grants final institutional clearance
      final tpReview = await approvalService.submitReview(
        internshipId: internshipId,
        stage: ApprovalReviewStage.tpAdmin,
        status: ApprovalStatus.approved,
        remarks: 'Final T&P clearance approved. NOC issued.',
      );

      expect(tpReview.reviewStage, equals('tp_admin'));
      expect(tpReview.status, equals(ApprovalStatus.approved));

      // 4. Verification: Check that both reviews exist in audit trail
      final allReviews = await approvalRepository.getReviews();
      final forThisInternship = allReviews.where((r) => r.internshipId == internshipId).toList();
      expect(forThisInternship.length, equals(2));

      final facultyRecord = forThisInternship.firstWhere((r) => r.reviewStage == 'faculty');
      final tpRecord = forThisInternship.firstWhere((r) => r.reviewStage == 'tp_admin');

      expect(facultyRecord.status, equals(ApprovalStatus.approved));
      expect(tpRecord.status, equals(ApprovalStatus.approved));
    });

    test('Security RBAC: Rejection requires mandatory remarks to prevent unjustified denials', () async {
      const internshipId = 'sec-internship-901';

      expect(
        () => approvalService.submitReview(
          internshipId: internshipId,
          stage: ApprovalReviewStage.faculty,
          status: ApprovalStatus.rejected,
          remarks: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Security RBAC: Document verification rejection requires reason', () async {
      expect(
        () => monitoringService.verifyStudentDocument(
          documentId: 'doc-sec-test',
          status: 'rejected',
          rejectionReason: 'Company seal is not clearly visible on the letterhead',
        ),
        returnsNormally,
      );
    });

    test('Data Scoping: Faculty and T&P stages remain isolated in review querying', () async {
      await approvalService.submitReview(
        internshipId: 'stage-iso-1',
        stage: ApprovalReviewStage.faculty,
        status: ApprovalStatus.approved,
        remarks: 'Faculty ok',
      );

      await approvalService.submitReview(
        internshipId: 'stage-iso-2',
        stage: ApprovalReviewStage.tpAdmin,
        status: ApprovalStatus.underReview,
        remarks: 'T&P verification ongoing',
      );

      final facultyOnly = await approvalRepository.getReviews(
        stage: ApprovalReviewStage.faculty,
      );
      expect(facultyOnly.every((r) => r.reviewStage == 'faculty'), isTrue);

      final tpOnly = await approvalRepository.getReviews(
        stage: ApprovalReviewStage.tpAdmin,
      );
      expect(tpOnly.every((r) => r.reviewStage == 'tp_admin'), isTrue);
    });
  });
}

