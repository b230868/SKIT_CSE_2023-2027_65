class StudentMonitoringItem {
  final String studentId;
  final String studentName;
  final String internshipId;
  final String internshipTitle;
  final String applicationStatus;
  final String? studentEmail;
  final String? rollNumber;
  final String? department;
  final int? batchYear;
  final String? companyName;
  final String? internshipStatus;
  final String? itrStatus;
  final bool hasCertificate;
  final String? certificateStatus;
  final int progress;
  final bool hasPendingApprovals;
  final double? companyEvaluationScore;
  final String? companyEvaluationGrade;
  final double? attendanceRate;
  final String? companyRemarks;
  final String? companyEvaluatorName;
  final List<dynamic> documents;

  const StudentMonitoringItem({
    required this.studentId,
    required this.studentName,
    required this.internshipId,
    required this.internshipTitle,
    required this.applicationStatus,
    this.studentEmail,
    this.rollNumber,
    this.department,
    this.batchYear,
    this.companyName,
    this.internshipStatus,
    this.itrStatus,
    this.hasCertificate = false,
    this.certificateStatus,
    this.progress = 0,
    this.hasPendingApprovals = false,
    this.companyEvaluationScore,
    this.companyEvaluationGrade,
    this.attendanceRate,
    this.companyRemarks,
    this.companyEvaluatorName,
    this.documents = const [],
  });
}
