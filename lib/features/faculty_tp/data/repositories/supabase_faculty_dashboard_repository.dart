import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../domain/entities/dashboard_statistics.dart';
import '../models/mock_dashboard_data.dart';
import 'faculty_dashboard_repository.dart';

class SupabaseFacultyDashboardRepository
    implements FacultyDashboardRepository {
  final SupabaseClient? _providedClient;

  SupabaseFacultyDashboardRepository({
    SupabaseClient? client,
  }) : _providedClient = client;

  SupabaseClient? get _client {
    if (_providedClient != null) return _providedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DashboardStatistics> getDashboardStatistics() async {
    final client = _client;
    if (client == null) {
      return MockDashboardData.statistics;
    }

    await AuthService.requireAuthenticatedClient(client: client);

    try {
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

        reviews.sort((a, b) => DateTime.parse(b['created_at'] as String)
            .compareTo(DateTime.parse(a['created_at'] as String)));

        String latestStatus = 'pending';
        if (reviews.isNotEmpty) {
          latestStatus = reviews.first['status'] as String? ?? 'pending';
        }

        if (latestStatus == 'pending' || latestStatus == 'under_review') {
          pendingApprovals++;
          if (studentId != null) {
            studentsNeedingReview.add(studentId);
          }
        } else if (latestStatus == 'approved') {
          approvedInternships++;
        } else if (latestStatus == 'rejected') {
          rejectedApplications++;
        }
      }

      return DashboardStatistics(
        pendingApprovals: pendingApprovals,
        approvedInternships: approvedInternships,
        rejectedApplications: rejectedApplications,
        studentsRequiringReview: studentsNeedingReview.length,
      );
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.message.toLowerCase().contains('permission denied')) {
        throw const UnauthorizedException(
          'Your account does not have permission to access dashboard data.',
        );
      }
      rethrow;
    }
  }
}