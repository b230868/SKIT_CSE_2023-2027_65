class IndustryDashboardData {
  final String industryName;
  final int totalInterns;
  final int activeInterns;
  final int completedInternships;
  final int pendingAttendance; // Students with attendance pending today
  final int pendingEvaluations;
  final int completedEvaluations;
  final int pendingCertificates;
  final int issuedCertificates;
  final int pendingOfferLetters;
  final int issuedOfferLetters;

  // Backward compatible getters so existing references/analytics continue to compile
  final int pendingItrs;
  final int submittedItrs;

  const IndustryDashboardData({
    required this.industryName,
    required this.totalInterns,
    required this.activeInterns,
    required this.completedInternships,
    this.pendingAttendance = 0,
    required this.pendingEvaluations,
    required this.completedEvaluations,
    this.pendingCertificates = 0,
    this.issuedCertificates = 0,
    this.pendingOfferLetters = 0,
    this.issuedOfferLetters = 0,
    this.pendingItrs = 0,
    this.submittedItrs = 0,
  });

  double get completionRate =>
      totalInterns > 0 ? (completedInternships / totalInterns) * 100 : 0.0;

  double get evaluationRate => submittedItrs > 0
      ? (completedEvaluations / submittedItrs) * 100
      : (totalInterns > 0 ? (completedEvaluations / totalInterns) * 100 : 0.0);

  double get certificateRate =>
      totalInterns > 0 ? (issuedCertificates / totalInterns) * 100 : 0.0;

  double get itrSubmissionRate =>
      totalInterns > 0 ? (submittedItrs / totalInterns) * 100 : 0.0;

  factory IndustryDashboardData.empty([String name = 'Industry Partner']) {
    return IndustryDashboardData(
      industryName: name,
      totalInterns: 0,
      activeInterns: 0,
      completedInternships: 0,
      pendingAttendance: 0,
      pendingEvaluations: 0,
      completedEvaluations: 0,
      pendingCertificates: 0,
      issuedCertificates: 0,
      pendingOfferLetters: 0,
      issuedOfferLetters: 0,
      pendingItrs: 0,
      submittedItrs: 0,
    );
  }

  factory IndustryDashboardData.fromMap(Map<String, dynamic> map) {
    return IndustryDashboardData(
      industryName: map['industry_name']?.toString() ?? 'Industry Partner',
      totalInterns: (map['total_interns'] as num?)?.toInt() ?? 0,
      activeInterns: (map['active_interns'] as num?)?.toInt() ?? 0,
      completedInternships:
          (map['completed_internships'] as num?)?.toInt() ?? 0,
      pendingAttendance: (map['pending_attendance'] as num?)?.toInt() ?? 0,
      pendingEvaluations: (map['pending_evaluations'] as num?)?.toInt() ?? 0,
      completedEvaluations:
          (map['completed_evaluations'] as num?)?.toInt() ?? 0,
      pendingCertificates: (map['pending_certificates'] as num?)?.toInt() ?? 0,
      issuedCertificates: (map['issued_certificates'] as num?)?.toInt() ?? 0,
      pendingOfferLetters: (map['pending_offer_letters'] as num?)?.toInt() ?? 0,
      issuedOfferLetters: (map['issued_offer_letters'] as num?)?.toInt() ?? 0,
      pendingItrs: (map['pending_itrs'] as num?)?.toInt() ?? 0,
      submittedItrs: (map['submitted_itrs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'industry_name': industryName,
      'total_interns': totalInterns,
      'active_interns': activeInterns,
      'completed_internships': completedInternships,
      'pending_attendance': pendingAttendance,
      'pending_evaluations': pendingEvaluations,
      'completed_evaluations': completedEvaluations,
      'pending_certificates': pendingCertificates,
      'issued_certificates': issuedCertificates,
      'pending_offer_letters': pendingOfferLetters,
      'issued_offer_letters': issuedOfferLetters,
      'pending_itrs': pendingItrs,
      'submitted_itrs': submittedItrs,
    };
  }
}
