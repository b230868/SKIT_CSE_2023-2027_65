import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/approval/data/repositories/mock_approval_repository.dart';
import 'package:prashikshan/features/approval/data/services/approval_repository_provider.dart';
import 'package:prashikshan/features/approval/data/services/approval_review_service.dart';
import 'package:prashikshan/features/approval/data/services/approval_review_service_provider.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_review_stage.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_status.dart';

void main() {
  group('ApprovalReviewService & Providers', () {
    late MockApprovalRepository mockRepository;
    late ApprovalReviewService service;

    setUp(() {
      mockRepository = MockApprovalRepository();
      service = ApprovalReviewService(repository: mockRepository);
    });

    test('submitReview creates review with mock repository', () async {
      final review = await service.submitReview(
        internshipId: 'internship-001',
        stage: ApprovalReviewStage.faculty,
        status: ApprovalStatus.approved,
        remarks: 'Approved by faculty',
      );

      expect(review.internshipId, equals('internship-001'));
      expect(review.status, equals(ApprovalStatus.approved));
      expect(review.remarks, equals('Approved by faculty'));
    });

    test('submitReview throws ArgumentError when rejecting without remarks', () async {
      expect(
        () => service.submitReview(
          internshipId: 'internship-001',
          stage: ApprovalReviewStage.faculty,
          status: ApprovalStatus.rejected,
          remarks: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('providers resolve repository and service instances', () {
      expect(ApprovalRepositoryProvider.instance, isNotNull);
      expect(ApprovalReviewServiceProvider.instance, isNotNull);
    });
  });
}
