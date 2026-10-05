import '../models/approval_request_model.dart';
import '../models/approval_review_model.dart';
import '../../domain/entities/approval_review_stage.dart';
import '../../domain/entities/approval_status.dart';

abstract class ApprovalRepository {
  Future<List<ApprovalReviewModel>> getReviews({
    ApprovalStatus? status,
    ApprovalReviewStage? stage,
  });

  Future<ApprovalReviewModel> createReview({
    required String internshipId,
    required String reviewerId,
    required ApprovalReviewStage stage,
    required ApprovalStatus status,
    String? remarks,
  });

  Future<ApprovalReviewModel> updateReview({
    required String reviewId,
    required ApprovalStatus status,
    String? remarks,
  });

  Future<List<ApprovalRequestModel>> getApprovalRequests({
    ApprovalStatus? status,
    ApprovalReviewStage? stage,
  });

  Future<ApprovalRequestModel?> getApprovalRequestDetails(
    String internshipId,
  );
}