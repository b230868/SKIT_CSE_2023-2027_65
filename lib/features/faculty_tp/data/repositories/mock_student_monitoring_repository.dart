import '../models/mock_student_monitoring_data.dart';
import '../models/student_monitoring_item.dart';
import 'student_monitoring_repository.dart';

class MockStudentMonitoringRepository
    implements StudentMonitoringRepository {
  @override
  Future<List<StudentMonitoringItem>> getStudents() async {
    await Future.delayed(const Duration(seconds: 1));

    return MockStudentMonitoringData.students;
  }
}