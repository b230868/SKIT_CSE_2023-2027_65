import '../models/industry_evaluation_model.dart';

abstract class IndustryEvaluationRepository {
  Future<List<IndustryEvaluationModel>> getEvaluations();

  Future<IndustryEvaluationModel?> getEvaluationByInternshipId(
    String internshipId,
  );

  Future<void> saveEvaluation(IndustryEvaluationModel evaluation);

  Future<void> verifyInternship({
    required String internshipId,
    required String remarks,
    String? evaluationId,
    String? itrId,
  });
}
