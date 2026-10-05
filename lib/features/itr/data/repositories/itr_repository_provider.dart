import 'itr_repository.dart';
import 'supabase_itr_repository.dart';

class ItrRepositoryProvider {
  static ItrRepository? _instance;

  static ItrRepository get instance {
    return _instance ??= SupabaseItrRepository();
  }

  static void setInstance(ItrRepository repository) {
    _instance = repository;
  }

  static void reset() {
    _instance = null;
  }
}

ItrRepository get itrRepository => ItrRepositoryProvider.instance;
