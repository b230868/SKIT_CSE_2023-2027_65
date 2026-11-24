import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:prashikshan/features/auth/models/app_user.dart';
import 'package:prashikshan/features/internship/models/internship.dart';
import 'package:prashikshan/features/student/presentation/student_application_detail_screen.dart';
import 'package:prashikshan/features/student/presentation/student_applications_screen.dart';
import 'package:prashikshan/features/student/presentation/student_reports_screen.dart';
import 'package:prashikshan/features/student/student_dashboard_screen.dart';
import 'package:prashikshan/features/student/widgets/student_notification_bell.dart';
import 'package:prashikshan/models/notification_models.dart';
import 'package:prashikshan/models/student_models.dart';
import 'package:prashikshan/services/document_progress_service.dart';
import 'package:prashikshan/services/notification_service.dart';
import 'package:prashikshan/services/student_service.dart';

const _mockUser = AppUser(
  id: 'student-test-01',
  fullName: 'Vidhi Sharma',
  email: 'vidhi@skit.ac.in',
  role: 'student',
  enrollmentNo: 'SKIT/2023/CSE/065',
  branch: 'CSE',
);

final _mockInternship = Internship(
  id: 'intern-001',
  studentId: 'student-test-01',
  companyName: 'Infosys Ltd',
  title: 'Full Stack Engineer Intern',
  mode: 'hybrid',
  startDate: DateTime(2026, 6, 1),
  endDate: DateTime(2026, 8, 31),
  status: 'approved',
  progress: 75,
  createdAt: DateTime(2026, 5, 20),
);

class _FakeStudentDataSource implements StudentDataSource {
  final List<Application> apps;
  _FakeStudentDataSource(this.apps);

  @override
  Future<List<Application>> myApplications() async => apps;
}

class _FakeDocumentProgressDataSource implements DocumentProgressDataSource {
  @override
  Future<List<DocumentItem>> documents(String internshipId) async => [
    DocumentItem('doc-1', 'resume', 'Resume_Vidhi.pdf', DateTime(2026, 5, 22)),
    DocumentItem(
      'doc-2',
      'offer_letter',
      'OfferLetter.pdf',
      DateTime(2026, 5, 25),
    ),
  ];

  @override
  Future<List<ProgressLog>> progress(String internshipId) async => [
    const ProgressLog(
      'prog-1',
      1,
      20,
      'Set up dev environment and completed onboarding.',
    ),
    const ProgressLog(
      'prog-2',
      2,
      45,
      'Built database migrations and user auth.',
    ),
    const ProgressLog(
      'prog-3',
      3,
      75,
      'Implemented dashboard screens and API routes.',
    ),
  ];

  @override
  Future<void> upload(
    String internshipId,
    String docType,
    dynamic file,
  ) async {}

  @override
  Future<void> addProgress(
    String internshipId,
    int week,
    int progress,
    String summary,
  ) async {}
}

class _FakeNotificationDataSource implements NotificationDataSource {
  final List<AppNotification> items;
  _FakeNotificationDataSource(this.items);

  @override
  Future<List<AppNotification>> list() async => items;

