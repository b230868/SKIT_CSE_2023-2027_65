import '../../domain/entities/faculty_report_data.dart';

class MockFacultyReportData {
  static const FacultyReportData sampleReport = FacultyReportData(
    totalInternships: 48,
    pendingApprovals: 12,
    underReviewApprovals: 4,
    approvedInternships: 28,
    rejectedApplications: 4,
    facultyStageCount: 10,
    tpStageCount: 6,
    departmentSummary: {
      'Computer Science': 24,
      'Information Technology': 14,
      'Electronics': 10,
    },
  );
}
