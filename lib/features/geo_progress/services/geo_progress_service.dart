import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' show ClientException;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/geo_progress_log.dart';
import 'geo_progress_queue.dart';

class GeoProgressException implements Exception {
  final String message;
  GeoProgressException(this.message);
  @override
  String toString() => message;
}

class GeoProgressSyncResult {
  const GeoProgressSyncResult({
    required this.syncedCount,
    required this.remainingCount,
    required this.failures,
  });

  final int syncedCount;
  final int remainingCount;
  final Map<String, String> failures;

  bool get isComplete => remainingCount == 0;
}

/// Integrates device GPS with Supabase so every progress update is geo-tagged.
class GeoProgressService {
  GeoProgressService({SupabaseClient? client, GeoProgressQueue? queue})
    : _db = client ?? Supabase.instance.client,
      _queue =
          queue ??
          GeoProgressQueue(box: Hive.box<Map>(GeoProgressQueue.boxName));

  final SupabaseClient _db;
  final GeoProgressQueue _queue;
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
    final ownerId = _db.auth.currentUser?.id;
    if (ownerId == null) {
      throw GeoProgressException('Sign in before submitting progress.');
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
      isPendingSync: true,
    );

    await _queue.enqueue(log, ownerId: ownerId);
    try {
      final savedLog = await _send(log);
      await _queue.remove(ownerId: ownerId, clientRef: log.clientRef);
      return savedLog;
    } on PostgrestException catch (e) {
      throw GeoProgressException(
        'Progress is saved on this device, but the server rejected it: ${e.message}',
      );
    } on Exception catch (e) {
      if (_isNetworkError(e)) return log;
      throw GeoProgressException(
        'Progress is saved on this device, but could not be synced: $e',
      );
    }
  }

  Future<GeoProgressLog> _send(GeoProgressLog log) async {
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
  }

  /// Returns this signed-in user's queued logs, newest first.
  List<GeoProgressLog> getPendingProgress({String? internshipId}) {
    final ownerId = _db.auth.currentUser?.id;
    if (ownerId == null) {
      throw GeoProgressException('Sign in before viewing cached progress.');
    }
    return _queue.pending(ownerId: ownerId, internshipId: internshipId);
  }

  /// Retries locally cached progress. Failed entries remain queued for retry.
  Future<GeoProgressSyncResult> syncPendingProgress() async {
    final ownerId = _db.auth.currentUser?.id;
    if (ownerId == null) {
      throw GeoProgressException('Sign in before syncing cached progress.');
    }

    var syncedCount = 0;
    final failures = <String, String>{};
    for (final log in _queue.pending(ownerId: ownerId)) {
      try {
        await _send(log);
        await _queue.remove(ownerId: ownerId, clientRef: log.clientRef);
        syncedCount++;
      } on Exception catch (e) {
        failures[log.clientRef] = e.toString();
      }
    }
    return GeoProgressSyncResult(
      syncedCount: syncedCount,
      remainingCount: _queue.count(ownerId: ownerId),
      failures: failures,
    );
  }

  /// Full history for one internship, newest first.
  Future<List<GeoProgressLog>> fetchHistory(String internshipId) async {
    final ownerId = _db.auth.currentUser?.id;
    final pending = ownerId == null
        ? <GeoProgressLog>[]
        : _queue.pending(ownerId: ownerId, internshipId: internshipId);
    try {
      final rows = await _db
          .from(_table)
          .select()
          .eq('internship_id', internshipId)
          .order('captured_at', ascending: false);
      final logsByRef = {
        for (final row in rows)
          (row['client_ref'] as String): GeoProgressLog.fromJson(row),
      };
      for (final log in pending) {
        logsByRef.putIfAbsent(log.clientRef, () => log);
      }
      final logs = logsByRef.values.toList()
        ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      return logs;
    } on PostgrestException catch (e) {
      throw GeoProgressException(e.message);
    } on Exception catch (e) {
      if (!_isNetworkError(e)) {
        throw GeoProgressException('Could not load progress history: $e');
      }
      if (pending.isEmpty) {
        throw GeoProgressException(
          'Progress history is unavailable offline and there are no cached entries.',
        );
      }
      return pending;
    }
  }

  bool _isNetworkError(Exception error) =>
      error is ClientException ||
      error is TimeoutException ||
      error is SocketException ||
      error is AuthRetryableFetchException;

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
