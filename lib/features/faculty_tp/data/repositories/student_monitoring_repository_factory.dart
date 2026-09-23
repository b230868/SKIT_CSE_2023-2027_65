import 'package:supabase_flutter/supabase_flutter.dart';

import 'student_monitoring_repository.dart';
import 'mock_student_monitoring_repository.dart';
import 'supabase_student_monitoring_repository.dart';

class StudentMonitoringRepositoryFactory {
  static StudentMonitoringRepository? _override;

  static void setRepository(StudentMonitoringRepository repository) {
    _override = repository;
  }

  static void reset() {
    _override = null;
  }

  static StudentMonitoringRepository create() {
    if (_override != null) return _override!;
    try {
      Supabase.instance.client;
      return SupabaseStudentMonitoringRepository();
    } catch (_) {
      return MockStudentMonitoringRepository();
    }
  }
}