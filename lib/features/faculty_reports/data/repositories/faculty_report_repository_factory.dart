import 'package:supabase_flutter/supabase_flutter.dart';

import 'faculty_report_repository.dart';
import 'mock_faculty_report_repository.dart';
import 'supabase_faculty_report_repository.dart';

class FacultyReportRepositoryFactory {
  static FacultyReportRepository? _override;

  static void setRepository(FacultyReportRepository repository) {
    _override = repository;
  }

  static void reset() {
    _override = null;
  }

  static FacultyReportRepository create() {
    if (_override != null) return _override!;
    try {
      Supabase.instance.client;
      return SupabaseFacultyReportRepository();
    } catch (_) {
      return MockFacultyReportRepository();
    }
  }
}
