import '../models/student_monitoring_item.dart';

abstract class StudentMonitoringRepository {
  Future<List<StudentMonitoringItem>> getStudents();
}