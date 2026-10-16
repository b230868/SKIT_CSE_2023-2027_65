import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_review_stage.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_status.dart';

void main() {
  group('ApprovalStatus & ApprovalReviewStage Domain Entities', () {
    test('ApprovalStatus maps to exact database values', () {
      expect(ApprovalStatus.pending.value, equals('pending'));
      expect(ApprovalStatus.underReview.value, equals('under_review'));
      expect(ApprovalStatus.approved.value, equals('approved'));
      expect(ApprovalStatus.rejected.value, equals('rejected'));
    });

    test('ApprovalStatus maps to exact display names', () {
      expect(ApprovalStatus.pending.displayName, equals('Pending'));
      expect(ApprovalStatus.underReview.displayName, equals('Under Review'));
      expect(ApprovalStatus.approved.displayName, equals('Approved'));
      expect(ApprovalStatus.rejected.displayName, equals('Rejected'));
    });

    test('ApprovalReviewStage maps to exact database values', () {
      expect(ApprovalReviewStage.faculty.value, equals('faculty'));
      expect(ApprovalReviewStage.tpAdmin.value, equals('tp_admin'));
    });
  });
}
