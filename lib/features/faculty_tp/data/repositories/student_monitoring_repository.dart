import '../models/student_monitoring_detail.dart';
import '../models/student_monitoring_item.dart';

abstract class StudentMonitoringRepository {
  Future<List<StudentMonitoringItem>> getStudents();

  Future<StudentMonitoringDetail?> getStudentDetails(
    String studentId, {
    String? internshipId,
  });

  Future<String?> getFileUrl({required String bucket, required String path});
}
