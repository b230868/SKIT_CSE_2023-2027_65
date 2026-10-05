import '../../domain/entities/approval_status.dart';

class ApprovalReviewModel {
  final String id;
  final String internshipId;
  final String reviewerId;
  final String reviewStage;
  final ApprovalStatus status;
  final String? remarks;
  final DateTime createdAt;

  const ApprovalReviewModel({
    required this.id,
    required this.internshipId,
    required this.reviewerId,
    required this.reviewStage,
    required this.status,
    this.remarks,
    required this.createdAt,
  });

  factory ApprovalReviewModel.fromMap(Map<String, dynamic> map) {
    return ApprovalReviewModel(
      id: map['id'] as String,
      internshipId: map['internship_id'] as String,
      reviewerId: map['reviewer_id'] as String,
      reviewStage: map['review_stage'] as String? ?? 'faculty',
      status: ApprovalStatus.values.firstWhere(
        (status) => status.value == map['status'],
        orElse: () => ApprovalStatus.pending,
      ),
      remarks: map['remarks'] as String?,
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'internship_id': internshipId,
      'reviewer_id': reviewerId,
      'review_stage': reviewStage,
      'status': status.value,
      'remarks': remarks,
      'created_at': createdAt.toIso8601String(),
    };
  }
}