import 'approval_status.dart';

class ApprovalReview {
  final String id;
  final String internshipId;
  final String reviewerId;
  final ApprovalStatus status;
  final String? remarks;
  final DateTime createdAt;

  const ApprovalReview({
    required this.id,
    required this.internshipId,
    required this.reviewerId,
    required this.status,
    this.remarks,
    required this.createdAt,
  });
}