import '../models/industry_dashboard_data.dart';
import '../models/industry_internship_model.dart';

abstract class IndustryRepository {
  Future<List<IndustryInternshipModel>> getIndustryInternships();

  Future<IndustryDashboardData> getDashboardData();
}
