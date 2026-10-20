import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/industry_dashboard_data.dart';
import '../models/industry_internship_model.dart';
import 'industry_repository.dart';

class SupabaseIndustryRepository implements IndustryRepository {
  SupabaseIndustryRepository({SupabaseClient? client}) : _customClient = client;

  final SupabaseClient? _customClient;

  SupabaseClient get _client {
    final client = _customClient;
    if (client != null) return client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('User is not authenticated.');
    }
  }

  /// Resolves the canonical `industry_id` for the authenticated industry supervisor.
  ///
  /// Based on project database schema evidence:
  /// - `industry_users` table maps `user_id` (auth profile ID) to `industry_id` (`industries.id`).
  /// - Does NOT treat `user.id` as `industry_id` unless confirmed by schema.
  Future<String?> _getIndustryId() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated.');
    }

    // 1. Primary lookup: industry_users mapping table (schema verified)
    final row = await _client
        .from('industry_users')
        .select('industry_id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row != null && row['industry_id'] != null) {
      return row['industry_id'].toString();
    }

    // 2. Direct lookup: check if an organization exists with id = user.id
    final ind = await _client
        .from('industries')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (ind != null && ind['id'] != null) {
      return ind['id'].toString();
    }

    // Explicitly return null if no confirmed industry assignment exists.
    return null;
  }

  @override
  Future<List<IndustryInternshipModel>> getIndustryInternships() async {
    final industryId = await _getIndustryId();

    if (industryId == null) {
      throw StateError(
        'No industry organization is associated with this user account. '
        'Please ensure an administrator assigns your account to an industry in the industry_users table.',
      );
    }

    // Query internships scoped strictly by industry_id without unsafe company_name matching
    final res = await _client
        .from('internships')
        .select('''
          id,
          internship_title,
          title,
          company_name,
          status,
          progress,
          students (
            roll_number,
            profiles (
              full_name
            )
          )
        ''')
        .eq('industry_id', industryId)
        .order('created_at', ascending: false);

    final internshipList = (res as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();

    if (internshipList.isEmpty) {
      return [];
    }

    final internshipIds =
        internshipList.map((e) => e['id'].toString()).toList();

    // Batch fetch latest related statuses for active internships
    final Map<String, String> latestItrStatus = {};
    final Map<String, String> latestEvaluationStatus = {};
    final Map<String, double> latestProgress = {};

    try {
      final itrRows = await _client
          .from('itrs')
          .select('internship_id, status, created_at')
          .inFilter('internship_id', internshipIds)
          .order('created_at', ascending: false);

      for (final row in (itrRows as List)) {
        final id = row['internship_id']?.toString();
        if (id != null && !latestItrStatus.containsKey(id)) {
          latestItrStatus[id] = row['status']?.toString() ?? 'draft';
        }
      }
    } catch (_) {
      // Supplementary table lookup degradation: continue with default ITR status
    }

    try {
      final evalRows = await _client
          .from('evaluations')
          .select('internship_id, status, created_at')
          .inFilter('internship_id', internshipIds)
          .order('created_at', ascending: false);

      for (final row in (evalRows as List)) {
        final id = row['internship_id']?.toString();
        if (id != null && !latestEvaluationStatus.containsKey(id)) {
          latestEvaluationStatus[id] = row['status']?.toString() ?? 'pending';
        }
      }
    } catch (_) {
      // Supplementary table lookup degradation: continue with default eval status
    }

    try {
      final progressRows = await _client
          .from('internship_progress_updates')
          .select('internship_id, progress_percentage, created_at')
          .inFilter('internship_id', internshipIds)
          .order('created_at', ascending: false);

      for (final row in (progressRows as List)) {
        final id = row['internship_id']?.toString();
        if (id != null && !latestProgress.containsKey(id)) {
          latestProgress[id] =
              (row['progress_percentage'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (_) {
      // Supplementary progress updates table lookup degradation
    }

    final result = <IndustryInternshipModel>[];

    for (final internship in internshipList) {
      final student = internship['students'] as Map<String, dynamic>?;
      final profile = student?['profiles'] as Map<String, dynamic>?;
      final internshipId = internship['id'].toString();

      final itrStatus = latestItrStatus[internshipId] ?? 'draft';
      final evalStatus = latestEvaluationStatus[internshipId] ?? 'pending';
      final progress = ((internship['progress'] as num?)?.toDouble() ??
              latestProgress[internshipId] ??
              0.0)
          .clamp(0.0, 100.0)
          .toDouble();

      result.add(
        IndustryInternshipModel(
          id: internshipId,
          studentName: profile?['full_name']?.toString() ??
              internship['company_name']?.toString() ??
              'Student',
          internshipTitle: internship['internship_title']?.toString() ??
              internship['title']?.toString() ??
              'Internship',
          status: internship['status']?.toString() ?? 'planned',
          progress: progress,
          itrStatus: itrStatus,
          evaluationStatus: evalStatus,
        ),
      );
    }

    return result;
  }

  @override
  Future<IndustryDashboardData> getDashboardData() async {
    final industryId = await _getIndustryId();

    if (industryId == null) {
      throw StateError(
        'No industry organization is associated with this user account. '
        'Please ensure an administrator assigns your account to an industry in the industry_users table.',
      );
    }

    String industryName = 'Industry Partner';
    final res = await _client
        .from('industries')
        .select('name')
        .eq('id', industryId)
        .maybeSingle();

    if (res != null && res['name'] != null) {
      industryName = res['name'].toString();
    }

    // Derive dashboard metrics from actual repository internships
    final internships = await getIndustryInternships();

    final active = internships.where((i) => i.status == 'active').length;
    final completed =
        internships.where((i) => i.status == 'completed').length;
    final pendingItr = internships
        .where(
          (i) => ['draft', 'submitted', 'under_review'].contains(i.itrStatus),
        )
        .length;
    final submittedItr = internships
        .where(
          (i) =>
              ['submitted', 'under_review', 'approved'].contains(i.itrStatus),
        )
        .length;
    final pendingEval = internships
        .where((i) => ['pending', 'in_progress'].contains(i.evaluationStatus))
        .length;
    final completedEval = internships
        .where(
          (i) => [
            'verified',
            'completed',
            'approved',
          ].contains(i.evaluationStatus),
        )
        .length;

    return IndustryDashboardData(
      industryName: industryName,
      totalInterns: internships.length,
      activeInterns: active,
      completedInternships: completed,
      pendingItrs: pendingItr,
      submittedItrs: submittedItr,
      pendingEvaluations: pendingEval,
      completedEvaluations: completedEval,
    );
  }
}
