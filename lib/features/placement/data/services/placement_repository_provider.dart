import '../repositories/placement_repository.dart';
import '../repositories/supabase_placement_repository.dart';

class PlacementRepositoryProvider {
  PlacementRepositoryProvider._();

  static PlacementRepository? _override;

  static void setRepository(PlacementRepository repository) {
    _override = repository;
  }

  static void reset() {
    _override = null;
  }

  static PlacementRepository get instance =>
      _override ?? SupabasePlacementRepository();
}
