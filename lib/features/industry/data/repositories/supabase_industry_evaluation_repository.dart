import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/industry_evaluation_model.dart';
import 'industry_evaluation_repository.dart';

class SupabaseIndustryEvaluationRepository
    implements IndustryEvaluationRepository {
  SupabaseIndustryEvaluationRepository({SupabaseClient? client})
    : _customClient = client;

  final SupabaseClient? _customClient;

  SupabaseClient get _client => _customClient ?? Supabase.instance.client;

  Future<String?> _getIndustryId() async {
    final User? user;
    try {
      user = _client.auth.currentUser;
    } catch (_) {
      return null;
    }
    if (user == null) return null;

    try {
      final row = await _client
          .from('industry_users')
          .select('industry_id')
          .eq('user_id', user.id)
          .maybeSingle();

      return row?['industry_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Verifies that the targeted internship belongs to the supervisor's authorized company.
  Future<String> _requireAuthorizedInternship(String internshipId) async {
    final industryId = await _getIndustryId();
    if (industryId == null) {
      throw StateError(
        'Unauthorized: No verified company association for this supervisor.',
      );
    }

    final row = await _client
        .from('internships')
        .select('id')
        .eq('id', internshipId)
        .eq('industry_id', industryId)
        .maybeSingle();

    if (row == null) {
      throw StateError(
        'Unauthorized: Internship $internshipId does not belong to your company.',
      );
    }

    return industryId;
  }

  @override
  Future<List<IndustryEvaluationModel>> getEvaluations() async {
    final industryId = await _getIndustryId();
    if (industryId == null) {
      return [];
    }

    dynamic data;
    try {
      data = await _client
          .from('evaluations')
          .select('''
            id,
            internship_id,
            student_id,
            industry_id,
            evaluator_id,
            total_score,
            score,
            marks,
            grade,
            status,
            feedback,
            remarks,
            evaluation_date,
            submitted_at,
            verified_at,
            internships (
              internship_title,
              industries (
                name
              )
            )
          ''')
          .eq('industry_id', industryId)
          .order('created_at', ascending: false);
    } catch (_) {
      try {
        data = await _client
            .from('evaluations')
            .select('''
              id,
              internship_id,
              student_id,
              industry_id,
              evaluator_id,
              total_score,
              score,
              marks,
              grade,
              status,
              feedback,
              remarks,
              evaluation_date,
              submitted_at,
              verified_at,
              internships (
                internship_title
              )
            ''')
            .eq('industry_id', industryId)
            .order('created_at', ascending: false);
      } catch (_) {
        return [];
      }
    }

    if (data is! List) return [];

    final result = <IndustryEvaluationModel>[];
    final evalList = data;

    final studentIds = evalList
        .map((raw) => (raw as Map)['student_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    final Map<String, String> studentNames = {};
    if (studentIds.isNotEmpty) {
      final Map<String, String> studentToUserId = {};
      try {
        final studs = await _client
            .from('students')
            .select('id, user_id')
            .inFilter('id', studentIds);
        for (final s in (studs as List)) {
          final sid = s['id']?.toString();
          final uid = s['user_id']?.toString();
          if (sid != null && uid != null) {
            studentToUserId[sid] = uid;
          }
        }
      } catch (_) {}

      final profileIds = <String>{
        ...studentIds,
        ...studentToUserId.values,
      }.toList();

      try {
        final profs = await _client
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', profileIds);
        final Map<String, String> namesByProfileId = {};
        for (final p in (profs as List)) {
          final id = p['id']?.toString();
          final name = p['full_name']?.toString();
          if (id != null && name != null) namesByProfileId[id] = name;
        }
        for (final sid in studentIds) {
          final resolvedName =
              namesByProfileId[sid] ??
              (studentToUserId[sid] != null
                  ? namesByProfileId[studentToUserId[sid]]
                  : null);
          if (resolvedName != null) {
            studentNames[sid] = resolvedName;
          }
        }
      } catch (_) {}
    }

    for (final raw in evalList) {
      final item = Map<String, dynamic>.from(raw as Map);
      final internship = item['internships'] as Map<String, dynamic>?;
      final industry = internship?['industries'] as Map<String, dynamic>?;
      final studentId = item['student_id']?.toString();
      final studentName =
          (studentId != null ? studentNames[studentId] : null) ?? 'Student';

      result.add(
        IndustryEvaluationModel.fromMap({
          ...item,
          'internship_title': internship?['internship_title'] ?? 'Internship',
          'company_name': industry?['name'] ?? 'Company',
          'student_name': studentName,
        }),
      );
    }

    return result;
  }

  @override
  Future<IndustryEvaluationModel?> getEvaluationByInternshipId(
    String internshipId,
  ) async {
    dynamic data;
    try {
      data = await _client
          .from('evaluations')
          .select('''
            id,
            internship_id,
            student_id,
            industry_id,
            evaluator_id,
            total_score,
            score,
            marks,
            grade,
            status,
            feedback,
            remarks,
            evaluation_date,
            submitted_at,
            verified_at,
            internships (
              internship_title,
              industries (
                name
              )
            )
          ''')
          .eq('internship_id', internshipId)
          .order('created_at', ascending: false)
          .limit(1);
    } catch (_) {
      try {
        data = await _client
            .from('evaluations')
            .select('''
              id,
              internship_id,
              student_id,
              industry_id,
              evaluator_id,
              total_score,
              score,
              marks,
              grade,
              status,
              feedback,
              remarks,
              evaluation_date,
              submitted_at,
              verified_at,
              internships (
                internship_title
              )
            ''')
            .eq('internship_id', internshipId)
            .order('created_at', ascending: false)
            .limit(1);
      } catch (_) {
        return null;
      }
    }

    if (data is! List || data.isEmpty) return null;

    final item = Map<String, dynamic>.from(data.first);
    final internship = item['internships'] as Map<String, dynamic>?;
    final industry = internship?['industries'] as Map<String, dynamic>?;
    final studentId = item['student_id']?.toString();

    String studentName = 'Student';
    if (studentId != null) {
      try {
        String lookupProfileId = studentId;
        final stud = await _client
            .from('students')
            .select('user_id')
            .eq('id', studentId)
            .maybeSingle();
        if (stud != null && stud['user_id'] != null) {
          lookupProfileId = stud['user_id'].toString();
        }
        final p = await _client
            .from('profiles')
            .select('full_name')
            .eq('id', lookupProfileId)
            .maybeSingle();
        if (p != null && p['full_name'] != null) {
          studentName = p['full_name'].toString();
        }
      } catch (_) {}
    }

    return IndustryEvaluationModel.fromMap({
      ...item,
      'internship_title': internship?['internship_title'] ?? 'Internship',
      'company_name': industry?['name'] ?? 'Company',
      'student_name': studentName,
    });
  }

    @override
  Future<void> saveEvaluation(IndustryEvaluationModel evaluation) async {
    // Enforce server-side company authorization check
    final industryId = await _requireAuthorizedInternship(
      evaluation.internshipId,
    );

    final user = _client.auth.currentUser;
    final payload = <String, dynamic>{
      'internship_id': evaluation.internshipId,
      'industry_id': industryId,
      'total_score': evaluation.totalScore,
      'score': evaluation.totalScore,
      'marks': evaluation.totalScore,
      'grade': evaluation.grade,
      'status': evaluation.status,
      'feedback': evaluation.feedback,
      'remarks': evaluation.remarks,
      'evaluation_date': DateTime.now().toIso8601String().split('T').first,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (user != null) {
      payload['evaluator_id'] = user.id;
    }
    if (evaluation.studentId.isNotEmpty) {
      payload['student_id'] = evaluation.studentId;
    }
    if (evaluation.status == 'verified' || evaluation.status == 'completed') {
      payload['verified_at'] = DateTime.now().toIso8601String();
      payload['submitted_at'] ??= DateTime.now().toIso8601String();
    }

    if (evaluation.id.isNotEmpty && !evaluation.id.startsWith('eval-')) {
      await _client.from('evaluations').update(payload).eq('id', evaluation.id);
    } else {
      final existing = await _client
          .from('evaluations')
          .select('id')
          .eq('internship_id', evaluation.internshipId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existing != null && existing['id'] != null) {
        await _client
            .from('evaluations')
            .update(payload)
            .eq('id', existing['id'].toString());
      } else {
        await _client.from('evaluations').insert(payload);
      }
    }
  }

  @override
  Future<void> verifyInternship({
    required String internshipId,
    required String remarks,
    String? evaluationId,
    String? itrId,
  }) async {
    await _requireAuthorizedInternship(internshipId);

    final user = _client.auth.currentUser;

    // 1. Record verification audit in verifications table (verification_status enum uses 'approved')
    try {
      await _client.from('verifications').insert({
        'internship_id': internshipId,
        'itr_id': itrId,
        'verifier_id': user?.id,
        'status': 'approved',
        'remarks': remarks,
        'verified_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    // 2. Mark evaluation as verified
    if (evaluationId != null && evaluationId.isNotEmpty) {
      await _client
          .from('evaluations')
          .update({
            'status': 'verified',
            'remarks': remarks,
            'verified_at': DateTime.now().toIso8601String(),
          })
          .eq('id', evaluationId);
    } else {
      await _client
          .from('evaluations')
          .update({
            'status': 'verified',
            'remarks': remarks,
            'verified_at': DateTime.now().toIso8601String(),
          })
          .eq('internship_id', internshipId);
    }
  }
}
