import 'notification_models.dart';

enum InsightSeverity { info, success, warning }

/// A short, human-readable alert derived from a student's progress analytics.
class ProgressInsight {
  final InsightSeverity severity;
  final String title;
  final String message;

  const ProgressInsight({
    required this.severity,
    required this.title,
    required this.message,
  });
}

/// Turns the analytics already computed by [ReportSummary] into alerts the
/// Reports / Home screens can show next to the notification bell.
extension ReportInsights on ReportSummary {
  List<ProgressInsight> get insights {
    final result = <ProgressInsight>[];

    if (weeksLogged == 0) {
      result.add(const ProgressInsight(
        severity: InsightSeverity.info,
        title: 'No progress logged yet',
        message: 'Add your first progress update to start tracking.',
      ));
    }

    if (latestProgress >= 100) {
      result.add(const ProgressInsight(
        severity: InsightSeverity.success,
        title: 'Internship progress complete',
        message: 'You have reached 100% progress.',
      ));
    } else if (weeksLogged > 0) {
      final days = daysSinceLastUpdate;
      if (days != null && days > 7) {
        result.add(ProgressInsight(
          severity: InsightSeverity.warning,
          title: 'No recent update',
          message: 'Your last progress update was $days days ago.',
        ));
      }

      final change = weekOverWeekGain;
      if (change != null && change <= 0) {
        result.add(const ProgressInsight(
          severity: InsightSeverity.warning,
          title: 'Progress stalled',
          message: 'Your progress did not increase in the latest week.',
        ));
      }

      final weeksLeft = estimatedWeeksLeft;
      if (weeksLeft != null && weeksLeft > 0) {
        result.add(ProgressInsight(
          severity: InsightSeverity.info,
          title: 'Estimated completion',
          message:
              'At your current pace you need about $weeksLeft more week(s) to reach 100%.',
        ));
      }
    }

    final best = bestWeek;
    if (best != null) {
      result.add(ProgressInsight(
        severity: InsightSeverity.success,
        title: 'Best week',
        message: 'Your biggest gain was in week $best.',
      ));
    }

    if (unreadNotifications > 0) {
      result.add(ProgressInsight(
        severity: InsightSeverity.info,
        title: 'Unread notifications',
        message: 'You have $unreadNotifications unread notification(s).',
      ));
    }

    return result;
  }

  /// True when the UI should draw attention (e.g. a dot on the bell).
  bool get hasWarnings =>
      insights.any((i) => i.severity == InsightSeverity.warning);
}
