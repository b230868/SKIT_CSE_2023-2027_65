import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'student_monitoring_repository.dart';
import 'mock_student_monitoring_repository.dart';
import 'supabase_student_monitoring_repository.dart';
import 'backend_student_monitoring_repository.dart';

class StudentMonitoringRepositoryFactory {
  static StudentMonitoringRepository? _override;
  static bool useBackendApi = false;

  static void setRepository(StudentMonitoringRepository repository) {
    _override = repository;
  }

  static void reset() {
    _override = null;
    useBackendApi = false;
  }

  static StudentMonitoringRepository create() {
    if (_override != null) return _override!;

    final envUseBackend =
        dotenv.isInitialized && dotenv.env['USE_BACKEND_API'] == 'true';

    if (useBackendApi || envUseBackend) {
      return BackendStudentMonitoringRepository();
    }

    try {
      Supabase.instance.client;
      return SupabaseStudentMonitoringRepository();
    } catch (_) {
      return MockStudentMonitoringRepository();
    }
  }

  static StudentMonitoringRepository createBackend() {
    return BackendStudentMonitoringRepository();
  }
}