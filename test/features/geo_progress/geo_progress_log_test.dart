import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/geo_progress/models/geo_progress_log.dart';

void main() {
  test('serializes internship progress using the database schema', () {
    final log = GeoProgressLog(
      clientRef: 'client-ref',
      internshipId: 'internship-id',
      progressPercent: 25,
      taskSummary: 'Completed setup',
      latitude: 26.9,
      longitude: 75.8,
      capturedAt: DateTime.utc(2026, 9, 28),
    );

    final json = log.toInsertJson();

    expect(json['internship_id'], 'internship-id');
    expect(json.containsKey('application_id'), isFalse);
    expect(json['captured_at'], '2026-09-28T00:00:00.000Z');
  });

  test('reads internship progress returned by the database', () {
    final log = GeoProgressLog.fromJson({
      'id': 'log-id',
      'client_ref': 'client-ref',
      'internship_id': 'internship-id',
      'progress_percent': 25,
      'task_summary': 'Completed setup',
      'latitude': 26.9,
      'longitude': 75.8,
      'accuracy_m': 12,
      'captured_at': '2026-09-28T00:00:00.000Z',
      'distance_from_site_m': 20,
      'within_geofence': true,
    });

    expect(log.internshipId, 'internship-id');
    expect(log.progressPercent, 25);
    expect(log.accuracyM, 12);
    expect(log.withinGeofence, isTrue);
  });
}
