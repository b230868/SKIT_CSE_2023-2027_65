import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/approval/data/models/approval_review_model.dart';
import 'package:prashikshan/features/approval/data/repositories/mock_approval_repository.dart';
import 'package:prashikshan/features/approval/data/services/approval_review_service.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_review_stage.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_status.dart';

void main() {
  group('Approval Workflow & Review Service Unit Tests', () {
    late MockApprovalRepository mockRepository;
    late ApprovalReviewService approvalService;

    setUp(() {
      mockRepository = MockApprovalRepository();
      approvalService = ApprovalReviewService(repository: mockRepository);
    });

    test('submitReview creates review with valid parameters', () async {
      final review = await approvalService.submitReview(
        internshipId: 'internship-test-01',
        stage: ApprovalReviewStage.faculty,
        status: ApprovalStatus.approved,
        remarks: 'Documents verified and eligible for internship',
      );

      expect(review, isNotNull);
      expect(review.internshipId, equals('internship-test-01'));
      expect(review.status, equals(ApprovalStatus.approved));
      expect(review.reviewStage, equals('faculty'));
      expect(review.remarks, equals('Documents verified and eligible for internship'));
    });

    test('submitReview throws ArgumentError when rejecting without remarks', () async {
      expect(
        () => approvalService.submitReview(
          internshipId: 'internship-test-02',
          stage: ApprovalReviewStage.faculty,
          status: ApprovalStatus.rejected,
          remarks: '',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => approvalService.submitReview(
          internshipId: 'internship-test-02',
          stage: ApprovalReviewStage.faculty,
          status: ApprovalStatus.rejected,
          remarks: null,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('submitReview supports T&P Admin final approval stage', () async {
      final review = await approvalService.submitReview(
        internshipId: 'internship-test-03',
        stage: ApprovalReviewStage.tpAdmin,
        status: ApprovalStatus.approved,
        remarks: 'Final T&P clearance granted',
      );

      expect(review.reviewStage, equals('tp_admin'));
      expect(review.status, equals(ApprovalStatus.approved));
    });

    test('mock repository getReviews filters by stage and status', () async {
      await mockRepository.createReview(
        internshipId: 'intern-filter-1',
        reviewerId: 'reviewer-1',
        stage: ApprovalReviewStage.faculty,
        status: ApprovalStatus.approved,
        remarks: 'Ok',
      );

      await mockRepository.createReview(
        internshipId: 'intern-filter-2',
        reviewerId: 'reviewer-2',
        stage: ApprovalReviewStage.tpAdmin,
        status: ApprovalStatus.pending,
      );

      final facultyReviews = await mockRepository.getReviews(
        stage: ApprovalReviewStage.faculty,
      );
      expect(facultyReviews.any((r) => r.internshipId == 'intern-filter-1'), isTrue);

      final pendingReviews = await mockRepository.getReviews(
        status: ApprovalStatus.pending,
      );
      expect(pendingReviews.any((r) => r.internshipId == 'intern-filter-2'), isTrue);
    });
  });

  group('Approval Review Model & Entity Tests', () {
    test('ApprovalReviewModel serialization toMap and fromMap match', () {
      final now = DateTime.now();
      final model = ApprovalReviewModel(
        id: 'rev-uuid-001',
        internshipId: 'intern-uuid-001',
        reviewerId: 'user-uuid-001',
        reviewStage: 'faculty',
        status: ApprovalStatus.approved,
        remarks: 'All documents confirmed',
        createdAt: now,
      );

      final map = model.toMap();
      expect(map['id'], equals('rev-uuid-001'));
      expect(map['internship_id'], equals('intern-uuid-001'));
      expect(map['review_stage'], equals('faculty'));
      expect(map['status'], equals('approved'));
      expect(map['remarks'], equals('All documents confirmed'));

      final reconstructed = ApprovalReviewModel.fromMap(map);
      expect(reconstructed.id, equals(model.id));
      expect(reconstructed.status, equals(ApprovalStatus.approved));
      expect(reconstructed.reviewStage, equals('faculty'));
    });

    test('ApprovalStatus extension returns correct displayName and values', () {
      expect(ApprovalStatus.pending.value, equals('pending'));
      expect(ApprovalStatus.pending.displayName, equals('Pending'));

      expect(ApprovalStatus.underReview.value, equals('under_review'));
      expect(ApprovalStatus.underReview.displayName, equals('Under Review'));

      expect(ApprovalStatus.approved.value, equals('approved'));
      expect(ApprovalStatus.approved.displayName, equals('Approved'));

      expect(ApprovalStatus.rejected.value, equals('rejected'));
      expect(ApprovalStatus.rejected.displayName, equals('Rejected'));
    });

    test('ApprovalReviewStage extension returns correct database values', () {
      expect(ApprovalReviewStage.faculty.value, equals('faculty'));
      expect(ApprovalReviewStage.tpAdmin.value, equals('tp_admin'));
    });
  });
}