  @override
  Stream<List<AppNotification>> watch() => Stream.value(items);

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<Internship?> internshipFor(String internshipId) async =>
      _mockInternship;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  group('Student Dashboard Tests', () {
    testWidgets(
      'renders count cards, progress ring and handles quick actions',
      (tester) async {
        int? navigatedTab;
        String? navigatedFilter;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentDashboardScreen(
                user: _mockUser,
                onApply: () {},
                onNavigate: (tab, {filter}) {
                  navigatedTab = tab;
                  navigatedFilter = filter;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify greetings and quick action titles
        expect(find.text('Hello, Vidhi'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.text('Approved'), findsWidgets);
        expect(find.text('Avg progress'), findsOneWidget);
        expect(find.text('Quick Actions'), findsOneWidget);
        expect(find.text('Browse'), findsOneWidget);
        expect(find.text('Upload Doc'), findsOneWidget);
        expect(find.text('View Report'), findsOneWidget);

        // Tap 'Pending' stat card
        await tester.tap(find.text('Pending'));
        expect(navigatedTab, 1);
        expect(navigatedFilter, 'pending');

        // Tap 'Approved' stat card
        await tester.tap(find.text('Approved'));
        expect(navigatedTab, 1);
        expect(navigatedFilter, 'approved');
      },
    );
  });

  group('Student Applications Screen Tests', () {
    testWidgets(
      'renders filter chips, search bar, sort and application items',
      (tester) async {
        final fakeApps = [
          Application(_mockInternship),
          Application(
            Internship(
              id: 'intern-002',
              studentId: 'student-test-01',
              companyName: 'TCS',
              title: 'Backend Intern',
              mode: 'onsite',
              startDate: DateTime(2026, 7, 1),
              endDate: DateTime(2026, 9, 30),
              status: 'pending',
              progress: 0,
              createdAt: DateTime(2026, 5, 25),
            ),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StudentApplicationsScreen(
                service: _FakeStudentDataSource(fakeApps),
                documentService: _FakeDocumentProgressDataSource(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify filter chips
        expect(find.text('All (2)'), findsOneWidget);
        expect(find.text('Pending (1)'), findsOneWidget);
        expect(find.text('Approved (1)'), findsOneWidget);
        expect(find.text('Rejected (0)'), findsOneWidget);

        // Both cards are visible initially
        expect(find.text('Infosys Ltd'), findsOneWidget);
        expect(find.text('TCS'), findsOneWidget);

        // Tap 'Pending' chip
        await tester.tap(find.text('Pending (1)'));
        await tester.pumpAndSettle();

        // Only TCS should be visible
        expect(find.text('TCS'), findsOneWidget);
        expect(find.text('Infosys Ltd'), findsNothing);

        // Tap 'All' chip
        await tester.tap(find.text('All (2)'));
        await tester.pumpAndSettle();
        expect(find.text('Infosys Ltd'), findsOneWidget);
        expect(find.text('TCS'), findsOneWidget);

        // Test Search bar
        await tester.enterText(find.byType(TextField), 'Full Stack');
        await tester.pumpAndSettle();
        expect(find.text('Infosys Ltd'), findsOneWidget);
        expect(find.text('TCS'), findsNothing);
      },
    );
  });

  group('Student Application Detail Screen Tests', () {
    testWidgets('renders 6-step lifecycle timeline and tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StudentApplicationDetailScreen(
            application: Application(_mockInternship),
            service: _FakeDocumentProgressDataSource(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Stepper steps
      expect(find.text('Applied'), findsOneWidget);
      expect(find.text('Approved'), findsWidgets);
      expect(find.text('Documents'), findsWidgets);
      expect(find.text('Progress'), findsWidgets);
      expect(find.text('ITR'), findsOneWidget);
      expect(find.text('Certificate'), findsOneWidget);

      // Verify Tabs
      expect(find.text('Overview'), findsOneWidget);
      expect(
        find.text('Documents'),
        findsWidgets,
      ); // in timeline, tab bar, and content
      expect(
        find.text('Progress'),
        findsWidgets,
      ); // in timeline, tab bar, and content

      // Switch to Documents tab
      await tester.tap(find.byIcon(Icons.file_present_outlined).first);
      await tester.pumpAndSettle();

      // Switch to Progress tab
      await tester.tap(find.byIcon(Icons.timeline).first);
      await tester.pumpAndSettle();
    });
  });

  group('Student Reports Screen Tests', () {
    testWidgets('renders interactive progress chart and time-window selector', (
      tester,
    ) async {
      final summary = ReportSummary(
        totalApplications: 2,
        approved: 1,
        pending: 1,
        rejected: 0,
        completed: 0,
        documentsUploaded: 3,
        latestProgress: 75,
        documentsByType: const {'resume': 1, 'offer_letter': 2},
        progressHistory: [
          ProgressPoint(
            weekNo: 1,
            progress: 20,
            recordedAt: DateTime(2026, 6, 7),
          ),
          ProgressPoint(
            weekNo: 2,
            progress: 45,
            recordedAt: DateTime(2026, 6, 14),
          ),
          ProgressPoint(
            weekNo: 3,
            progress: 75,
            recordedAt: DateTime(2026, 6, 21),
          ),
        ],
        studentName: 'Vidhi Sharma',
        unreadNotifications: 1,
        notificationsByType: const {'application': 1},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentReportsScreen(
            loader: ({bool force = false}) async => summary,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Performance Overview'), findsOneWidget);
      expect(find.text('Progress Analytics'), findsOneWidget);
      expect(find.text('All Weeks'), findsOneWidget);
      expect(find.text('Last 8 Wks'), findsOneWidget);
      expect(find.text('Last 4 Wks'), findsOneWidget);
      expect(find.text('Weekly Progress Trend'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Copy Report Summary'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Export as PDF Report'), findsOneWidget);
      expect(find.text('Copy Report Summary'), findsOneWidget);
    });
  });

  group('Student Notification Bell Tests', () {
    testWidgets('renders unread badge and opens quick preview modal', (
      tester,
    ) async {
      final notifs = [
        AppNotification(
          id: 'n-1',
          title: 'ITR Approved',
          body: 'Your weekly ITR was approved by mentor.',
          type: 'application',
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        AppNotification(
          id: 'n-2',
          title: 'Document Uploaded',
          body: 'Your offer letter was received.',
          type: 'document',
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                StudentNotificationBell(
                  service: _FakeNotificationDataSource(notifs),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify unread badge shows '1'
      expect(find.text('1'), findsOneWidget);

      // Tap bell to open quick preview
      await tester.tap(find.byType(StudentNotificationBell));
      await tester.pumpAndSettle();

      // Verify preview content
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('ITR Approved'), findsOneWidget);
      expect(
        find.text('Your weekly ITR was approved by mentor.'),
        findsOneWidget,
      );
      expect(find.text('See all notifications'), findsOneWidget);
    });
  });
}
