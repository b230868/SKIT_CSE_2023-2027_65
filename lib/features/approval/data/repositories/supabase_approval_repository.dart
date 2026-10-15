import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../models/approval_request_model.dart';
import '../models/approval_review_model.dart';
import '../../domain/entities/approval_review_stage.dart';
import '../../domain/entities/approval_status.dart';
import 'approval_repository.dart';

class SupabaseApprovalRepository implements ApprovalRepository {
  final SupabaseClient? _providedClient;

  SupabaseApprovalRepository({SupabaseClient? client})
    : _providedClient = client;

  SupabaseClient? get _client {
    if (_providedClient != null) return _providedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<SupabaseClient> _requireAuth() {
    return AuthService.requireAuthenticatedClient(client: _client);
  }

  @override
  Future<List<ApprovalReviewModel>> getReviews({
    ApprovalStatus? status,
    ApprovalReviewStage? stage,
  }) async {
    final client = await _requireAuth();
    try {
      var query = client.from('approval_reviews').select();

      if (status != null) {
        query = query.eq('status', status.value);
      }

      if (stage != null) {
        query = query.eq('review_stage', stage.value);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map(
            (item) => ApprovalReviewModel.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      if (e.code == '42501' ||
          e.message.toLowerCase().contains('permission denied')) {
        throw const UnauthorizedException(
          'Your account does not have permission to access approval data.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<ApprovalReviewModel> createReview({
    required String internshipId,
    required String reviewerId,
    required ApprovalReviewStage stage,
    required ApprovalStatus status,
    String? remarks,
  }) async {
    final client = await _requireAuth();
    try {
      final response = await client
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

      return ApprovalReviewModel.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.code == '42501' ||
          e.message.toLowerCase().contains('permission denied')) {
        throw const UnauthorizedException(
          'Your account does not have permission to access approval data.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<ApprovalReviewModel> updateReview({
    required String reviewId,
    required ApprovalStatus status,
    String? remarks,
  }) async {
    final client = await _requireAuth();
    try {
      final response = await client
          .from('approval_reviews')
          .update({'status': status.value, 'remarks': remarks})
          .eq('id', reviewId)
          .select()
          .single();

      return ApprovalReviewModel.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.code == '42501' ||
          e.message.toLowerCase().contains('permission denied')) {
        throw const UnauthorizedException(
          'Your account does not have permission to access approval data.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<ApprovalRequestModel>> getApprovalRequests({
    ApprovalStatus? status,
    ApprovalReviewStage? stage,
  }) async {
    final client = await _requireAuth();
    try {
      final response = await client
          .from('internships')
          .select('''
            id,
            student_id,
            industry_id,
            status,
            internship_title,
            created_at,
            students (
              id,
              roll_number,
              user_id,
              profiles:user_id (
                full_name
              )
            ),
            industries (
              id,
              name
            ),
            approval_reviews (
              id,
              status,
              review_stage,
              remarks,
              created_at
            )
          ''')
          .order('created_at', ascending: false);

      final requests = <ApprovalRequestModel>[];

      for (final item in response as List) {
        final map = Map<String, dynamic>.from(item as Map);

        final reviews = (map['approval_reviews'] as List? ?? [])
            .map((review) => Map<String, dynamic>.from(review as Map))
            .toList();

        reviews.sort(
          (a, b) =>
              DateTime.parse(b['created_at'] as String)
                  .compareTo(DateTime.parse(a['created_at'] as String)),
        );

        ApprovalStatus latestStatus = ApprovalStatus.pending;

        if (reviews.isNotEmpty) {
          latestStatus = ApprovalStatus.values.firstWhere(
            (value) => value.value == reviews.first['status'],
            orElse: () => ApprovalStatus.pending,
          );
        }

        if (stage == ApprovalReviewStage.faculty) {
          final hasTpReview = reviews.any(
            (review) => review['review_stage'] == 'tp_admin',
          );

          if (hasTpReview) {
            continue;
          }
        }

        if (stage == ApprovalReviewStage.tpAdmin) {
          final facultyApproved = reviews.any(
            (review) =>
                review['review_stage'] == 'faculty' &&
                review['status'] == 'approved',
          );

          final hasTpReview = reviews.any(
            (review) => review['review_stage'] == 'tp_admin',
          );

          if (!facultyApproved || hasTpReview) {
            continue;
          }
        }

        if (status != null && latestStatus != status) {
          continue;
        }

        final student = map['students'] is Map
            ? Map<String, dynamic>.from(map['students'] as Map)
            : <String, dynamic>{};

        final profile = student['profiles'] is Map
            ? Map<String, dynamic>.from(student['profiles'] as Map)
            : <String, dynamic>{};

        final industry = map['industries'] is Map
            ? Map<String, dynamic>.from(map['industries'] as Map)
            : <String, dynamic>{};

        requests.add(
          ApprovalRequestModel(
            internshipId: map['id'] as String,
            studentId: map['student_id'] as String,
            studentName: profile['full_name'] as String? ?? 'Unknown Student',
            rollNumber: student['roll_number'] as String? ?? '',
            internshipTitle:
                map['internship_title'] as String? ?? 'Untitled Internship',
            industryId: map['industry_id'] as String,
            industryName: industry['name'] as String? ?? 'Unknown Industry',
            internshipStatus: map['status'] as String? ?? 'unknown',
            approvalStatus: latestStatus,
          ),
        );
      }
      return requests;
    } on PostgrestException catch (e) {
      if (e.code == '42501' ||
          e.message.toLowerCase().contains('permission denied')) {
        throw const UnauthorizedException(
          'Your account does not have permission to access approval data.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<ApprovalRequestModel?> getApprovalRequestDetails(
    String internshipId,
  ) async {
    final requests = await getApprovalRequests();

    for (final request in requests) {
      if (request.internshipId == internshipId) {
        return request;
      }
    }

    return null;
  }
}
