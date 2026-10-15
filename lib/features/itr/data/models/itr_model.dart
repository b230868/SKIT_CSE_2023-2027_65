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
  });

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
    };
  }
}
