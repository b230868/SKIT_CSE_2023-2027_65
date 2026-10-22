
class IndustryEvaluationModel {
  final String id;
  final String internshipId;
  final String studentId;
  final String studentName;
  final String internshipTitle;
  final String companyName;
  final String? industryId;
  final String? evaluatorId;

  // Criteria scores (each 0 - 20, summing to total score 0 - 100)
  final double technicalSkillsScore;
  final double workQualityScore;
  final double attendanceScore;
  final double initiativeScore;
  final double communicationScore;

  final double totalScore;
  final String grade;
  final String status; // 'pending', 'in_progress', 'verified', 'completed'
  final String? feedback;
  final String? remarks;
  final DateTime? evaluationDate;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;

  const IndustryEvaluationModel({
    required this.id,
    required this.internshipId,
    required this.studentId,
    required this.studentName,
    required this.internshipTitle,
    required this.companyName,
    this.industryId,
    this.evaluatorId,
    this.technicalSkillsScore = 0,
    this.workQualityScore = 0,
    this.attendanceScore = 0,
    this.initiativeScore = 0,
    this.communicationScore = 0,
    required this.totalScore,
    required this.grade,
    required this.status,
    this.feedback,
    this.remarks,
    this.evaluationDate,
    this.submittedAt,
    this.verifiedAt,
  });

  static String calculateGrade(double totalScore) {
    if (totalScore >= 90) return 'A+';
    if (totalScore >= 80) return 'A';
    if (totalScore >= 70) return 'B+';
    if (totalScore >= 60) return 'B';
    if (totalScore >= 50) return 'C';
    return 'F';
  }

