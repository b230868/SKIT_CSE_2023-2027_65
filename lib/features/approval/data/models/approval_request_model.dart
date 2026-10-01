import '../../domain/entities/approval_status.dart';

class ApprovalRequestModel {
  final String internshipId;
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String internshipTitle;
  final String industryId;
  final String industryName;
  final String internshipStatus;
  final ApprovalStatus approvalStatus;

  const ApprovalRequestModel({
    required this.internshipId,
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.internshipTitle,
    required this.industryId,
    required this.industryName,
    required this.internshipStatus,
    required this.approvalStatus,
  });

  factory ApprovalRequestModel.fromMap(Map<String, dynamic> map) {
    return ApprovalRequestModel(
      internshipId: map['internship_id'] as String,
      studentId: map['student_id'] as String,
      studentName: map['student_name'] as String? ?? 'Unknown Student',
      rollNumber: map['roll_number'] as String? ?? '',
      internshipTitle:
          map['internship_title'] as String? ?? 'Untitled Internship',
      industryId: map['industry_id'] as String,
      industryName: map['industry_name'] as String? ?? 'Unknown Industry',
      internshipStatus:
          map['internship_status'] as String? ?? 'unknown',
      approvalStatus: ApprovalStatus.values.firstWhere(
        (status) => status.value == map['approval_status'],
        orElse: () => ApprovalStatus.pending,
      ),
    );
  }
}