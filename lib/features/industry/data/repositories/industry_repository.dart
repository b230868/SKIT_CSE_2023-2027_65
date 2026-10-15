import '../models/industry_internship_model.dart';

abstract class IndustryRepository {
  Future<List<IndustryInternshipModel>>
      getIndustryInternships();
}