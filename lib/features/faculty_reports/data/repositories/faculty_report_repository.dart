import '../../domain/entities/faculty_report_data.dart';

abstract class FacultyReportRepository {
  Future<FacultyReportData> getReportData();
}
