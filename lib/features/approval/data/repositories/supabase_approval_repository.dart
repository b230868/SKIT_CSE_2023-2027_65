import 'package:supabase_flutter/supabase_flutter.dart';

<<<<<<< HEAD
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
=======
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
>>>>>>> origin/main
  }

  @override
  Future<List<ApprovalReviewModel>> getReviews({
    ApprovalStatus? status,
    ApprovalReviewStage? stage,
  }) async {
<<<<<<< HEAD
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
=======
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
>>>>>>> origin/main
  }

  @override
  Future<ApprovalReviewModel> createReview({
    required String internshipId,
    required String reviewerId,
    required ApprovalReviewStage stage,
    required ApprovalStatus status,
    String? remarks,
  }) async {
<<<<<<< HEAD
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
=======
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
>>>>>>> origin/main
  }

  @override
  Future<ApprovalReviewModel> updateReview({
    required String reviewId,
    required ApprovalStatus status,
    String? remarks,
  }) async {
<<<<<<< HEAD
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
=======
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
>>>>>>> origin/main
  }

  @override
  Future<List<ApprovalRequestModel>> getApprovalRequests({
    ApprovalStatus? status,
    ApprovalReviewStage? stage,
  }) async {
<<<<<<< HEAD
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
=======
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
>>>>>>> origin/main
  }

  @override
  Future<ApprovalRequestModel?> getApprovalRequestDetails(
    String internshipId,
  ) async {
    final requests = await getApprovalRequests();
<<<<<<< HEAD

    for (final request in requests) {
      if (request.internshipId == internshipId) {
        return request;
      }
    }

=======
    for (final request in requests) {
      if (request.internshipId == internshipId) return request;
    }
>>>>>>> origin/main
    return null;
  }
}
