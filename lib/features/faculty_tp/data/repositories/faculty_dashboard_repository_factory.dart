import 'package:supabase_flutter/supabase_flutter.dart';

import 'faculty_dashboard_repository.dart';
import 'mock_faculty_dashboard_repository.dart';
import 'supabase_faculty_dashboard_repository.dart';

class FacultyDashboardRepositoryFactory {
  static FacultyDashboardRepository? _override;

  static void setRepository(FacultyDashboardRepository repository) {
    _override = repository;
  }

  static void reset() {
    _override = null;
  }

  static FacultyDashboardRepository create() {
    if (_override != null) return _override!;
    try {
      Supabase.instance.client;
      return SupabaseFacultyDashboardRepository();
    } catch (_) {
      return MockFacultyDashboardRepository();
    }
  }
}