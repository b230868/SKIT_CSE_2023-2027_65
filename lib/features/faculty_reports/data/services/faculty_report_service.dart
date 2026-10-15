import '../../domain/entities/faculty_report_data.dart';
import '../repositories/faculty_report_repository.dart';

class FacultyReportService {
  final FacultyReportRepository repository;

  FacultyReportService({required this.repository});

  Future<FacultyReportData> loadReportData() {
    return repository.getReportData();
  }
}
