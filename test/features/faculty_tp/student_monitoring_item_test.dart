import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/data/models/student_monitoring_item.dart';

void main() {
  test('student monitoring item stores correct data', () {
    const item = StudentMonitoringItem(
      studentId: 'student-001',
      studentName: 'Demo Student',
      internshipId: 'internship-001',
      internshipTitle: 'Software Development Internship',
      applicationStatus: 'pending',
    );

    expect(item.studentId, 'student-001');
    expect(item.studentName, 'Demo Student');
    expect(item.internshipId, 'internship-001');
    expect(item.internshipTitle, 'Software Development Internship');
    expect(item.applicationStatus, 'pending');
  });
}