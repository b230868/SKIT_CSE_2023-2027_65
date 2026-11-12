// Unit tests for the S5 analytics logic (no Supabase or Hive needed).
// Run with:  flutter test test/s5_notification_analytics_test.dart
//
// If your project's lints complain about relative lib imports, replace the two
// imports below with  package:<your_package_name>/models/...  (see pubspec.yaml).
import 'package:flutter_test/flutter_test.dart';

import 'package:prashikshan/models/notification_models.dart';
import 'package:prashikshan/models/report_insights.dart';

ReportSummary _summary(List<int> progress, {String? lastRecordedAt}) {
  return ReportSummary.fromMap({
    'total_applications': 2,
    'approved': 1,
    'pending': 1,
    'rejected': 0,
    'latest_progress': progress.isEmpty ? 0 : progress.last,
    'progress': [
      for (var i = 0; i < progress.length; i++)
        {
          'week_no': i + 1,
          'progress': progress[i],
          'recorded_at': i == progress.length - 1 ? lastRecordedAt : null,
        },
    ],
    'unread_notifications': 3,
    'notifications_by_type': {'progress': 2, 'alert': 1},
  });
}

void main() {
  group('ReportSummary analytics', () {
    test('weekly gains, average pace and estimate', () {
      final s = _summary([25, 50, 75]);
      expect(s.weeklyGains, [25, 25, 25]);
      expect(s.averageWeeklyGain, 25);
      expect(s.estimatedWeeksLeft, 1);
      expect(s.stalledWeeks, 0);
    });

    test('detects a stalled week and the best week', () {
      final s = _summary([20, 50, 50]);
      expect(s.weekOverWeekGain, 0);
      expect(s.stalledWeeks, 1);
      expect(s.bestWeek, 2);
    });

    test('lastWeeks uses the progress before the window as baseline', () {
      final s = _summary([10, 20, 40, 60]).lastWeeks(2);
      expect(s.progressHistory.length, 2);
      expect(s.baselineProgress, 20);
      expect(s.weeklyGains, [20, 20]);
    });

    test('notification statistics are parsed', () {
      final s = _summary([10]);
      expect(s.unreadNotifications, 3);
      expect(s.totalNotifications, 3);
      expect(s.notificationsByType['alert'], 1);
    });

    test('empty history is safe', () {
      final s = ReportSummary.empty();
      expect(s.weeksLogged, 0);
      expect(s.averageWeeklyGain, 0);
      expect(s.estimatedWeeksLeft, isNull);
    });
  });

  group('Progress insights (alerts)', () {
    test('no progress logged', () {
      final titles = ReportSummary.empty().insights.map((i) => i.title);
      expect(titles, contains('No progress logged yet'));
    });

    test('stalled progress raises a warning', () {
      final s = _summary([20, 50, 50]);
      expect(s.insights.map((i) => i.title), contains('Progress stalled'));
      expect(s.hasWarnings, isTrue);
    });

    test('old last update raises a warning', () {
      final old = DateTime.now().subtract(const Duration(days: 10));
      final s = _summary([20, 40], lastRecordedAt: old.toIso8601String());
      expect(s.insights.map((i) => i.title), contains('No recent update'));
    });

    test('100% shows the completion message only', () {
      final s = _summary([50, 100]);
      final titles = s.insights.map((i) => i.title).toList();
      expect(titles, contains('Internship progress complete'));
      expect(titles, isNot(contains('Progress stalled')));
    });
  });
}
