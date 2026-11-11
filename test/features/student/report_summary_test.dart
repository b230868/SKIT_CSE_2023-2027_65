import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../lib/models/notification_models.dart';

ReportSummary _summary(List<int> progress, {int total = 0, int approved = 0}) {
  return ReportSummary(
    totalApplications: total,
    approved: approved,
    pending: 0,
    rejected: 0,
    documentsUploaded: 0,
    latestProgress: progress.isEmpty ? 0 : progress.last,
    progressHistory: [
      for (var i = 0; i < progress.length; i++)
        ProgressPoint(weekNo: i + 1, progress: progress[i]),
    ],
  );
}

void main() {
  group('ReportSummary analytics', () {
    test('empty summary has safe defaults', () {
      final r = ReportSummary.empty();
      expect(r.weeksLogged, 0);
      expect(r.averageWeeklyGain, 0);
      expect(r.approvalRate, 0);
      expect(r.weekOverWeekGain, isNull);
      expect(r.bestWeek, isNull);
      expect(r.estimatedWeeksLeft, isNull);
      expect(r.daysSinceLastUpdate, isNull);
      expect(r.totalNotifications, 0);
    });

    test('weekly gains are measured from the previous entry', () {
      final r = _summary([10, 30, 30, 60]);
      expect(r.weeklyGains, [10, 20, 0, 30]);
      expect(r.stalledWeeks, 1);
      expect(r.bestWeek, 4);
      expect(r.weekOverWeekGain, 30);
    });

    test('average gain and estimated weeks left', () {
      final r = _summary([20, 40]);
      expect(r.averageWeeklyGain, 20);
      expect(r.estimatedWeeksLeft, 3);
    });

    test('a completed internship needs no more weeks', () {
      final r = _summary([50, 100]);
      expect(r.estimatedWeeksLeft, 0);
    });

    test('no estimate when nothing was gained', () {
      final r = _summary([0, 0]);
      expect(r.estimatedWeeksLeft, isNull);
    });

    test('approval rate', () {
      final r = _summary([], total: 4, approved: 3);
      expect(r.approvalRate, 75);
    });

    test('lastWeeks keeps the last N entries and sets a baseline', () {
      final r = _summary([10, 20, 30, 40, 50, 60]).lastWeeks(4);
      expect(r.weeksLogged, 4);
      expect(r.baselineProgress, 20);
      expect(r.weeklyGains, [10, 10, 10, 10]);
      expect(r.averageWeeklyGain, 10);
    });

    test('lastWeeks returns the same summary when the history is short', () {
      final r = _summary([10, 20]);
      expect(identical(r.lastWeeks(4), r), isTrue);
    });

    test('lastUpdate finds the newest entry', () {
      final r = ReportSummary(
        totalApplications: 1,
        approved: 1,
        pending: 0,
        rejected: 0,
        documentsUploaded: 0,
        latestProgress: 50,
        progressHistory: [
          ProgressPoint(weekNo: 1, progress: 20, recordedAt: DateTime(2026, 11, 1)),
          ProgressPoint(weekNo: 2, progress: 50, recordedAt: DateTime(2026, 11, 8)),
        ],
      );
      expect(r.lastUpdate, DateTime(2026, 11, 8));
    });

    test('notification totals add up across types', () {
      const r = ReportSummary(
        totalApplications: 0,
        approved: 0,
        pending: 0,
        rejected: 0,
        documentsUploaded: 0,
        latestProgress: 0,
        unreadNotifications: 1,
        notificationsByType: {'application': 2, 'progress': 1},
      );
      expect(r.totalNotifications, 3);
    });
  });
}
