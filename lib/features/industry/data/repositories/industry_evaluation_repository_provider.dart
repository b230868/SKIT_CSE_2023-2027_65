import 'industry_evaluation_repository.dart';
import 'supabase_industry_evaluation_repository.dart';

class IndustryEvaluationRepositoryProvider {
  static IndustryEvaluationRepository? _instance;

  static IndustryEvaluationRepository get instance {
    return _instance ??= SupabaseIndustryEvaluationRepository();
  }

  static void setInstance(IndustryEvaluationRepository repository) {
    _instance = repository;
  }

  static void reset() {
    _instance = null;
  }
}

IndustryEvaluationRepository get industryEvaluationRepository =>
    IndustryEvaluationRepositoryProvider.instance;
