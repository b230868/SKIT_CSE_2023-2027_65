import '../models/mock_student_monitoring_data.dart';
import '../models/student_monitoring_detail.dart';
import '../models/student_monitoring_item.dart';
import 'student_monitoring_repository.dart';

class MockStudentMonitoringRepository implements StudentMonitoringRepository {
  @override
  Future<List<StudentMonitoringItem>> getStudents() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return MockStudentMonitoringData.students;
  }

  @override
  Future<StudentMonitoringDetail?> getStudentDetails(
    String studentId, {
    String? internshipId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return MockStudentMonitoringData.getDetails(studentId);
  }

  @override
  Future<String?> getFileUrl({
    required String bucket,
    required String path,
  }) async {
    return 'https://example.com/files/$bucket/$path';
  }
}
