import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/geo_progress/models/geo_progress_log.dart';

void main() {
  test('serializes progress for the existing progress_updates table', () {
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
    expect(json['percent'], 25);
    expect(json['note'], 'Completed setup');
    expect(json.containsKey('progress_percent'), isFalse);
    expect(json.containsKey('student_id'), isFalse);
    expect(json['captured_at'], '2026-09-28T00:00:00.000Z');
    expect(json.containsKey('owner_id'), isFalse);
    expect(json.containsKey('is_pending_sync'), isFalse);
  });

  test('reads geo progress returned by the database', () {
    final log = GeoProgressLog.fromJson({
      'id': 'log-id',
      'client_ref': 'client-ref',
      'internship_id': 'internship-id',
      'percent': 25,
      'note': 'Completed setup',
      'latitude': 26.9,
      'longitude': 75.8,
      'accuracy_m': 12,
      'created_at': '2026-09-28T00:00:00.000Z',
    });

    expect(log.internshipId, 'internship-id');
    expect(log.progressPercent, 25);
    expect(log.accuracyM, 12);
    expect(log.latitude, 26.9);
    expect(log.isPendingSync, isFalse);
  });

  test('reads legacy progress rows without GPS fields', () {
    final log = GeoProgressLog.fromJson({
      'id': 'log-id',
      'client_ref': 'client-ref',
      'internship_id': 'internship-id',
      'percent': 40,
      'note': 'Completed a milestone',
      'created_at': '2026-10-10T00:00:00.000Z',
    });

    expect(log.progressPercent, 40);
    expect(log.taskSummary, 'Completed a milestone');
    expect(log.capturedAt, DateTime.utc(2026, 10, 10));
    expect(log.latitude, isNull);
    expect(log.longitude, isNull);
  });
}
