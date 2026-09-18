
import '../models/student_monitoring_item.dart';
import '../repositories/student_monitoring_repository.dart';

class StudentMonitoringService {
  final StudentMonitoringRepository repository;

  StudentMonitoringService({
    required this.repository,
  });

  Future<List<StudentMonitoringItem>> loadStudents() async {
    return repository.getStudents();
  }
}

