import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/approval_review_stage.dart';
import '../../domain/entities/approval_status.dart';
import '../models/approval_request_model.dart';
import '../models/approval_review_model.dart';
import 'approval_repository.dart';

class SupabaseApprovalRepository implements ApprovalRepository {
  final SupabaseClient _client;

  SupabaseApprovalRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _currentUserId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to review internship applications.');
    }
    return user.id;
  }

  @override
  Future<List<ApprovalReviewModel>> getReviews({
    ApprovalStatus? status,
    ApprovalReviewStage? stage,
  }) async {
    var query = _client.from('approval_reviews').select();
    if (status != null) query = query.eq('status', status.value);
    if (stage != null) query = query.eq('review_stage', stage.value);
    final rows = await query.order('created_at', ascending: false);
    return rows
        .map<ApprovalReviewModel>(
          (row) => ApprovalReviewModel.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  @override
  Future<ApprovalReviewModel> createReview({
    required String internshipId,
    required String reviewerId,
    required ApprovalReviewStage stage,
    required ApprovalStatus status,
    String? remarks,
  }) async {
    if (reviewerId != _currentUserId) {
      throw const AuthException('You can only submit a review for yourself.');
    }

    final row = await _client
        .from('approval_reviews')
        .insert({
          'internship_id': internshipId,
          'reviewer_id': reviewerId,
          'review_stage': stage.value,
          'status': status.value,
          'remarks': remarks,
        })
        .select()
        .single();

    if (status == ApprovalStatus.approved ||
        status == ApprovalStatus.rejected) {
      await _client
          .from('internships')
          .update({'status': status.value})
          .eq('id', internshipId);
    }

    return ApprovalReviewModel.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<ApprovalReviewModel> updateReview({
    required String reviewId,
    required ApprovalStatus status,
    String? remarks,
  }) async {
    final row = await _client
        .from('approval_reviews')
        .update({
          'status': status.value,
          'remarks': remarks,
        })
        .eq('id', reviewId)
        .eq('reviewer_id', _currentUserId)
        .select()
        .single();

    final review = ApprovalReviewModel.fromMap(
      Map<String, dynamic>.from(row),
    );
    if (status == ApprovalStatus.approved ||
        status == ApprovalStatus.rejected) {
      await _client
          .from('internships')
          .update({'status': status.value})
          .eq('id', review.internshipId);
    }
    return review;
  }

  @override
  Future<List<ApprovalRequestModel>> getApprovalRequests({
    ApprovalStatus? status,
    ApprovalReviewStage? stage,
  }) async {
    final internships = await _client
        .from('internships')
        .select('id, student_id, title, company_name, status')
        .order('created_at', ascending: false);
    if (internships.isEmpty) return [];

    final internshipRows = internships
        .map<Map<String, dynamic>>(
          (row) => Map<String, dynamic>.from(row),
        )
        .toList();
    final internshipIds =
        internshipRows.map((row) => row['id'] as String).toList();
    final studentIds = internshipRows
        .map((row) => row['student_id'] as String)
        .toSet()
        .toList();

    final profiles = await _client
        .from('profiles')
        .select('id, full_name, enrollment_no')
        .inFilter('id', studentIds);
    final profileById = {
      for (final profile in profiles)
        profile['id'] as String: Map<String, dynamic>.from(profile),
    };

    final reviewRows = await _client
        .from('approval_reviews')
        .select()
        .inFilter('internship_id', internshipIds)
        .order('created_at', ascending: false);
    final reviewsByInternship = <String, List<ApprovalReviewModel>>{};
    for (final row in reviewRows) {
      final review = ApprovalReviewModel.fromMap(
        Map<String, dynamic>.from(row),
      );
      reviewsByInternship
          .putIfAbsent(review.internshipId, () => [])
          .add(review);
    }

    final requests = <ApprovalRequestModel>[];
    for (final internship in internshipRows) {
      final id = internship['id'] as String;
      final studentId = internship['student_id'] as String;
      final profile = profileById[studentId] ?? const <String, dynamic>{};
      final reviews = reviewsByInternship[id] ?? const <ApprovalReviewModel>[];
      final facultyReviews = reviews
          .where((review) => review.reviewStage == 'faculty')
          .toList();
      final tpReviews = reviews
          .where((review) => review.reviewStage == 'tp_admin')
          .toList();
      final stageReviews = stage == ApprovalReviewStage.tpAdmin
          ? tpReviews
          : facultyReviews;
      final stageStatus = stageReviews.isNotEmpty
          ? stageReviews.first.status
          : stage == ApprovalReviewStage.tpAdmin
              ? (facultyReviews.isNotEmpty &&
                      facultyReviews.first.status == ApprovalStatus.approved
                  ? ApprovalStatus.approved
                  : ApprovalStatus.pending)
              : ApprovalStatus.pending;

      if (stage == ApprovalReviewStage.tpAdmin &&
          (facultyReviews.isEmpty ||
              facultyReviews.first.status != ApprovalStatus.approved)) {
        continue;
      }
      if (stage == ApprovalReviewStage.tpAdmin &&
          tpReviews.isNotEmpty &&
          (stageStatus == ApprovalStatus.approved ||
              stageStatus == ApprovalStatus.rejected)) {
        continue;
      }
      if (status != null && stageStatus != status) continue;

      requests.add(
        ApprovalRequestModel(
          internshipId: id,
          studentId: studentId,
          studentName: profile['full_name'] as String? ?? 'Unknown Student',
          rollNumber: profile['enrollment_no'] as String? ?? '',
          internshipTitle: internship['title'] as String? ?? 'Internship',
          industryId: '',
          industryName: internship['company_name'] as String? ?? 'Unknown Company',
          internshipStatus: internship['status'] as String? ?? 'pending',
          approvalStatus: stageStatus,
        ),
      );
    }
    return requests;
  }

  @override
  Future<ApprovalRequestModel?> getApprovalRequestDetails(
    String internshipId,
  ) async {
    final requests = await getApprovalRequests();
    for (final request in requests) {
      if (request.internshipId == internshipId) return request;
    }
    return null;
  }
}
