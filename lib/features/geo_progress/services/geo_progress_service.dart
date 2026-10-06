import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/geo_progress_log.dart';

class GeoProgressException implements Exception {
  final String message;
  GeoProgressException(this.message);
  @override
  String toString() => message;
}

/// Integrates device GPS with Supabase so every progress update is geo-tagged.
class GeoProgressService {
  GeoProgressService({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;
  static const _uuid = Uuid();
  static const _table = 'geo_progress_logs';

  /// Max GPS error (metres) we accept for a log.
  static const double maxAccuracyM = 100;

  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw GeoProgressException('Please turn on location services.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw GeoProgressException('Location permission denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw GeoProgressException(
        'Location permission permanently denied. Enable it in app settings.',
      );
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    if (pos.isMocked) {
      throw GeoProgressException('Mock locations are not allowed.');
    }
    if (pos.accuracy > maxAccuracyM) {
      throw GeoProgressException(
        'GPS accuracy too low (${pos.accuracy.toStringAsFixed(0)} m). Move to an open area and retry.',
      );
    }
    return pos;
  }

  /// Captures GPS and submits a geo-tagged progress update.
  /// [clientRef] makes the call idempotent (safe to retry / sync later via Hive).
  Future<GeoProgressLog> submitProgress({
    required String internshipId,
    required int progressPercent,
    required String taskSummary,
    String? clientRef,
  }) async {
    if (progressPercent < 0 || progressPercent > 100) {
      throw GeoProgressException('Progress must be between 0 and 100.');
    }
    if (taskSummary.trim().length < 3) {
      throw GeoProgressException('Please describe the task completed.');
    }
    if (taskSummary.trim().length > 500) {
      throw GeoProgressException(
        'Task descriptions must be 500 characters or less.',
      );
    }

    final pos = await getCurrentPosition();

    final log = GeoProgressLog(
      clientRef: clientRef ?? _uuid.v4(),
      internshipId: internshipId,
      progressPercent: progressPercent,
      taskSummary: taskSummary.trim(),
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracyM: pos.accuracy,
      capturedAt: pos.timestamp,
    );

    try {
      final row = await _db
          .from(_table)
          .upsert(
            log.toInsertJson(),
            onConflict: 'client_ref',
            ignoreDuplicates: true,
          )
          .select()
          .maybeSingle();
      if (row != null) return GeoProgressLog.fromJson(row);

      final existing = await _db
          .from(_table)
          .select()
          .eq('client_ref', log.clientRef)
          .maybeSingle();
      if (existing != null) return GeoProgressLog.fromJson(existing);
      throw GeoProgressException('Progress could not be saved.');
    } on PostgrestException catch (e) {
      throw GeoProgressException(e.message);
    }
  }

  /// Full history for one internship, newest first.
  Future<List<GeoProgressLog>> fetchHistory(String internshipId) async {
    try {
      final rows = await _db
          .from(_table)
          .select()
          .eq('internship_id', internshipId)
          .order('captured_at', ascending: false);
      return rows.map<GeoProgressLog>(GeoProgressLog.fromJson).toList();
    } on PostgrestException catch (e) {
      throw GeoProgressException(e.message);
    }
  }

  /// Latest log per internship (for faculty / T&P / industry dashboards).
  Future<GeoProgressLog?> fetchLatest(String internshipId) async {
    try {
      final row = await _db
          .from('geo_progress_latest')
          .select()
          .eq('internship_id', internshipId)
          .maybeSingle();
      return row == null ? null : GeoProgressLog.fromJson(row);
    } on PostgrestException catch (e) {
      throw GeoProgressException(e.message);
    }
  }

  /// Realtime stream of new logs for an internship.
  Stream<List<GeoProgressLog>> watchProgress(String internshipId) {
    return _db
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('internship_id', internshipId)
        .order('captured_at', ascending: false)
        .map((rows) => rows.map(GeoProgressLog.fromJson).toList());
  }
}
