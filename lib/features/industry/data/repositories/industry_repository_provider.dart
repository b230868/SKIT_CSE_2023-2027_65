import 'industry_repository.dart';
import 'supabase_industry_repository.dart';

class IndustryRepositoryProvider {
  static IndustryRepository? _instance;

  static IndustryRepository get instance {
    return _instance ??= SupabaseIndustryRepository();
  }

  static void setInstance(IndustryRepository repository) {
    _instance = repository;
  }

  static void reset() {
    _instance = null;
  }
}

IndustryRepository get industryRepository =>
    IndustryRepositoryProvider.instance;
