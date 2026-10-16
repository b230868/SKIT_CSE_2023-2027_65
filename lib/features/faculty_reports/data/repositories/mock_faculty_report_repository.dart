import '../../domain/entities/faculty_report_data.dart';
import '../models/mock_faculty_report_data.dart';
import 'faculty_report_repository.dart';

class MockFacultyReportRepository implements FacultyReportRepository {
  @override
  Future<FacultyReportData> getReportData() async {
    return MockFacultyReportData.sampleReport;
  }
}
