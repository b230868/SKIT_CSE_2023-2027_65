import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/industry_dashboard_data.dart';
import 'package:prashikshan/features/industry/data/models/industry_internship_model.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_repository.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_attendance_screen.dart';

class FailingAttendanceRepo extends MockIndustryRepository {
  bool failInternships = false;
  bool failAttendance = false;

  @override
  Future<List<IndustryInternshipModel>> getIndustryInternships() async {
    if (failInternships) {
      throw Exception('Failed to fetch assigned interns.');
    }
    return super.getIndustryInternships();
  }

  @override
  Future<void> markAttendance({
    required String internshipId,
    required String studentId,
    required DateTime date,
    required String status,
    String? remarks,
  }) async {
    if (failAttendance) {
      throw Exception('Database write rejected: network error.');
    }
    return super.markAttendance(
      internshipId: internshipId,
      studentId: studentId,
      date: date,
      status: status,
      remarks: remarks,
    );
  }
}

void main() {
  group('IndustryAttendanceScreen Widget & Flow Tests', () {
    testWidgets('renders header, date selector, and eligible interns list', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockIndustryRepository(companyName: 'TechNova Solutions');
      final service = IndustryService(repository: repo);

      await tester.pumpWidget(
        MaterialApp(home: IndustryAttendanceScreen(service: service)),
      );

      // Loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Header and date selector
      expect(find.text('Attendance Management'), findsOneWidget);
      expect(find.text('Attendance Date'), findsOneWidget);
      expect(find.text('Change Date'), findsOneWidget);
      expect(find.text('Mark Daily Attendance'), findsOneWidget);

      // Interns
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Priya Singh'), findsOneWidget);

      // Controls: Present, Absent, Leave segments
      expect(find.text('Present'), findsWidgets);
      expect(find.text('Absent'), findsWidgets);
      expect(find.text('Leave'), findsWidgets);
    });

    testWidgets('marks Present and updates status indicator and history', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockIndustryRepository(companyName: 'TechNova Solutions');
      final service = IndustryService(repository: repo);

      await tester.pumpWidget(
        MaterialApp(home: IndustryAttendanceScreen(service: service)),
      );

      await tester.pumpAndSettle();

      // Tap Present for first intern (Rahul Sharma)
      final presentButtons = find.text('Present');
      expect(presentButtons, findsWidgets);
      await tester.tap(presentButtons.first);
      await tester.pumpAndSettle();

      // Verify snackbar confirmation
      expect(
        find.textContaining('Marked Rahul Sharma as PRESENT'),
        findsOneWidget,
      );

      // Verify status badge changed to PRESENT
      expect(find.text('PRESENT'), findsWidgets);
    });

    testWidgets('marks Absent and updates status indicator', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockIndustryRepository(companyName: 'TechNova Solutions');
      final service = IndustryService(repository: repo);

      await tester.pumpWidget(
        MaterialApp(home: IndustryAttendanceScreen(service: service)),
      );

      await tester.pumpAndSettle();

      // Tap Absent for first intern
      final absentButtons = find.text('Absent');
      expect(absentButtons, findsWidgets);
      await tester.tap(absentButtons.first);
      await tester.pumpAndSettle();

      // Verify snackbar confirmation
      expect(
        find.textContaining('Marked Rahul Sharma as ABSENT'),
        findsOneWidget,
      );
      expect(find.text('ABSENT'), findsWidgets);
    });

    testWidgets('shows informative empty state when no interns are assigned', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockIndustryRepository(
        internships: const [],
        dashboardData: const IndustryDashboardData(
          industryName: 'Empty Tech',
          totalInterns: 0,
          activeInterns: 0,
          completedInternships: 0,
          pendingAttendance: 0,
          pendingEvaluations: 0,
          completedEvaluations: 0,
        ),
      );
      final service = IndustryService(repository: repo);

      await tester.pumpWidget(
        MaterialApp(home: IndustryAttendanceScreen(service: service)),
      );

      await tester.pumpAndSettle();

      // Date selector remains visible
      expect(find.text('Attendance Management'), findsOneWidget);
      expect(find.text('Attendance Date'), findsOneWidget);

      // Clean empty state
      expect(find.text('No Assigned Interns'), findsOneWidget);
      expect(
        find.textContaining(
          'No eligible interns are currently assigned to your company',
        ),
        findsOneWidget,
      );
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets(
      'displays pending company assignment banner for unassigned supervisors',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = MockIndustryRepository(
          hasVerifiedCompany: false,
          internships: const [],
          dashboardData: IndustryDashboardData.empty('Unassigned Organization'),
        );
        final service = IndustryService(repository: repo);

        await tester.pumpWidget(
          MaterialApp(home: IndustryAttendanceScreen(service: service)),
        );

        await tester.pumpAndSettle();

        expect(find.text('Company Assignment Pending'), findsOneWidget);
        expect(
          find.textContaining(
            'Your account is not yet mapped to a verified company',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('displays error state and retries successfully', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final failingRepo = FailingAttendanceRepo();
      failingRepo.failInternships = true;
      final service = IndustryService(repository: failingRepo);

      await tester.pumpWidget(
        MaterialApp(home: IndustryAttendanceScreen(service: service)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Attendance Management'), findsOneWidget);
      expect(find.text('Attendance Date'), findsOneWidget);
      expect(find.text('Unable to load attendance'), findsOneWidget);
      expect(
        find.textContaining('Failed to fetch assigned interns.'),
        findsOneWidget,
      );
      expect(find.text('Try Again'), findsOneWidget);

      // Recover and tap Try Again
      failingRepo.failInternships = false;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Mark Daily Attendance'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
    });

    testWidgets('shows error snackbar when save fails', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final failingRepo = FailingAttendanceRepo();
      final service = IndustryService(repository: failingRepo);

      await tester.pumpWidget(
        MaterialApp(home: IndustryAttendanceScreen(service: service)),
      );

      await tester.pumpAndSettle();

      // Trigger write failure
      failingRepo.failAttendance = true;
      final presentButtons = find.text('Present');
      await tester.tap(presentButtons.first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Failed to record attendance:'),
        findsOneWidget,
      );
    });
  });
}
