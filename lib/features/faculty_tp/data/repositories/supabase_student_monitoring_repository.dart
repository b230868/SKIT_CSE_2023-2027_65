
import '../models/student_monitoring_item.dart';
import 'student_monitoring_repository.dart';

class SupabaseStudentMonitoringRepository
    implements StudentMonitoringRepository {
  SupabaseStudentMonitoringRepository();

  @override
  Future<List<StudentMonitoringItem>> getStudents() async {
    throw UnimplementedError(
      'Supabase student monitoring queries will be implemented '
      'after the shared database schema is available.',
    );
  }
}

