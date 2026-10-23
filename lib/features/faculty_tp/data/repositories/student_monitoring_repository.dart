import '../models/student_monitoring_detail.dart';
import '../models/student_monitoring_item.dart';

abstract class StudentMonitoringRepository {
  Future<List<StudentMonitoringItem>> getStudents();

  Future<StudentMonitoringDetail?> getStudentDetails(
    String studentId, {
    String? internshipId,
  });

  Future<String?> getFileUrl({required String bucket, required String path});

  Future<void> verifyStudentDocument({
    required String documentId,
    required String status,
    String? rejectionReason,
    String? remarks,
  }) async {}

}
