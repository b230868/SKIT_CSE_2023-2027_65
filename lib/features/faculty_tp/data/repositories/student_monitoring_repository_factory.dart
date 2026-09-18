import 'student_monitoring_repository.dart';
import 'mock_student_monitoring_repository.dart';

class StudentMonitoringRepositoryFactory {
  static StudentMonitoringRepository create() {
    return MockStudentMonitoringRepository();
  }
}