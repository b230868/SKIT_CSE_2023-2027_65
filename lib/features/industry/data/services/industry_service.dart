import '../models/industry_internship_model.dart';
import '../repositories/industry_repository.dart';
import '../repositories/supabase_industry_repository.dart';

class IndustryService {
  final IndustryRepository _repository;

  IndustryService({IndustryRepository? repository})
      : _repository =
            repository ?? SupabaseIndustryRepository();

  Future<List<IndustryInternshipModel>>
      getIndustryInternships() {
    return _repository.getIndustryInternships();
  }
}