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

    try {
      final data = await _client
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
              ),
              students (
                profiles (
                  full_name
                )
              )
            )
          ''')
          .eq('industry_id', industryId)
          .order('created_at', ascending: false);

      final result = <IndustryEvaluationModel>[];

      for (final raw in (data as List)) {
        final item = Map<String, dynamic>.from(raw);
        final internship = item['internships'] as Map<String, dynamic>?;
        final industry = internship?['industries'] as Map<String, dynamic>?;
        final student = internship?['students'] as Map<String, dynamic>?;
        final profile = student?['profiles'] as Map<String, dynamic>?;

        result.add(
          IndustryEvaluationModel.fromMap({
            ...item,
            'internship_title': internship?['internship_title'] ?? 'Internship',
            'company_name': industry?['name'] ?? 'Company',
            'student_name': profile?['full_name'] ?? 'Student',
          }),
        );
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<IndustryEvaluationModel?> getEvaluationByInternshipId(
    String internshipId,
  ) async {
    try {
      final data = await _client
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
              ),
              students (
                profiles (
                  full_name
                )
              )
            )
          ''')
          .eq('internship_id', internshipId)
          .order('created_at', ascending: false)
          .limit(1);

      if ((data as List).isEmpty) return null;

      final item = Map<String, dynamic>.from(data.first);
      final internship = item['internships'] as Map<String, dynamic>?;
      final industry = internship?['industries'] as Map<String, dynamic>?;
      final student = internship?['students'] as Map<String, dynamic>?;
      final profile = student?['profiles'] as Map<String, dynamic>?;

      return IndustryEvaluationModel.fromMap({
        ...item,
        'internship_title': internship?['internship_title'] ?? 'Internship',
        'company_name': industry?['name'] ?? 'Company',
        'student_name': profile?['full_name'] ?? 'Student',
      });
    } catch (_) {
      return null;
    }
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
      await _client
          .from('evaluations')
          .upsert(payload, onConflict: 'internship_id');
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

    // 1. Record verification in verifications table
    try {
      await _client.from('verifications').insert({
        'internship_id': internshipId,
        'itr_id': itrId,
        'verifier_id': user?.id,
        'status': 'verified',
        'remarks': remarks,
        'verified_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    // 2. Mark evaluation as verified
    try {
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
    } catch (_) {}
  }
}
