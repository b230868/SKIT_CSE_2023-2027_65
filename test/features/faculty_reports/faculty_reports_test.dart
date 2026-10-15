import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_reports/data/repositories/faculty_report_repository_factory.dart';
import 'package:prashikshan/features/faculty_reports/data/repositories/mock_faculty_report_repository.dart';
import 'package:prashikshan/features/faculty_reports/data/services/faculty_report_service.dart';
import 'package:prashikshan/features/faculty_reports/domain/entities/faculty_report_data.dart';
import 'package:prashikshan/features/faculty_reports/presentation/screens/faculty_reports_screen.dart';

void main() {
  group('FacultyReportData Entity Tests', () {
    test('calculates approval rate accurately', () {
      const report = FacultyReportData(
        totalInternships: 20,
        approvedInternships: 15,
        pendingApprovals: 3,
        underReviewApprovals: 1,
        rejectedApplications: 1,
        facultyStageCount: 2,
        tpStageCount: 2,
        departmentSummary: {'CSE': 10, 'ECE': 10},
      );

      expect(report.approvalRate, closeTo(75.0, 0.01));
      expect(report.totalInternships, equals(20));
      expect(report.approvedInternships, equals(15));
      expect(report.facultyStageCount, equals(2));
      expect(report.tpStageCount, equals(2));
    });

    test('handles zero total internships without division by zero', () {
      const report = FacultyReportData(
        totalInternships: 0,
        approvedInternships: 0,
        pendingApprovals: 0,
        underReviewApprovals: 0,
        rejectedApplications: 0,
        facultyStageCount: 0,
        tpStageCount: 0,
        departmentSummary: {},
      );

      expect(report.approvalRate, equals(0.0));
    });

    test('defaults departmentSummary to empty map when omitted', () {
      const report = FacultyReportData(
        totalInternships: 10,
        approvedInternships: 5,
        pendingApprovals: 2,
        underReviewApprovals: 1,
        rejectedApplications: 2,
        facultyStageCount: 1,
        tpStageCount: 1,
      );

      expect(report.departmentSummary, isEmpty);
      expect(report.approvalRate, equals(50.0));
    });
  });

  group('FacultyReport Service & Repository Tests', () {
    test('Mock repository returns valid report metrics', () async {
      final repo = MockFacultyReportRepository();
      final data = await repo.getReportData();

      expect(data.totalInternships, equals(48));
      expect(data.approvedInternships, equals(28));
      expect(data.departmentSummary.isNotEmpty, isTrue);
    });

    test('Service delegates to repository', () async {
      final repo = MockFacultyReportRepository();
      final service = FacultyReportService(repository: repo);
      final data = await service.loadReportData();

      expect(data.totalInternships, equals(48));
      expect(data.approvedInternships, equals(28));
      expect(data.approvalRate, closeTo(58.33, 0.1));
    });

    test('Factory creates repository without crashing', () {
      final repo = FacultyReportRepositoryFactory.create();
      expect(repo, isNotNull);
    });
  });

  group('FacultyReportsScreen Widget Tests', () {
    testWidgets('renders all report sections and metric titles', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FacultyReportsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Faculty & T&P Reports'), findsOneWidget);
      expect(find.text('Internship Overview'), findsOneWidget);
      expect(find.text('Total Internships'), findsOneWidget);
      expect(find.text('Approval Rate'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Pending Approvals'), findsOneWidget);
      expect(find.text('Under Review'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Stage Distribution'), findsOneWidget);
      expect(find.text('Faculty Review Stage'), findsOneWidget);
      expect(find.text('T&P Review Stage'), findsOneWidget);
      expect(find.text('Department Breakdown'), findsOneWidget);
    });

    testWidgets('refresh icon button triggers reload', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FacultyReportsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final refreshButton = find.byTooltip('Refresh');
      expect(refreshButton, findsOneWidget);

      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      expect(find.text('Faculty & T&P Reports'), findsOneWidget);
    });
  });
}
