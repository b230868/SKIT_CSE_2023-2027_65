import '../repositories/faculty_dashboard_repository.dart';
import '../../domain/entities/dashboard_statistics.dart';

class FacultyDashboardService {
  final FacultyDashboardRepository repository;

  FacultyDashboardService({
    required this.repository,
  });

  Future<DashboardStatistics> loadStatistics() async {
    try {
      return await repository.getDashboardStatistics();
    } catch (e) {
      throw Exception('Failed to load dashboard statistics');
    }
  }
}