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

  double get completionRate =>
      totalInterns > 0 ? (completedInternships / totalInterns) * 100 : 0.0;

  double get itrSubmissionRate =>
      totalInterns > 0 ? (submittedItrs / totalInterns) * 100 : 0.0;

  double get evaluationRate =>
      submittedItrs > 0 ? (completedEvaluations / submittedItrs) * 100 : 0.0;

  factory IndustryDashboardData.empty([String name = 'Industry Partner']) {
    return IndustryDashboardData(
      industryName: name,
      totalInterns: 0,
      activeInterns: 0,
      completedInternships: 0,
      pendingItrs: 0,
      submittedItrs: 0,
      pendingEvaluations: 0,
      completedEvaluations: 0,
    );
  }

  factory IndustryDashboardData.fromMap(Map<String, dynamic> map) {
    return IndustryDashboardData(
      industryName: map['industry_name']?.toString() ?? 'Industry Partner',
      totalInterns: (map['total_interns'] as num?)?.toInt() ?? 0,
      activeInterns: (map['active_interns'] as num?)?.toInt() ?? 0,
      completedInternships:
          (map['completed_internships'] as num?)?.toInt() ?? 0,
      pendingItrs: (map['pending_itrs'] as num?)?.toInt() ?? 0,
      submittedItrs: (map['submitted_itrs'] as num?)?.toInt() ?? 0,
      pendingEvaluations: (map['pending_evaluations'] as num?)?.toInt() ?? 0,
      completedEvaluations:
          (map['completed_evaluations'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'industry_name': industryName,
      'total_interns': totalInterns,
      'active_interns': activeInterns,
      'completed_internships': completedInternships,
      'pending_itrs': pendingItrs,
      'submitted_itrs': submittedItrs,
      'pending_evaluations': pendingEvaluations,
      'completed_evaluations': completedEvaluations,
    };
  }
}
