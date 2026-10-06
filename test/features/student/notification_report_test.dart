import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/models/notification_models.dart';
import 'package:prashikshan/screens/student/notification_screen.dart';
import 'package:prashikshan/screens/student/reports_screen.dart';
import 'package:prashikshan/services/notification_service.dart';
import 'package:prashikshan/services/report_service.dart';

void main() {
  group('Notification and report models', () {
    test('AppNotification parses values and applies optional defaults', () {
      final notification = AppNotification.fromMap({
        'id': 'notification-1',
        'title': 'Application received',
        'created_at': '2026-10-06T10:00:00.000Z',
      });

      expect(notification.id, 'notification-1');
      expect(notification.title, 'Application received');
      expect(notification.body, isEmpty);
      expect(notification.type, 'general');
      expect(notification.isRead, isFalse);
      expect(notification.createdAt, DateTime.utc(2026, 10, 6, 10));
    });

    test('ReportSummary.empty initializes every metric to zero', () {
      final summary = ReportSummary.empty();

      expect(summary.totalApplications, 0);
      expect(summary.approved, 0);
      expect(summary.pending, 0);
      expect(summary.rejected, 0);
      expect(summary.documentsUploaded, 0);
      expect(summary.latestProgress, 0);
    });
  });

  group('NotificationsScreen', () {
    testWidgets('shows notifications and marks an item read', (tester) async {
      final service = _FakeNotificationService([
        AppNotification(
          id: 'notification-1',
          title: 'Application received',
          body: 'Your application was submitted.',
          type: 'application',
          isRead: false,
          createdAt: DateTime.utc(2026, 10, 6),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(home: NotificationsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Application received'), findsOneWidget);
      expect(find.text('Your application was submitted.'), findsOneWidget);

      await tester.tap(find.text('Application received'));
      await tester.pumpAndSettle();

      expect(service.markedIds, ['notification-1']);
      expect(service.listCalls, 2);
    });

    testWidgets('shows an empty state when no notifications exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsScreen(service: _FakeNotificationService([])),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No notifications yet.'), findsOneWidget);
    });

    testWidgets('marks all notifications read', (tester) async {
      final service = _FakeNotificationService([
        AppNotification(
          id: 'notification-2',
          title: 'Document approved',
          body: 'Your document was approved.',
          type: 'document',
          isRead: false,
          createdAt: DateTime.utc(2026, 10, 6),
        ),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: NotificationsScreen(service: service),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(service.markAllCalls, 1);
      expect(service.notifications.single.isRead, isTrue);
      expect(find.byIcon(Icons.circle), findsNothing);
    });

    testWidgets('shows a recoverable error state when loading fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsScreen(
            service: _FakeNotificationService([], shouldFail: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load notifications. Pull down to retry.'),
        findsOneWidget,
      );
    });

    testWidgets('bell opens notifications and shows its unread count', (
      tester,
    ) async {
      final service = _FakeNotificationService([], unread: 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NotificationBell(service: service)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
    });
  });

  group('ReportsScreen', () {
    testWidgets('renders application, document, and progress metrics', (
      tester,
    ) async {
      const summary = ReportSummary(
        totalApplications: 5,
        approved: 2,
        pending: 2,
        rejected: 1,
        documentsUploaded: 4,
        latestProgress: 65,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportsScreen(service: _FakeReportService(summary: summary)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Application summary'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(2));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Internship progress'), findsOneWidget);
      expect(find.text('Latest progress: 65%'), findsOneWidget);
      expect(find.text('4 document(s) uploaded'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows an error state when the report cannot load', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportsScreen(service: _FakeReportService(shouldFail: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load your report. Pull down to retry.'),
        findsOneWidget,
      );
    });

    testWidgets('explains that PDF export is not available yet', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportsScreen(
            service: _FakeReportService(summary: ReportSummary.empty()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export as PDF'));
      await tester.pump();

      expect(
        find.text('PDF export is coming once this layout is approved.'),
        findsOneWidget,
      );
    });
  });
}

class _FakeNotificationService implements NotificationDataSource {
  _FakeNotificationService(
    this.notifications, {
    this.unread = 0,
    this.shouldFail = false,
  });

  List<AppNotification> notifications;
  final int unread;
  final bool shouldFail;
  final List<String> markedIds = [];
  int listCalls = 0;
  int markAllCalls = 0;

  @override
  Future<List<AppNotification>> list() async {
    listCalls++;
    if (shouldFail) throw StateError('Notification load failed');
    return notifications;
  }

  @override
  Future<int> unreadCount() async => unread;

  @override
  Future<void> markRead(String id) async {
    markedIds.add(id);
    notifications = notifications
        .map(
          (notification) => notification.id == id
              ? AppNotification(
                  id: notification.id,
                  title: notification.title,
                  body: notification.body,
                  type: notification.type,
                  isRead: true,
                  createdAt: notification.createdAt,
                )
              : notification,
        )
        .toList();
  }

  @override
  Future<void> markAllRead() async {
    markAllCalls++;
    notifications = notifications
        .map(
          (notification) => AppNotification(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            type: notification.type,
            isRead: true,
            createdAt: notification.createdAt,
          ),
        )
        .toList();
  }
}

class _FakeReportService implements ReportDataSource {
  _FakeReportService({this.summary, this.shouldFail = false});

  final ReportSummary? summary;
  final bool shouldFail;

  @override
  Future<ReportSummary> studentSummary() async {
    if (shouldFail) throw StateError('Report load failed');
    return summary!;
  }
}
