import 'student_monitoring_item.dart';

class MockStudentMonitoringData {
  static const List<StudentMonitoringItem> students = [
    StudentMonitoringItem(
      studentId: 'student-001',
      studentName: 'Demo Student 1',
      internshipId: 'internship-001',
      internshipTitle: 'Software Development Internship',
      applicationStatus: 'pending',
    ),
    StudentMonitoringItem(
      studentId: 'student-002',
      studentName: 'Demo Student 2',
      internshipId: 'internship-002',
      internshipTitle: 'Data Analytics Internship',
      applicationStatus: 'approved',
    ),
  ];
}