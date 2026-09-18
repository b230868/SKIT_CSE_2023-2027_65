import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/industry_internship_model.dart';
import 'industry_repository.dart';

class SupabaseIndustryRepository
    implements IndustryRepository {
  SupabaseIndustryRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String?> _getIndustryId() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final row = await _client
        .from('industry_users')
        .select('industry_id')
        .eq('user_id', user.id)
        .maybeSingle();

    return row?['industry_id']?.toString();
  }

  @override
  Future<List<IndustryInternshipModel>>
      getIndustryInternships() async {
    final industryId = await _getIndustryId();

    if (industryId == null) {
      return [];
    }

    final internships = await _client
        .from('internships')
        .select('''
          id,
          internship_title,
          status,
          students (
            profiles (
              full_name
            )
          )
        ''')
        .eq('industry_id', industryId)
        .order('created_at', ascending: false);

    final result = <IndustryInternshipModel>[];

    for (final raw in internships) {
      final internship =
          Map<String, dynamic>.from(raw);

      final student =
          internship['students'] as Map<String, dynamic>?;

      final profile =
          student?['profiles'] as Map<String, dynamic>?;

      final internshipId =
          internship['id'].toString();

      final itrResponse = await _client
          .from('itrs')
          .select('status')
          .eq('internship_id', internshipId)
          .order('created_at', ascending: false)
          .limit(1);

      final itrStatus = itrResponse.isNotEmpty
          ? itrResponse.first['status']?.toString() ??
              'draft'
          : 'draft';

      final evaluationResponse = await _client
          .from('evaluations')
          .select('status')
          .eq('internship_id', internshipId)
          .order('created_at', ascending: false)
          .limit(1);

      final evaluationStatus =
          evaluationResponse.isNotEmpty
              ? evaluationResponse.first['status']
                      ?.toString() ??
                  'pending'
              : 'pending';

      final progressResponse = await _client
          .from('internship_progress_updates')
          .select(
            'progress_percentage',
          )
          .eq('internship_id', internshipId)
          .order('created_at', ascending: false)
          .limit(1);

      final progress = progressResponse.isNotEmpty
          ? (progressResponse.first[
                      'progress_percentage'] as num?)
                  ?.toDouble() ??
              0
          : 0;

      result.add(
        IndustryInternshipModel(
          id: internshipId,
          studentName:
              profile?['full_name']?.toString() ??
                  'Student',
          internshipTitle:
              internship['internship_title']
                      ?.toString() ??
                  'Internship',
          status:
              internship['status']?.toString() ??
                  'planned',
          progress: progress.clamp(0.0, 100.0).toDouble(),
          itrStatus: itrStatus,
          evaluationStatus: evaluationStatus,
        ),
      );
    }

    return result;
  }
}