class FacultyReportData {
  final int totalInternships;
  final int pendingApprovals;
  final int underReviewApprovals;
  final int approvedInternships;
  final int rejectedApplications;
  final int facultyStageCount;
  final int tpStageCount;
  final Map<String, int> departmentSummary;

  const FacultyReportData({
    required this.totalInternships,
    required this.pendingApprovals,
    required this.underReviewApprovals,
    required this.approvedInternships,
    required this.rejectedApplications,
    required this.facultyStageCount,
    required this.tpStageCount,
    this.departmentSummary = const {},
  });

  double get approvalRate {
    if (totalInternships == 0) return 0.0;
    return (approvedInternships / totalInternships) * 100;
  }
}
