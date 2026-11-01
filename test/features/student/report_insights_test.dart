import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/internship/models/internship.dart';
import 'package:prashikshan/models/geo_checkin_model.dart';
import 'package:prashikshan/models/notification_models.dart';
import 'package:prashikshan/models/report_insights.dart';

void main() {
  group('ReportInsights', () {
    test('produces info insight when no weeks logged', () {
      final summary = ReportSummary.fromMap({
        'total_applications': 1,
        'approved': 1,
        'pending': 0,
        'rejected': 0,
        'completed': 0,
        'documents_uploaded': 0,
        'latest_progress': 0,
        'progress': <Map<String, dynamic>>[],
        'unread_notifications': 0,
      });

      final insights = summary.insights;
      expect(insights.any((i) => i.title == 'No progress logged yet'), isTrue);
      expect(summary.hasWarnings, isFalse);
    });

    test('produces success insight when progress is 100%', () {
      final summary = ReportSummary.fromMap({
        'total_applications': 1,
        'approved': 0,
        'pending': 0,
        'rejected': 0,
        'completed': 1,
        'documents_uploaded': 1,
        'latest_progress': 100,
        'progress': [
          {'week_no': 1, 'progress': 50, 'recorded_at': '2026-10-01T10:00:00Z'},
          {'week_no': 2, 'progress': 100, 'recorded_at': '2026-10-08T10:00:00Z'},
        ],
        'unread_notifications': 0,
      });

      final insights = summary.insights;
      expect(insights.any((i) => i.title == 'Internship progress complete'), isTrue);
    });

    test('detects stalled progress as warning insight', () {
      final summary = ReportSummary.fromMap({
        'total_applications': 1,
        'approved': 1,
        'pending': 0,
        'rejected': 0,
        'completed': 0,
        'documents_uploaded': 0,
        'latest_progress': 50,
        'progress': [
          {'week_no': 1, 'progress': 50, 'recorded_at': '2026-10-25T10:00:00Z'},
          {'week_no': 2, 'progress': 50, 'recorded_at': '2026-11-01T10:00:00Z'},
        ],
        'unread_notifications': 2,
      });

      final insights = summary.insights;
      expect(summary.hasWarnings, isTrue);
      expect(insights.any((i) => i.title == 'Progress stalled'), isTrue);
      expect(insights.any((i) => i.title == 'Unread notifications'), isTrue);
    });
  });

  group('Internship model', () {
    test('isEditable is case-insensitive for pending status', () {
      final i1 = Internship(
        id: '1',
        studentId: 's1',
        companyName: 'Acme',
        title: 'Intern',
        mode: 'onsite',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 1),
        status: 'pending',
        progress: 0,
        createdAt: DateTime.now(),
      );
      final i2 = Internship(
        id: '2',
        studentId: 's1',
        companyName: 'Acme',
        title: 'Intern',
        mode: 'onsite',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 1),
        status: 'Pending',
        progress: 0,
        createdAt: DateTime.now(),
      );
      final i3 = Internship(
        id: '3',
        studentId: 's1',
        companyName: 'Acme',
        title: 'Intern',
        mode: 'onsite',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 1),
        status: 'approved',
        progress: 50,
        createdAt: DateTime.now(),
      );

      expect(i1.isEditable, isTrue);
      expect(i2.isEditable, isTrue);
      expect(i3.isEditable, isFalse);
    });
  });

  group('GeoCheckIn model', () {
    test('serializes and deserializes GPS coordinates correctly', () {
      final checkIn = GeoCheckIn(
        id: 'chk-1',
        studentId: 'stud-1',
        internshipId: 'intern-1',
        latitude: 26.8214,
        longitude: 75.8648,
        locationAccuracy: 12.5,
        checkInTime: DateTime.parse('2026-11-01T12:00:00Z'),
      );

      final map = checkIn.toMap();
      expect(map['latitude'], 26.8214);
      expect(map['longitude'], 75.8648);
      expect(map['location_accuracy'], 12.5);

      final restored = GeoCheckIn.fromMap(map);
      expect(restored.id, 'chk-1');
      expect(restored.latitude, 26.8214);
      expect(restored.longitude, 75.8648);
      expect(restored.locationAccuracy, 12.5);
    });
  });
}
