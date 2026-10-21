class IndustryInternshipModel {
  final String id;
  final String studentName;
  final String internshipTitle;
  final String status;
  final double progress;
  final String itrStatus;
  final String evaluationStatus;
  final String? studentId;
  final String? studentRollNo;
  final String? branch;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? companyName;
  final double? attendanceRate;
  final String
  offerLetterStatus; // 'pending' | 'issued' | 'verified' | 'rejected'
  final String? offerLetterUrl;
  final String
  certificateStatus; // 'pending' | 'issued' | 'verified' | 'rejected'
  final String? certificateUrl;

  const IndustryInternshipModel({
    required this.id,
    required this.studentName,
    required this.internshipTitle,
    required this.status,
    required this.progress,
    required this.itrStatus,
    required this.evaluationStatus,
    this.studentId,
    this.studentRollNo,
    this.branch,
    this.startDate,
    this.endDate,
    this.companyName,
    this.attendanceRate,
    this.offerLetterStatus = 'pending',
    this.offerLetterUrl,
    this.certificateStatus = 'pending',
    this.certificateUrl,
  });

  factory IndustryInternshipModel.fromMap(Map<String, dynamic> map) {
    return IndustryInternshipModel(
      id: map['id']?.toString() ?? '',
      studentName: map['student_name']?.toString() ?? 'Student',
      internshipTitle: map['internship_title']?.toString() ?? 'Internship',
      status: map['status']?.toString() ?? 'planned',
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      itrStatus: map['itr_status']?.toString() ?? 'draft',
      evaluationStatus: map['evaluation_status']?.toString() ?? 'pending',
      studentId: map['student_id']?.toString(),
      studentRollNo:
          map['student_roll_no']?.toString() ?? map['roll_number']?.toString(),
      branch: map['branch']?.toString(),
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'].toString())
          : null,
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'].toString())
          : null,
      companyName: map['company_name']?.toString(),
      attendanceRate: (map['attendance_rate'] as num?)?.toDouble(),
      offerLetterStatus: map['offer_letter_status']?.toString() ?? 'pending',
      offerLetterUrl: map['offer_letter_url']?.toString(),
      certificateStatus: map['certificate_status']?.toString() ?? 'pending',
      certificateUrl: map['certificate_url']?.toString(),
    );
  }

  IndustryInternshipModel copyWith({
    String? id,
    String? studentName,
    String? internshipTitle,
    String? status,
    double? progress,
    String? itrStatus,
    String? evaluationStatus,
    String? studentId,
    String? studentRollNo,
    String? branch,
    DateTime? startDate,
    DateTime? endDate,
    String? companyName,
    double? attendanceRate,
    String? offerLetterStatus,
    String? offerLetterUrl,
    String? certificateStatus,
    String? certificateUrl,
  }) {
    return IndustryInternshipModel(
      id: id ?? this.id,
      studentName: studentName ?? this.studentName,
      internshipTitle: internshipTitle ?? this.internshipTitle,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      itrStatus: itrStatus ?? this.itrStatus,
      evaluationStatus: evaluationStatus ?? this.evaluationStatus,
      studentId: studentId ?? this.studentId,
      studentRollNo: studentRollNo ?? this.studentRollNo,
      branch: branch ?? this.branch,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      companyName: companyName ?? this.companyName,
      attendanceRate: attendanceRate ?? this.attendanceRate,
      offerLetterStatus: offerLetterStatus ?? this.offerLetterStatus,
      offerLetterUrl: offerLetterUrl ?? this.offerLetterUrl,
      certificateStatus: certificateStatus ?? this.certificateStatus,
      certificateUrl: certificateUrl ?? this.certificateUrl,
    );
  }
}
