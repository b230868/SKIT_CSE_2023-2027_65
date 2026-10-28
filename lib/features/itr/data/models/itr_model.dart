class ItrModel {
  final String id;
  final String internshipId;
  final String studentId;
  final String studentName;
  final String internshipTitle;
  final String companyName;
  final String status;

  final String? content;
  final String? workDone;
  final String? technologiesUsed;
  final String? keyLearnings;
  final String? challengesFaced;

  final String? documentPath;
  final String? projectZipPath;
  final String? presentationPath;

  final DateTime? submittedAt;
  final String? reviewerName;
  final String? remarks;

  final String? certificateStatus;
  final String? certificateUrl;
  final double? evaluationScore;
  final String? evaluationGrade;

  const ItrModel({
    required this.id,
    required this.internshipId,
    required this.studentId,
    required this.studentName,
    required this.internshipTitle,
    required this.companyName,
    required this.status,
    this.content,
    this.workDone,
    this.technologiesUsed,
    this.keyLearnings,
    this.challengesFaced,
    this.documentPath,
    this.projectZipPath,
    this.presentationPath,
    this.submittedAt,
    this.reviewerName,
    this.remarks,
    this.certificateStatus,
    this.certificateUrl,
    this.evaluationScore,
    this.evaluationGrade,
  });

  bool get isCertificateVerified => certificateStatus == 'verified';

  factory ItrModel.fromMap(Map<String, dynamic> map) {
    return ItrModel(
      id: map['id']?.toString() ?? '',
      internshipId: map['internship_id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      studentName: map['student_name']?.toString() ?? 'Unknown Student',
      internshipTitle:
          map['internship_title']?.toString() ?? 'Unknown Internship',
      companyName: map['company_name']?.toString() ?? 'Unknown Company',
      status: map['status']?.toString() ?? 'draft',
      content: map['content']?.toString(),
      workDone: map['work_done']?.toString(),
      technologiesUsed: map['technologies_used']?.toString(),
      keyLearnings: map['key_learnings']?.toString(),
      challengesFaced: map['challenges_faced']?.toString(),
      documentPath: map['document_path']?.toString(),
      projectZipPath: map['project_zip_path']?.toString(),
      presentationPath: map['presentation_path']?.toString(),
      submittedAt: map['submitted_at'] != null
          ? DateTime.tryParse(map['submitted_at'].toString())
          : null,
      reviewerName: map['reviewer_name']?.toString(),
      remarks: map['remarks']?.toString(),
      certificateStatus: map['certificate_status']?.toString(),
      certificateUrl: map['certificate_url']?.toString(),
      evaluationScore: (map['evaluation_score'] as num?)?.toDouble(),
      evaluationGrade: map['evaluation_grade']?.toString(),
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
      'status': status,
      'content': content,
      'work_done': workDone,
      'technologies_used': technologiesUsed,
      'key_learnings': keyLearnings,
      'challenges_faced': challengesFaced,
      'document_path': documentPath,
      'project_zip_path': projectZipPath,
      'presentation_path': presentationPath,
      'submitted_at': submittedAt?.toIso8601String(),
      'reviewer_name': reviewerName,
      'remarks': remarks,
      'certificate_status': certificateStatus,
      'certificate_url': certificateUrl,
      'evaluation_score': evaluationScore,
      'evaluation_grade': evaluationGrade,
    };
  }

  ItrModel copyWith({
    String? id,
    String? internshipId,
    String? studentId,
    String? studentName,
    String? internshipTitle,
    String? companyName,
    String? status,
    String? content,
    String? workDone,
    String? technologiesUsed,
    String? keyLearnings,
    String? challengesFaced,
    String? documentPath,
    String? projectZipPath,
    String? presentationPath,
    DateTime? submittedAt,
    String? reviewerName,
    String? remarks,
    String? certificateStatus,
    String? certificateUrl,
    double? evaluationScore,
    String? evaluationGrade,
  }) {
    return ItrModel(
      id: id ?? this.id,
      internshipId: internshipId ?? this.internshipId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      internshipTitle: internshipTitle ?? this.internshipTitle,
      companyName: companyName ?? this.companyName,
      status: status ?? this.status,
      content: content ?? this.content,
      workDone: workDone ?? this.workDone,
      technologiesUsed: technologiesUsed ?? this.technologiesUsed,
      keyLearnings: keyLearnings ?? this.keyLearnings,
      challengesFaced: challengesFaced ?? this.challengesFaced,
      documentPath: documentPath ?? this.documentPath,
      projectZipPath: projectZipPath ?? this.projectZipPath,
      presentationPath: presentationPath ?? this.presentationPath,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewerName: reviewerName ?? this.reviewerName,
      remarks: remarks ?? this.remarks,
      certificateStatus: certificateStatus ?? this.certificateStatus,
      certificateUrl: certificateUrl ?? this.certificateUrl,
      evaluationScore: evaluationScore ?? this.evaluationScore,
      evaluationGrade: evaluationGrade ?? this.evaluationGrade,
    );
  }
}
