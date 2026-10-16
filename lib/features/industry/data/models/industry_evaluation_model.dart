class IndustryAnalyticsData {
  final String industryName;
  final int totalInterns;
  final int activeInterns;
  final int completedInternships;
  final int pendingItrs;
  final int submittedItrs;
  final int approvedItrs;
  final int pendingEvaluations;
  final int completedEvaluations;
  final double? averageScore;
  final Map<String, int> gradeDistribution;
  final Map<String, int> progressBands;

  const IndustryAnalyticsData({
    required this.industryName,
    required this.totalInterns,
    required this.activeInterns,
    required this.completedInternships,
    required this.pendingItrs,
    required this.submittedItrs,
    required this.approvedItrs,
    required this.pendingEvaluations,
    required this.completedEvaluations,
    required this.averageScore,
    required this.gradeDistribution,
    required this.progressBands,
  });
}
