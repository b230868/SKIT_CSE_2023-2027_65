import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../domain/entities/faculty_report_data.dart';
import '../models/mock_faculty_report_data.dart';
import 'faculty_report_repository.dart';

class SupabaseFacultyReportRepository implements FacultyReportRepository {
  final SupabaseClient? _providedClient;

  SupabaseFacultyReportRepository({
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
  Future<FacultyReportData> getReportData() async {
    final client = _client;
    if (client == null) {
      return MockFacultyReportData.sampleReport;
    }

    await AuthService.requireAuthenticatedClient(client: client);

    try {
      final response = await client.from('internships').select('''
        id,
        status,
        student_id,
        students (
          department
        ),
        approval_reviews (
          id,
          status,
          review_stage,
          created_at
        )
      ''');

      int total = 0;
      int pending = 0;
      int underReview = 0;
      int approved = 0;
      int rejected = 0;
      int facultyStage = 0;
      int tpStage = 0;
      final deptMap = <String, int>{};

      for (final item in response as List) {
        total++;
        final map = Map<String, dynamic>.from(item as Map);

        final student = map['students'] is Map
            ? Map<String, dynamic>.from(map['students'] as Map)
            : <String, dynamic>{};
        final dept = student['department'] as String? ?? 'General';
        deptMap[dept] = (deptMap[dept] ?? 0) + 1;

        final reviews = (map['approval_reviews'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

        reviews.sort((a, b) => DateTime.parse(b['created_at'] as String)
            .compareTo(DateTime.parse(a['created_at'] as String)));

        if (reviews.isNotEmpty) {
          final latest = reviews.first;
          final status = latest['status'] as String? ?? 'pending';
          final stage = latest['review_stage'] as String? ?? 'faculty';

          if (stage == 'faculty') facultyStage++;
          if (stage == 'tp_admin') tpStage++;

          if (status == 'pending') {
            pending++;
          } else if (status == 'under_review') {
            underReview++;
          } else if (status == 'approved') {
            approved++;
          } else if (status == 'rejected') {
            rejected++;
          }
        } else {
          pending++;
          facultyStage++;
        }
      }

      return FacultyReportData(
        totalInternships: total,
        pendingApprovals: pending,
        underReviewApprovals: underReview,
        approvedInternships: approved,
        rejectedApplications: rejected,
        facultyStageCount: facultyStage,
        tpStageCount: tpStage,
        departmentSummary: deptMap,
      );
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.message.toLowerCase().contains('permission denied')) {
        throw const UnauthorizedException(
          'Your account does not have permission to access report data.',
        );
      }
      rethrow;
    }
  }
}
