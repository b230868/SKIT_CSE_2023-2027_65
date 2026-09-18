import '../models/mock_dashboard_data.dart';
import '../../domain/entities/dashboard_statistics.dart';
import 'faculty_dashboard_repository.dart';

class MockFacultyDashboardRepository
    implements FacultyDashboardRepository {
  @override
  Future<DashboardStatistics> getDashboardStatistics() async {
    await Future.delayed(const Duration(seconds: 1));

    return MockDashboardData.statistics;
  }
}