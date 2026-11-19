// Contract test: checks that the JSON produced by the Supabase functions
// (get_student_analytics, get_notification_summary, notifications rows) is read
// correctly by the Flutter models. No Supabase connection is needed.
//
// Run with:  flutter test test/features/student/s5_data_contract_test.dart
//
// If your lints complain about relative lib imports, replace the imports with
// package:<your_package_name>/...  (same style as report_insights_test.dart).
import 'package:flutter_test/flutter_test.dart';

import 'package:prashikshan/services/analytics_service.dart';
import 'package:prashikshan/models/notification_models.dart';
import 'package:prashikshan/models/report_insights.dart';

// Shaped exactly like the output of public.get_student_analytics().
final Map<String, dynamic> analyticsPayload = {
  'total_applications': 3,
  'approved': 2,
  'pending': 1,
  'rejected': 0,
  'completed': 0,
  'documents_uploaded': 3,
  'documents_by_type': {'pdf': 2, 'image': 1},
  'latest_progress': 75,
  'progress': [
    {'week_no': 1, 'progress': 25, 'recorded_at': '2020-01-01T10:00:00+00:00'},
    {'week_no': 2, 'progress': 50, 'recorded_at': '2020-01-08T10:00:00+00:00'},
    {'week_no': 3, 'progress': 75, 'recorded_at': '2020-01-15T10:00:00+00:00'},
  ],
  'student_name': 'Test Student',
  'unread_notifications': 2,
  'notifications_by_type': {'progress': 3, 'alert': 1, 'application': 1},
};

// Shaped exactly like the output of public.get_notification_summary().
final Map<String, dynamic> summaryPayload = {
  'total': 5,
  'unread': 2,
  'by_type': {'progress': 3, 'alert': 1, 'application': 1},
  'unread_by_type': {'alert': 1, 'progress': 1},
};

// A row of public.notifications as returned by select / realtime.
final Map<String, dynamic> alertRow = {
  'id': 'a1b2c3d4-0000-0000-0000-000000000001',
  'user_id': 'u1b2c3d4-0000-0000-0000-000000000001',
  'title': 'Milestone reached',
  'body': 'Your internship progress has passed 50%.',
  'type': 'alert',
  'internship_id': 'i1b2c3d4-0000-0000-0000-000000000001',
  'is_read': false,
  'created_at': '2026-11-18T09:30:00+00:00',
};

void main() {
  group('get_student_analytics -> ReportSummary', () {
    test('all fields are read', () {
      final s = ReportSummary.fromMap(analyticsPayload);
      expect(s.studentName, 'Test Student');
      expect(s.totalApplications, 3);
      expect(s.approved, 2);
      expect(s.pending, 1);
      expect(s.documentsUploaded, 3);
      expect(s.documentsByType['pdf'], 2);
      expect(s.latestProgress, 75);
      expect(s.progressHistory.map((p) => p.weekNo), [1, 2, 3]);
      expect(s.unreadNotifications, 2);
      expect(s.totalNotifications, 5);
      expect(s.notificationsByType['alert'], 1);
    });

    test('analytics are derived correctly from the payload', () {
      final s = ReportSummary.fromMap(analyticsPayload);
      expect(s.weeklyGains, [25, 25, 25]);
      expect(s.averageWeeklyGain, 25);
      expect(s.estimatedWeeksLeft, 1);
      expect(s.bestWeek, 1);
    });

    test('an older payload without the new fields still works', () {
      final old = Map<String, dynamic>.from(analyticsPayload)
        ..remove('student_name')
        ..remove('unread_notifications')
        ..remove('notifications_by_type');
      final s = ReportSummary.fromMap(old);
      expect(s.studentName, isNull);
      expect(s.unreadNotifications, 0);
      expect(s.notificationsByType, isEmpty);
      expect(s.latestProgress, 75);
    });

    test('insights are produced from the payload', () {
      final s = ReportSummary.fromMap(analyticsPayload);
      // recorded_at is far in the past, so the no-update warning must appear
      expect(s.insights.map((i) => i.title), contains('No recent update'));
      expect(s.hasWarnings, isTrue);
    });
  });

  group('get_notification_summary -> NotificationSummary', () {
    test('all fields are read', () {
      final n = NotificationSummary.fromMap(summaryPayload);
      expect(n.total, 5);
      expect(n.unread, 2);
      expect(n.byType['progress'], 3);
      expect(n.unreadByType['alert'], 1);
    });

    test('missing fields fall back to zero / empty', () {
      final n = NotificationSummary.fromMap({});
      expect(n.total, 0);
      expect(n.unread, 0);
      expect(n.byType, isEmpty);
    });
  });

  group('notifications row -> AppNotification', () {
    test('alert row is read, including the internship link', () {
      final n = AppNotification.fromMap(alertRow);
      expect(n.type, 'alert');
      expect(n.title, 'Milestone reached');
      expect(n.isRead, isFalse);
      expect(n.internshipId, 'i1b2c3d4-0000-0000-0000-000000000001');
      expect(n.createdAt.year, 2026);
    });

    test('row without body or internship does not crash', () {
      final row = Map<String, dynamic>.from(alertRow)
        ..['body'] = null
        ..['internship_id'] = null;
      final n = AppNotification.fromMap(row);
      expect(n.body, '');
      expect(n.internshipId, isNull);
    });
  });

  test('AnalyticsResult is "live" by default and "cached" when flagged', () {
    final s = ReportSummary.empty();
    expect(AnalyticsResult(s).fromCache, isFalse);
    expect(AnalyticsResult(s, fromCache: true).fromCache, isTrue);
  });
}
