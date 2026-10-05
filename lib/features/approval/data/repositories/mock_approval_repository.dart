import '../models/approval_request_model.dart';
import '../models/approval_review_model.dart';
import '../../domain/entities/approval_review_stage.dart';
import '../../domain/entities/approval_status.dart';
import 'approval_repository.dart';

class MockApprovalRepository implements ApprovalRepository {
  final List<ApprovalReviewModel> _reviews = [
    ApprovalReviewModel(
      id: 'review-001',
      internshipId: 'internship-001',
      reviewerId: 'faculty-001',
      reviewStage: 'faculty',
      status: ApprovalStatus.pending,
      remarks: null,
      createdAt: DateTime(2026, 9, 1),
    ),
    ApprovalReviewModel(
      id: 'review-002',
      internshipId: 'internship-002',
      reviewerId: 'faculty-002',
      reviewStage: 'faculty',
      status: ApprovalStatus.underReview,
      remarks: 'Documents are being reviewed.',
      createdAt: DateTime(2026, 9, 2),
    ),
    ApprovalReviewModel(
      id: 'review-003',
      internshipId: 'internship-003',
      reviewerId: 'faculty-003',
      reviewStage: 'faculty',
      status: ApprovalStatus.approved,
      remarks: 'Faculty approval completed.',
      createdAt: DateTime(2026, 9, 3),
    ),
    ApprovalReviewModel(
      id: 'review-004',
      internshipId: 'internship-004',
      reviewerId: 'tp-001',
      reviewStage: 'tp_admin',
      status: ApprovalStatus.rejected,
      remarks: 'Required documents are incomplete.',
      createdAt: DateTime(2026, 9, 4),
    ),
  ];

  final List<ApprovalRequestModel> _requests = [
    ApprovalRequestModel(
      internshipId: 'internship-001',
      studentId: 'student-001',
      studentName: 'Demo Student 1',
      rollNumber: 'PRK001',
      internshipTitle: 'Software Development Internship',
      industryId: 'industry-001',
      industryName: 'Demo Technology Ltd.',
      internshipStatus: 'pending',
      approvalStatus: ApprovalStatus.pending,
    ),
    ApprovalRequestModel(
      internshipId: 'internship-002',
      studentId: 'student-002',
      studentName: 'Demo Student 2',
      rollNumber: 'PRK002',
      internshipTitle: 'Data Analytics Internship',
      industryId: 'industry-002',
      industryName: 'Demo Analytics Pvt. Ltd.',
      internshipStatus: 'active',
      approvalStatus: ApprovalStatus.underReview,
    ),
    ApprovalRequestModel(
      internshipId: 'internship-003',
      studentId: 'student-003',
      studentName: 'Demo Student 3',
      rollNumber: 'PRK003',
      internshipTitle: 'Web Development Internship',
      industryId: 'industry-003',
      industryName: 'Demo Web Solutions',
      internshipStatus: 'approved',
      approvalStatus: ApprovalStatus.approved,
    ),
    ApprovalRequestModel(
      internshipId: 'internship-004',
      studentId: 'student-004',
      studentName: 'Demo Student 4',
      rollNumber: 'PRK004',
      internshipTitle: 'Cloud Computing Internship',
      industryId: 'industry-004',
      industryName: 'Demo Cloud Systems',
      internshipStatus: 'rejected',
      approvalStatus: ApprovalStatus.rejected,
    ),
  ];

  @override
  Future<List<ApprovalReviewModel>> getReviews({
    ApprovalStatus? status,
    ApprovalReviewStage? stage,
  }) async {
    return List.unmodifiable(
      _reviews.where((review) {
        final matchesStatus =
            status == null || review.status == status;

        final matchesStage =
            stage == null ||
            review.reviewStage == stage.value;

        return matchesStatus && matchesStage;
      }),
    );
  }

  @override
  Future<ApprovalReviewModel> createReview({
    required String internshipId,
    required String reviewerId,
    required ApprovalReviewStage stage,
    required ApprovalStatus status,
    String? remarks,
  }) async {
    final review = ApprovalReviewModel(
      id: 'review-${_reviews.length + 1}',
      internshipId: internshipId,
      reviewerId: reviewerId,
      reviewStage: stage.value,
      status: status,
      remarks: remarks,
      createdAt: DateTime.now(),
    );

    _reviews.add(review);
    return review;
  }

  @override
  Future<ApprovalReviewModel> updateReview({
    required String reviewId,
    required ApprovalStatus status,
    String? remarks,
  }) async {
    final index = _reviews.indexWhere(
      (review) => review.id == reviewId,
    );

    if (index == -1) {
      throw StateError('Approval review not found.');
    }

    final existing = _reviews[index];

    final updated = ApprovalReviewModel(
      id: existing.id,
      internshipId: existing.internshipId,
      reviewerId: existing.reviewerId,
      reviewStage: existing.reviewStage,
      status: status,
      remarks: remarks,
      createdAt: existing.createdAt,
    );

    _reviews[index] = updated;
    return updated;
  }

  @override
  Future<List<ApprovalRequestModel>> getApprovalRequests({
    ApprovalStatus? status,
    ApprovalReviewStage? stage,
  }) async {
    final filtered = _requests.where((request) {
      if (status != null &&
          request.approvalStatus != status) {
        return false;
      }

      if (stage == ApprovalReviewStage.tpAdmin) {
        return request.approvalStatus ==
            ApprovalStatus.approved;
      }

      return true;
    }).toList();

    return List.unmodifiable(filtered);
  }

  @override
  Future<ApprovalRequestModel?> getApprovalRequestDetails(
    String internshipId,
  ) async {
    for (final request in _requests) {
      if (request.internshipId == internshipId) {
        return request;
      }
    }

    return null;
  }
}