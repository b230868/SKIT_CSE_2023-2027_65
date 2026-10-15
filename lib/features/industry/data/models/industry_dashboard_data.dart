class IndustryDashboardData {
  final String industryName;
  final int totalInterns;
  final int activeInterns;
  final int completedInternships;
  final int pendingItrs;
  final int submittedItrs;
  final int pendingEvaluations;
  final int completedEvaluations;

  const IndustryDashboardData({
    required this.industryName,
    required this.totalInterns,
    required this.activeInterns,
    required this.completedInternships,
    required this.pendingItrs,
    required this.submittedItrs,
    required this.pendingEvaluations,
    required this.completedEvaluations,
  });
}
