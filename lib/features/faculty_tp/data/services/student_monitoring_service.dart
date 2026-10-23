import '../models/student_monitoring_detail.dart';
import '../models/student_monitoring_item.dart';
import '../repositories/student_monitoring_repository.dart';

class StudentMonitoringService {
  final StudentMonitoringRepository repository;

  StudentMonitoringService({required this.repository});

  Future<List<StudentMonitoringItem>> loadStudents() async {
    return repository.getStudents();
  }

  Future<StudentMonitoringDetail?> loadStudentDetails(
    String studentId, {
    String? internshipId,
  }) async {
    return repository.getStudentDetails(studentId, internshipId: internshipId);
  }

  Future<String?> getFileUrl({
    required String bucket,
    required String path,
  }) async {
    return repository.getFileUrl(bucket: bucket, path: path);
  }

  Future<void> verifyStudentDocument({
    required String documentId,
    required String status,
    String? rejectionReason,
    String? remarks,
  }) {
    throw UnsupportedError(
      'Document verification is not supported by the configured repository.',
    );
  }
}
