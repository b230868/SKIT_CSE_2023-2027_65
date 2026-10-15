class IndustryInternshipModel {
  final String id;
  final String studentName;
  final String internshipTitle;
  final String status;
  final double progress;
  final String itrStatus;
  final String evaluationStatus;

  const IndustryInternshipModel({
    required this.id,
    required this.studentName,
    required this.internshipTitle,
    required this.status,
    required this.progress,
    required this.itrStatus,
    required this.evaluationStatus,
  });

  factory IndustryInternshipModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return IndustryInternshipModel(
      id: map['id']?.toString() ?? '',
      studentName:
          map['student_name']?.toString() ?? 'Student',
      internshipTitle:
          map['internship_title']?.toString() ??
              'Internship',
      status:
          map['status']?.toString() ?? 'planned',
      progress:
          (map['progress'] as num?)?.toDouble() ?? 0,
      itrStatus:
          map['itr_status']?.toString() ?? 'draft',
      evaluationStatus:
          map['evaluation_status']?.toString() ??
              'pending',
    );
  }
}