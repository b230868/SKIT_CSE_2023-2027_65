import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../approval/domain/entities/approval_review_stage.dart';
import '../../domain/entities/dashboard_statistics.dart';
import 'faculty_dashboard_repository.dart';

class SupabaseFacultyDashboardRepository implements FacultyDashboardRepository {
  final SupabaseClient? _providedClient;

  SupabaseFacultyDashboardRepository({SupabaseClient? client})
    : _providedClient = client;

  SupabaseClient? get _client {
    if (_providedClient != null) return _providedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DashboardStatistics> getDashboardStatistics({
    ApprovalReviewStage? stage,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase client is not initialized.');
    }

    await AuthService.requireAuthenticatedClient(client: client);

    try {
      ApprovalReviewStage? effectiveStage = stage;
      if (effectiveStage == null) {
        final profile = await AuthService(client: client)
            .getCurrentUserProfile();
        if (profile?.role == AppRole.tpOfficer) {
          effectiveStage = ApprovalReviewStage.tpAdmin;
        } else {
          effectiveStage = ApprovalReviewStage.faculty;
        }
      }

      final response = await client.from('internships').select('''
        id,
        status,
        student_id,
        approval_reviews (
          id,
          status,
          review_stage,
          created_at
        )
      ''');

      int pendingApprovals = 0;
      int approvedInternships = 0;
      int rejectedApplications = 0;
      final Set<String> studentsNeedingReview = {};

      for (final item in response as List) {
        final map = Map<String, dynamic>.from(item as Map);
        final studentId = map['student_id'] as String?;
        final reviews = (map['approval_reviews'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

        reviews.sort((a, b) {
          final bDate =
              DateTime.tryParse(b['created_at']?.toString() ?? '') ??
              DateTime(1970);
          final aDate =
              DateTime.tryParse(a['created_at']?.toString() ?? '') ??
              DateTime(1970);
          return bDate.compareTo(aDate);
        });

        if (effectiveStage == ApprovalReviewStage.faculty) {
          final hasTpReview = reviews.any(
            (review) => review['review_stage'] == 'tp_admin',
          );

          if (hasTpReview) {
            approvedInternships++;
            continue;
          }

          final facultyReviews = reviews
              .where((r) => r['review_stage'] == 'faculty')
              .toList();

          if (facultyReviews.isEmpty) {
            pendingApprovals++;
            if (studentId != null) {
              studentsNeedingReview.add(studentId);
            }
          } else {
            final latestStatus =
                facultyReviews.first['status'] as String? ?? 'pending';
            if (latestStatus == 'approved') {
              approvedInternships++;
            } else if (latestStatus == 'rejected') {
              rejectedApplications++;
            } else {
              pendingApprovals++;
              if (studentId != null) {
                studentsNeedingReview.add(studentId);
              }
            }
          }
        } else if (effectiveStage == ApprovalReviewStage.tpAdmin) {
          final facultyApproved = reviews.any(
            (review) =>
                review['review_stage'] == 'faculty' &&
                review['status'] == 'approved',
          );

          if (!facultyApproved) {
            continue;
          }

          final tpReviews = reviews
              .where((r) => r['review_stage'] == 'tp_admin')
              .toList();

          if (tpReviews.isEmpty) {
            pendingApprovals++;
            if (studentId != null) {
              studentsNeedingReview.add(studentId);
            }
          } else {
            final latestStatus =
                tpReviews.first['status'] as String? ?? 'pending';
            if (latestStatus == 'approved') {
              approvedInternships++;
            } else if (latestStatus == 'rejected') {
              rejectedApplications++;
            } else {
              pendingApprovals++;
              if (studentId != null) {
                studentsNeedingReview.add(studentId);
              }
            }
          }
        }
      }

      return DashboardStatistics(
        pendingApprovals: pendingApprovals,
        approvedInternships: approvedInternships,
        rejectedApplications: rejectedApplications,
        studentsRequiringReview: studentsNeedingReview.length,
      );
    } on PostgrestException catch (e) {
      if (e.code == '42501' ||
          e.message.toLowerCase().contains('permission denied')) {
        throw const UnauthorizedException(
          'Your account does not have permission to access dashboard statistics.',
        );
      }
      rethrow;
    }
  }
}
