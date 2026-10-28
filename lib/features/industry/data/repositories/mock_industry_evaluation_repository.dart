import '../models/industry_evaluation_model.dart';
import 'industry_evaluation_repository.dart';

class MockIndustryEvaluationRepository implements IndustryEvaluationRepository {
  final List<IndustryEvaluationModel> _allEvaluations;
  final String? companyName;
  final bool hasVerifiedCompany;

  MockIndustryEvaluationRepository({
    List<IndustryEvaluationModel>? evaluations,
    this.companyName,
    this.hasVerifiedCompany = true,
  }) : _allEvaluations = evaluations != null
           ? List.of(evaluations)
           : [
               IndustryEvaluationModel(
                 id: 'eval-001',
                 internshipId: '1',
                 studentId: 'student-001',
                 studentName: 'Rahul Sharma',
                 internshipTitle: 'Software Development Intern',
                 companyName: 'TechNova Solutions',
                 technicalSkillsScore: 16.0,
                 workQualityScore: 15.0,
                 attendanceScore: 18.0,
                 initiativeScore: 14.0,
                 communicationScore: 15.0,
                 totalScore: 78.0,
                 grade: 'B+',
                 status: 'pending',
                 feedback: 'Strong grasp of Flutter fundamentals. Needs minor improvement in test coverage.',
                 remarks: 'Good progress across all sprint deliverables.',
                 evaluationDate: DateTime(2026, 9, 20),
               ),
               IndustryEvaluationModel(
                 id: 'eval-002',
                 internshipId: '2',
                 studentId: 'student-002',
                 studentName: 'Priya Singh',
                 internshipTitle: 'Data Analytics Intern',
                 companyName: 'TechNova Solutions',
                 technicalSkillsScore: 18.0,
                 workQualityScore: 17.0,
                 attendanceScore: 19.0,
                 initiativeScore: 16.0,
                 communicationScore: 17.0,
                 totalScore: 87.0,
                 grade: 'A',
                 status: 'in_progress',
                 feedback: 'Exceptional analytical insights and clean data pipelines.',
                 remarks: 'Recommended for fast-track verification.',
                 evaluationDate: DateTime(2026, 9, 22),
               ),
               IndustryEvaluationModel(
                 id: 'eval-003',
                 internshipId: '3',
                 studentId: 'student-003',
                 studentName: 'Aman Verma',
                 internshipTitle: 'Flutter Development Intern',
                 companyName: 'TechNova Solutions',
                 technicalSkillsScore: 19.0,
                 workQualityScore: 19.0,
                 attendanceScore: 20.0,
                 initiativeScore: 18.0,
                 communicationScore: 18.0,
                 totalScore: 94.0,
                 grade: 'A+',
                 status: 'verified',
                 feedback: 'Outstanding performance, high code quality, and proactive problem solving.',
                 remarks: 'Verified completion with honors.',
                 evaluationDate: DateTime(2026, 9, 25),
                 submittedAt: DateTime(2026, 9, 25),
                 verifiedAt: DateTime(2026, 9, 26),
               ),
             ];

  List<IndustryEvaluationModel> get _authorizedEvaluations {
    if (!hasVerifiedCompany) return [];
    if (companyName != null && companyName!.trim().isNotEmpty) {
      return _allEvaluations
          .where(
            (e) =>
                (e.companyName.trim().toLowerCase()) ==
                companyName!.trim().toLowerCase(),
          )
          .toList();
    }
    return _allEvaluations;
  }

  void _assertAuthorized(String internshipId, [String? evaluationCompanyName]) {
    if (!hasVerifiedCompany) {
      throw StateError(
        'Unauthorized: No verified company association for this supervisor.',
      );
    }
    if (companyName != null && companyName!.trim().isNotEmpty) {
      if (evaluationCompanyName != null &&
          evaluationCompanyName.trim().toLowerCase() !=
              companyName!.trim().toLowerCase()) {
        throw StateError(
          'Unauthorized: Intern belongs to $evaluationCompanyName, not $companyName.',
        );
      }
      final isAuthorized = _allEvaluations.any(
        (e) =>
            e.internshipId == internshipId &&
            e.companyName.trim().toLowerCase() ==
                companyName!.trim().toLowerCase(),
      );
      // If evaluation doesn't exist yet, we check if evaluationCompanyName matches
      if (!isAuthorized && evaluationCompanyName != null) {
        if (evaluationCompanyName.trim().toLowerCase() !=
            companyName!.trim().toLowerCase()) {
          throw StateError(
            'Unauthorized: Cannot evaluate intern belonging to another company.',
          );
        }
      }
    }
  }

  @override
  Future<List<IndustryEvaluationModel>> getEvaluations() async {
    return List.unmodifiable(_authorizedEvaluations);
  }

  @override
  Future<IndustryEvaluationModel?> getEvaluationByInternshipId(
    String internshipId,
  ) async {
    try {
      final eval = _allEvaluations.firstWhere(
        (e) => e.internshipId == internshipId,
      );
      _assertAuthorized(internshipId, eval.companyName);
      return eval;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveEvaluation(IndustryEvaluationModel evaluation) async {
    _assertAuthorized(evaluation.internshipId, evaluation.companyName);

    final index = _allEvaluations.indexWhere(
      (e) => e.id == evaluation.id || e.internshipId == evaluation.internshipId,
    );

    if (index == -1) {
      _allEvaluations.add(evaluation);
    } else {
      _allEvaluations[index] = evaluation;
    }
  }

  @override
  Future<void> verifyInternship({
    required String internshipId,
    required String remarks,
    String? evaluationId,
    String? itrId,
  }) async {
    _assertAuthorized(internshipId);

    final index = _allEvaluations.indexWhere(
      (e) =>
          e.internshipId == internshipId ||
          (evaluationId != null && e.id == evaluationId),
    );

    if (index != -1) {
      final existing = _allEvaluations[index];
      _allEvaluations[index] = existing.copyWith(
        status: 'verified',
        remarks: remarks,
        verifiedAt: DateTime.now(),
      );
    }
  }
}
