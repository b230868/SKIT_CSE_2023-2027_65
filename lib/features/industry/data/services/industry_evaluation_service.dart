import '../models/industry_evaluation_model.dart';
import '../repositories/industry_evaluation_repository.dart';
import '../repositories/industry_evaluation_repository_provider.dart';

class IndustryEvaluationService {
  final IndustryEvaluationRepository _repository;

  IndustryEvaluationService({IndustryEvaluationRepository? repository})
    : _repository = repository ?? industryEvaluationRepository;

  Future<List<IndustryEvaluationModel>> getEvaluations() {
    return _repository.getEvaluations();
  }

  Future<IndustryEvaluationModel?> getEvaluationByInternshipId(
    String internshipId,
  ) {
    return _repository.getEvaluationByInternshipId(internshipId);
  }

  Future<void> saveEvaluation({
    required String internshipId,
    required String studentId,
    required String studentName,
    required String internshipTitle,
    required String companyName,
    String? evaluationId,
    String? industryId,
    double technicalSkillsScore = 0,
    double workQualityScore = 0,
    double attendanceScore = 0,
    double initiativeScore = 0,
    double communicationScore = 0,
    String status = 'in_progress',
    String? feedback,
    String? remarks,
  }) async {
    final total =
        technicalSkillsScore +
        workQualityScore +
        attendanceScore +
        initiativeScore +
        communicationScore;

    final grade = IndustryEvaluationModel.calculateGrade(total);

    final model = IndustryEvaluationModel(
      id: evaluationId ?? '',
      internshipId: internshipId,
      studentId: studentId,
      studentName: studentName,
      internshipTitle: internshipTitle,
      companyName: companyName,
      industryId: industryId,
      technicalSkillsScore: technicalSkillsScore,
      workQualityScore: workQualityScore,
      attendanceScore: attendanceScore,
      initiativeScore: initiativeScore,
      communicationScore: communicationScore,
      totalScore: total.clamp(0.0, 100.0),
      grade: grade,
      status: status,
      feedback: feedback,
      remarks: remarks,
      evaluationDate: DateTime.now(),
      submittedAt: (status == 'verified' || status == 'completed')
          ? DateTime.now()
          : null,
      verifiedAt: status == 'verified' ? DateTime.now() : null,
    );

    await _repository.saveEvaluation(model);
  }

  Future<void> verifyInternship({
    required String internshipId,
    required String remarks,
    String? evaluationId,
    String? itrId,
  }) {
    return _repository.verifyInternship(
      internshipId: internshipId,
      remarks: remarks,
      evaluationId: evaluationId,
      itrId: itrId,
    );
  }
}
