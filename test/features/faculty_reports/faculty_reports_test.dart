import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_reports/data/repositories/faculty_report_repository.dart';
import 'package:prashikshan/features/faculty_reports/data/services/faculty_report_service.dart';
import 'package:prashikshan/features/faculty_reports/domain/entities/faculty_report_data.dart';

class FakeFacultyReportRepository implements FacultyReportRepository {
  final FacultyReportData data;

  FakeFacultyReportRepository({required this.data});

  @override
  Future<FacultyReportData> getReportData() async {
    return data;
  }
}

void main() {
  group('Faculty Reports & Analytics Unit Tests', () {
    test('approvalRate returns 0.0 when totalInternships is 0', () {
      const report = FacultyReportData(
        totalInternships: 0,
        pendingApprovals: 0,
        underReviewApprovals: 0,
        approvedInternships: 0,
        rejectedApplications: 0,
        facultyStageCount: 0,
        tpStageCount: 0,
      );

      expect(report.approvalRate, equals(0.0));
    });

    test('approvalRate calculates percentage correctly', () {
      const report = FacultyReportData(
        totalInternships: 50,
        pendingApprovals: 10,
        underReviewApprovals: 5,
        approvedInternships: 35,
        rejectedApplications: 5,
        facultyStageCount: 20,
        tpStageCount: 30,
        departmentSummary: {'Computer Science': 30, 'Mechanical': 20},
      );

      expect(report.approvalRate, equals(70.0));
      expect(report.totalInternships, equals(50));
      expect(report.approvedInternships, equals(35));
      expect(report.departmentSummary['Computer Science'], equals(30));
    });

    test('FacultyReportService loads report data accurately', () async {
      const expectedData = FacultyReportData(
        totalInternships: 100,
        pendingApprovals: 20,
        underReviewApprovals: 10,
        approvedInternships: 65,
        rejectedApplications: 5,
        facultyStageCount: 40,
        tpStageCount: 60,
      );

      final fakeRepo = FakeFacultyReportRepository(data: expectedData);
      final service = FacultyReportService(repository: fakeRepo);

      final result = await service.loadReportData();
      expect(result.totalInternships, equals(100));
      expect(result.approvedInternships, equals(65));
      expect(result.approvalRate, equals(65.0));
    });
  });
}

