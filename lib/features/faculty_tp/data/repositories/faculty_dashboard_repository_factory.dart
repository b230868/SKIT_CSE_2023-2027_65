import 'faculty_dashboard_repository.dart';
import 'mock_faculty_dashboard_repository.dart';

class FacultyDashboardRepositoryFactory {
  static FacultyDashboardRepository create() {
    return MockFacultyDashboardRepository();
  }
}