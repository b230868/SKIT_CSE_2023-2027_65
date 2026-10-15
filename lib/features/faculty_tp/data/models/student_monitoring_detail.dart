class StudentMonitoringDetail {
  // Personal & Academic
  final String studentId;
  final String? userId;
  final String studentName;
  final String studentEmail;
  final String? rollNumber;
  final String? department;
  final String? branch;
  final int? batchYear;
  final String? phone;
  final String? address;
  final String? avatarUrl;
  final bool isActive;
  final DateTime? profileCreatedAt;
  final DateTime? profileUpdatedAt;

  // Internship
  final String? internshipId;
  final String? internshipTitle;
  final String? companyName;
  final String? internshipMode;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? internshipStatus;
  final int progress;
  final String? description;
  final String? industryName;
  final String? industryAddress;
  final String? industryEmail;
  final String? industryPhone;

  // ITR (Industrial Training Report)
  final String? itrId;
  final String? itrStatus;
  final String? itrContent;
  final String? itrProjectTitle;
  final String? itrProjectDescription;
  final String? itrWorkDone;
  final String? itrTechnologiesUsed;
  final String? itrKeyLearnings;
  final String? itrChallengesFaced;
  final String? itrDocumentPath;
  final String? itrProjectZipPath;
  final String? itrProjectPptPath;
  final String? itrPresentationPath;
  final DateTime? itrSubmittedAt;
  final DateTime? itrReviewedAt;
  final DateTime? itrVerifiedAt;
  final String? itrReviewerName;
  final String? itrRemarks;

  // Certificate
  final String? certificateId;
  final String? certificateFilePath;
  final String? certificateStatus; // pending, approved, rejected, uploaded
  final DateTime? certificateCreatedAt;
  final DateTime? certificateUpdatedAt;

  // Approval Reviews
  final List<StudentApprovalReviewItem> approvalReviews;

  const StudentMonitoringDetail({
    required this.studentId,
    this.userId,
    required this.studentName,
    required this.studentEmail,
    this.rollNumber,
    this.department,
    this.branch,
    this.batchYear,
    this.phone,
    this.address,
    this.avatarUrl,
    this.isActive = true,
    this.profileCreatedAt,
    this.profileUpdatedAt,
    this.internshipId,
    this.internshipTitle,
    this.companyName,
    this.internshipMode,
    this.startDate,
    this.endDate,
    this.internshipStatus,
    this.progress = 0,
    this.description,
    this.industryName,
    this.industryAddress,
    this.industryEmail,
    this.industryPhone,
    this.itrId,
    this.itrStatus,
    this.itrContent,
    this.itrProjectTitle,
    this.itrProjectDescription,
    this.itrWorkDone,
    this.itrTechnologiesUsed,
    this.itrKeyLearnings,
    this.itrChallengesFaced,
    this.itrDocumentPath,
    this.itrProjectZipPath,
    this.itrProjectPptPath,
    this.itrPresentationPath,
    this.itrSubmittedAt,
    this.itrReviewedAt,
    this.itrVerifiedAt,
    this.itrReviewerName,
    this.itrRemarks,
    this.certificateId,
    this.certificateFilePath,
    this.certificateStatus,
    this.certificateCreatedAt,
    this.certificateUpdatedAt,
    this.approvalReviews = const [],
  });

  /// True if certificate file path is actually present
  bool get hasCertificateUploaded =>
      certificateFilePath != null && certificateFilePath!.trim().isNotEmpty;

  /// Duration of internship in weeks (if start and end dates exist)
  int? get durationInWeeks {
    if (startDate == null || endDate == null) return null;
    final days = endDate!.difference(startDate!).inDays;
    if (days < 0) return 0;
    return (days / 7).ceil();
  }

  /// Profile completion score (0 to 100%)
  int get profileCompletionPercentage {
    int filled = 0;
    const totalFields = 7;
    if (studentName.isNotEmpty && studentName != 'Unknown Student') filled++;
    if (studentEmail.isNotEmpty && studentEmail != 'N/A') filled++;
    if (rollNumber != null && rollNumber!.isNotEmpty) filled++;
    if (department != null && department!.isNotEmpty) filled++;
    if (batchYear != null) filled++;
    if (phone != null && phone!.isNotEmpty) filled++;
    if (address != null && address!.isNotEmpty) filled++;
    return ((filled / totalFields) * 100).round();
  }
}

class StudentApprovalReviewItem {
  final String id;
  final String reviewStage;
  final String status;
  final String? remarks;
  final DateTime? createdAt;

  const StudentApprovalReviewItem({
    required this.id,
    required this.reviewStage,
    required this.status,
    this.remarks,
    this.createdAt,
  });
}
