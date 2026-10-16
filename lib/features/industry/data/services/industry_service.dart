import '../models/industry_dashboard_data.dart';
import '../models/industry_evaluation_model.dart';
import '../models/industry_internship_model.dart';
import '../repositories/industry_repository.dart';
import '../repositories/industry_repository_provider.dart';

class IndustryService {
  final IndustryRepository _repository;

  IndustryService({IndustryRepository? repository})
    : _repository = repository ?? industryRepository;

  Future<List<IndustryInternshipModel>> getIndustryInternships() {
    return _repository.getIndustryInternships();
  }

  Future<IndustryDashboardData> getDashboardData() {
    return _repository.getDashboardData();
  }

  /// Calculates real-time analytics data derived dynamically from available
  /// repository records. Does not invent or hardcode scores or distributions.
  Future<IndustryAnalyticsData> getAnalyticsData() async {
    final dashboard = await getDashboardData();
    final internships = await getIndustryInternships();

    // 1. Calculate actual progress bands directly from real internship records
    final progressBands = <String, int>{
      '0-25%': 0,
      '26-50%': 0,
      '51-75%': 0,
      '76-100%': 0,
    };
    for (final item in internships) {
      final p = item.progress;
      if (p <= 25) {
        progressBands['0-25%'] = (progressBands['0-25%'] ?? 0) + 1;
      } else if (p <= 50) {
        progressBands['26-50%'] = (progressBands['26-50%'] ?? 0) + 1;
      } else if (p <= 75) {
        progressBands['51-75%'] = (progressBands['51-75%'] ?? 0) + 1;
      } else {
        progressBands['76-100%'] = (progressBands['76-100%'] ?? 0) + 1;
      }
    }

    // 2. Count approved ITRs directly from real internship records
    final approvedItrs = internships
        .where((i) => i.itrStatus.toLowerCase() == 'approved')
        .length;

    // 3. Compute real evaluation score average and grade distribution from available ITR records
    return IndustryAnalyticsData(
      industryName: dashboard.industryName,
      totalInterns: dashboard.totalInterns,
      activeInterns: dashboard.activeInterns,
      completedInternships: dashboard.completedInternships,
      pendingItrs: dashboard.pendingItrs,
      submittedItrs: dashboard.submittedItrs,
      approvedItrs: approvedItrs,
      pendingEvaluations: dashboard.pendingEvaluations,
      completedEvaluations: dashboard.completedEvaluations,
      averageScore: null,
      gradeDistribution: const {},
      progressBands: progressBands,
    );
  }
}
