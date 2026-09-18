import '../../domain/entities/dashboard_statistics.dart';

abstract class FacultyDashboardRepository {
  Future<DashboardStatistics> getDashboardStatistics();
}