  factory IndustryEvaluationModel.fromMap(Map<String, dynamic> map) {
    final tech = (map['technical_skills_score'] as num?)?.toDouble() ?? 0.0;
    final quality = (map['work_quality_score'] as num?)?.toDouble() ?? 0.0;
    final att = (map['attendance_score'] as num?)?.toDouble() ?? 0.0;
    final init = (map['initiative_score'] as num?)?.toDouble() ?? 0.0;
    final comm = (map['communication_score'] as num?)?.toDouble() ?? 0.0;

    final computedTotal =
        (map['total_score'] as num?)?.toDouble() ??
        (map['score'] as num?)?.toDouble() ??
        (map['marks'] as num?)?.toDouble() ??
        (tech + quality + att + init + comm);

    final gradeVal = map['grade']?.toString() ?? calculateGrade(computedTotal);

    return IndustryEvaluationModel(
      id: map['id']?.toString() ?? '',
      internshipId: map['internship_id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      studentName: map['student_name']?.toString() ?? 'Student',
      internshipTitle: map['internship_title']?.toString() ?? 'Internship',
      companyName: map['company_name']?.toString() ?? 'Company',
      industryId: map['industry_id']?.toString(),
      evaluatorId: map['evaluator_id']?.toString(),
      technicalSkillsScore: tech,
      workQualityScore: quality,
      attendanceScore: att,
      initiativeScore: init,
      communicationScore: comm,
      totalScore: computedTotal.clamp(0.0, 100.0),
      grade: gradeVal,
      status: map['status']?.toString() ?? 'pending',
      feedback: map['feedback']?.toString(),
      remarks: map['remarks']?.toString(),
      evaluationDate: map['evaluation_date'] != null
          ? DateTime.tryParse(map['evaluation_date'].toString())
          : null,
      submittedAt: map['submitted_at'] != null
          ? DateTime.tryParse(map['submitted_at'].toString())
          : null,
      verifiedAt: map['verified_at'] != null
          ? DateTime.tryParse(map['verified_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'internship_id': internshipId,
      'student_id': studentId,
      'student_name': studentName,
      'internship_title': internshipTitle,
      'company_name': companyName,
      'industry_id': industryId,
      'evaluator_id': evaluatorId,
      'technical_skills_score': technicalSkillsScore,
      'work_quality_score': workQualityScore,
      'attendance_score': attendanceScore,
      'initiative_score': initiativeScore,
      'communication_score': communicationScore,
      'total_score': totalScore,
      'score': totalScore,
      'marks': totalScore,
      'grade': grade,
      'status': status,
      'feedback': feedback,
      'remarks': remarks,
      'evaluation_date': evaluationDate?.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
    };
  }

  IndustryEvaluationModel copyWith({
    String? id,
    String? internshipId,
    String? studentId,
    String? studentName,
    String? internshipTitle,
    String? companyName,
    String? industryId,
    String? evaluatorId,
    double? technicalSkillsScore,
    double? workQualityScore,
    double? attendanceScore,
    double? initiativeScore,
    double? communicationScore,
    double? totalScore,
    String? grade,
    String? status,
    String? feedback,
    String? remarks,
    DateTime? evaluationDate,
    DateTime? submittedAt,
    DateTime? verifiedAt,
  }) {
    final newTech = technicalSkillsScore ?? this.technicalSkillsScore;
    final newQuality = workQualityScore ?? this.workQualityScore;
    final newAtt = attendanceScore ?? this.attendanceScore;
    final newInit = initiativeScore ?? this.initiativeScore;
    final newComm = communicationScore ?? this.communicationScore;
    final computedTotal =
        totalScore ?? (newTech + newQuality + newAtt + newInit + newComm);

    return IndustryEvaluationModel(
      id: id ?? this.id,
      internshipId: internshipId ?? this.internshipId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      internshipTitle: internshipTitle ?? this.internshipTitle,
      companyName: companyName ?? this.companyName,
      industryId: industryId ?? this.industryId,
      evaluatorId: evaluatorId ?? this.evaluatorId,
      technicalSkillsScore: newTech,
      workQualityScore: newQuality,
      attendanceScore: newAtt,
      initiativeScore: newInit,
      communicationScore: newComm,
      totalScore: computedTotal.clamp(0.0, 100.0),
      grade: grade ?? calculateGrade(computedTotal),
      status: status ?? this.status,
      feedback: feedback ?? this.feedback,
      remarks: remarks ?? this.remarks,
      evaluationDate: evaluationDate ?? this.evaluationDate,
      submittedAt: submittedAt ?? this.submittedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}

class IndustryVerificationModel {
  final String id;
  final String internshipId;
  final String? itrId;
  final String? verifierId;
  final String status; // 'pending', 'verified', 'rejected'
  final String? remarks;
  final DateTime? verifiedAt;

  const IndustryVerificationModel({
    required this.id,
    required this.internshipId,
    this.itrId,
    this.verifierId,
    required this.status,
    this.remarks,
    this.verifiedAt,
  });

  factory IndustryVerificationModel.fromMap(Map<String, dynamic> map) {
    return IndustryVerificationModel(
      id: map['id']?.toString() ?? '',
      internshipId: map['internship_id']?.toString() ?? '',
      itrId: map['itr_id']?.toString(),
      verifierId: map['verifier_id']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      remarks: map['remarks']?.toString(),
      verifiedAt: map['verified_at'] != null
          ? DateTime.tryParse(map['verified_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'internship_id': internshipId,
      'itr_id': itrId,
      'verifier_id': verifierId,
      'status': status,
      'remarks': remarks,
      'verified_at': verifiedAt?.toIso8601String(),
    };
  }
}


class IndustryAnalyticsData {
  final String industryName;
  final int totalInterns;
  final int activeInterns;
  final int completedInternships;
  final int pendingAttendance;
  final double attendanceRate;
  final int pendingEvaluations;
  final int completedEvaluations;
  final int pendingCertificates;
  final int issuedCertificates;
  final int pendingOfferLetters;
  final int issuedOfferLetters;
  final double? averageScore;
  final Map<String, int> gradeDistribution;
  final Map<String, int> progressBands;

  // Optional backward compatible fields (deprecated, not displayed in UI)
  final int pendingItrs;
  final int submittedItrs;
  final int approvedItrs;

  const IndustryAnalyticsData({
    required this.industryName,
    required this.totalInterns,
    required this.activeInterns,
    required this.completedInternships,
    this.pendingAttendance = 0,
    this.attendanceRate = 0.0,
    required this.pendingEvaluations,
    required this.completedEvaluations,
    this.pendingCertificates = 0,
    this.issuedCertificates = 0,
    this.pendingOfferLetters = 0,
    this.issuedOfferLetters = 0,
    this.averageScore,
    this.gradeDistribution = const {},
    this.progressBands = const {},
    this.pendingItrs = 0,
    this.submittedItrs = 0,
    this.approvedItrs = 0,
  });
}
