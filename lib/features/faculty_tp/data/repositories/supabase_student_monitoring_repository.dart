
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../models/mock_student_monitoring_data.dart';
import '../models/student_monitoring_item.dart';
import 'student_monitoring_repository.dart';

class SupabaseStudentMonitoringRepository
    implements StudentMonitoringRepository {
  final SupabaseClient? _providedClient;

  SupabaseStudentMonitoringRepository({
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
  Future<List<StudentMonitoringItem>> getStudents() async {
    final client = _client;
    if (client == null) {
      return MockStudentMonitoringData.students;
    }

    await AuthService.requireAuthenticatedClient(client: client);

    try {
      final response = await client.from('internships').select('''
        id,
        internship_title,
        status,
        student_id,
        created_at,
        students (
          id,
          roll_number,
          user_id,
          profiles:user_id (
            full_name
          )
        ),
        approval_reviews (
          id,
          status,
          review_stage,
          created_at
        )
      ''').order('created_at', ascending: false);

      final items = <StudentMonitoringItem>[];

      for (final item in response as List) {
        final map = Map<String, dynamic>.from(item as Map);

        final student = map['students'] is Map
            ? Map<String, dynamic>.from(map['students'] as Map)
            : <String, dynamic>{};

        final profile = student['profiles'] is Map
            ? Map<String, dynamic>.from(student['profiles'] as Map)
            : <String, dynamic>{};

        final studentName = profile['full_name'] as String? ?? 'Unknown Student';
        final internshipTitle =
            map['internship_title'] as String? ?? 'Untitled Internship';
        final internshipId = map['id'] as String? ?? '';
        final studentId =
            map['student_id'] as String? ?? (student['id'] as String? ?? '');

        final reviews = (map['approval_reviews'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

        reviews.sort((a, b) => DateTime.parse(b['created_at'] as String)
            .compareTo(DateTime.parse(a['created_at'] as String)));

        final status = reviews.isNotEmpty
            ? (reviews.first['status'] as String? ?? 'pending')
            : (map['status'] as String? ?? 'pending');

        items.add(
          StudentMonitoringItem(
            studentId: studentId,
            studentName: studentName,
            internshipId: internshipId,
            internshipTitle: internshipTitle,
            applicationStatus: status,
          ),
        );
      }

      return items;
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.message.toLowerCase().contains('permission denied')) {
        throw const UnauthorizedException(
          'Your account does not have permission to access student monitoring data.',
        );
      }
      rethrow;
    }
  }
}


