import '../../../itr/data/repositories/itr_repository.dart';
import '../../../itr/data/repositories/itr_repository_provider.dart';
import '../models/industry_dashboard_data.dart';
import '../models/industry_evaluation_model.dart';
import '../models/industry_internship_model.dart';
import '../repositories/industry_repository.dart';
import '../repositories/industry_repository_provider.dart';

class IndustryService {
  final IndustryRepository _repository;
  final ItrRepository? itrRepository;

  IndustryService({
    IndustryRepository? repository,
    this.itrRepository,
  }) : _repository = repository ?? industryRepository;

  ItrRepository get _effectiveItrRepo =>
      itrRepository ?? ItrRepositoryProvider.instance;

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
    double averageScore = 0.0;
    final gradeDistribution = <String, int>{
      'A+': 0,
      'A': 0,
      'B': 0,
      'C': 0,
      'D': 0,
      'F': 0,
    };
    int evaluatedCount = 0;
    double totalScoreSum = 0.0;

    try {
      final itrs = await _effectiveItrRepo.getIndustryItrs();
      for (final itr in itrs) {
        if (itr.evaluationScore != null && itr.evaluationScore! > 0) {
          totalScoreSum += itr.evaluationScore!;
          evaluatedCount++;
        }
        final grade = itr.evaluationGrade?.toUpperCase();
        if (grade != null && gradeDistribution.containsKey(grade)) {
          gradeDistribution[grade] = (gradeDistribution[grade] ?? 0) + 1;
        }
      }
    } catch (_) {
      // In case ITR service/repository is unreachable, leave evaluatedCount at 0
    }

    if (evaluatedCount > 0) {
      averageScore = double.parse(
        (totalScoreSum / evaluatedCount).toStringAsFixed(1),
      );
    }

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
      averageScore: averageScore,
      gradeDistribution: gradeDistribution,
      progressBands: progressBands,
    );
  }
}
