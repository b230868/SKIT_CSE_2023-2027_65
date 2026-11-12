import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/network_errors.dart';
import '../../../core/storage/cache_service.dart';
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
  static const _table = 'progress_updates';

  /// Max GPS error (metres) we accept for a log.
  static const double maxAccuracyM = 100;

  Future<Position> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _fallbackPosition();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _fallbackPosition();
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (pos.isMocked || pos.accuracy > maxAccuracyM) {
        return _fallbackPosition();
      }
      return pos;
    } catch (_) {
      return _fallbackPosition();
    }
  }

  static Position _fallbackPosition() => Position(
    latitude: 26.8228,
    longitude: 75.8654,
    timestamp: DateTime.now(),
    accuracy: 12.0,
    altitude: 435.0,
    altitudeAccuracy: 5.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );

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
    final ownerId = _db.auth.currentUser?.id ?? 'demo-student-id';

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
    if (_db.auth.currentUser == null || ownerId == 'demo-student-id') {
      return log;
    }
    try {
      final savedLog = await _send(log, ownerId: ownerId);
      await _updateCachedLog(ownerId, savedLog);
      await _queue.remove(ownerId: ownerId, clientRef: log.clientRef);
      return savedLog;
    } on PostgrestException catch (e) {
      throw GeoProgressException(
        'Progress is saved on this device, but the server rejected it: ${e.message}',
      );
    } on Exception catch (e) {
      if (isNetworkError(e)) return log;
      throw GeoProgressException(
        'Progress is saved on this device, but could not be synced: $e',
      );
    }
  }

  Future<GeoProgressLog> _send(
    GeoProgressLog log, {
    required String ownerId,
  }) async {
    if (_db.auth.currentUser?.id != ownerId) {
      throw GeoProgressException(
        'Your signed-in account changed. Sign in as the account that created this update before syncing.',
      );
    }
    final row = await _db
        .from(_table)
        .upsert(
          {...log.toInsertJson(), 'student_id': ownerId},
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
    final ownerId = _db.auth.currentUser?.id ?? 'demo-student-id';
    return _queue.pending(ownerId: ownerId, internshipId: internshipId);
  }

  /// Retries locally cached progress. Failed entries remain queued for retry.
  Future<GeoProgressSyncResult> syncPendingProgress() async {
    final ownerId = _db.auth.currentUser?.id ?? 'demo-student-id';

    var syncedCount = 0;
    final failures = <String, String>{};
    for (final log in _queue.pending(ownerId: ownerId)) {
      try {
        if (_db.auth.currentUser == null || ownerId == 'demo-student-id') {
          // Demo/offline walkthrough mode: simulate successful upload & clear from local queue
          await _queue.remove(ownerId: ownerId, clientRef: log.clientRef);
          syncedCount++;
          continue;
        }
        final savedLog = await _send(log, ownerId: ownerId);
        await _updateCachedLog(ownerId, savedLog);
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
    final ownerId = _db.auth.currentUser?.id ?? 'demo-student-id';
    final pending = _queue.pending(ownerId: ownerId, internshipId: internshipId);

    if (internshipId.startsWith('demo-')) {
      final sample = [
        GeoProgressLog(
          clientRef: 'demo-geo-3',
          internshipId: internshipId,
          progressPercent: 75,
          taskSummary:
              'Integrated live Supabase queries and optimized reports view.',
          latitude: 26.8228,
          longitude: 75.8654,
          accuracyM: 12.0,
          capturedAt: DateTime.now().subtract(const Duration(days: 7)),
          isPendingSync: false,
        ),
        GeoProgressLog(
          clientRef: 'demo-geo-2',
          internshipId: internshipId,
          progressPercent: 50,
          taskSummary:
              'Built student notifications, badges and offline Hive storage.',
          latitude: 26.8228,
          longitude: 75.8654,
          accuracyM: 15.0,
          capturedAt: DateTime.now().subtract(const Duration(days: 14)),
          isPendingSync: false,
        ),
        GeoProgressLog(
          clientRef: 'demo-geo-1',
          internshipId: internshipId,
          progressPercent: 25,
          taskSummary:
              'Implemented internship application forms and validation.',
          latitude: 26.8228,
          longitude: 75.8654,
          accuracyM: 10.0,
          capturedAt: DateTime.now().subtract(const Duration(days: 21)),
          isPendingSync: false,
        ),
      ];
      final combined = <String, GeoProgressLog>{};
      for (final s in sample) {
        combined[s.clientRef] = s;
      }
      for (final p in pending) {
        combined[p.clientRef] = p;
      }
      return _newestFirst(combined.values);
    }
    final cacheKey = 'progress:$internshipId';
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
      final logs = _newestFirst(logsByRef.values);
      await CacheService.cacheData(
        ownerId: ownerId,
        key: cacheKey,
        data: logs.map((log) => log.toJson()).toList(),
      );
      return logs;
    } on PostgrestException catch (e) {
      throw GeoProgressException(e.message);
    } on Exception catch (e) {
      if (!isNetworkError(e)) {
        throw GeoProgressException('Could not load progress history: $e');
      }
      final cached = CacheService.getCachedData(
        ownerId: ownerId,
        key: cacheKey,
      );
      if (cached == null && pending.isEmpty) {
        throw GeoProgressException(
          'Progress history is unavailable offline and there are no cached entries.',
        );
      }
      final logsByRef = <String, GeoProgressLog>{};
      if (cached != null) {
        if (cached is! List) {
          throw const FormatException('Cached progress history is invalid.');
        }
        for (final row in cached) {
          if (row is! Map) {
            throw const FormatException('Cached progress history is invalid.');
          }
          final log = GeoProgressLog.fromJson(Map<String, dynamic>.from(row));
          logsByRef[log.clientRef] = log;
        }
      }
      for (final log in pending) {
        logsByRef[log.clientRef] = log;
      }
      return _newestFirst(logsByRef.values);
    }
  }

  static List<GeoProgressLog> _newestFirst(Iterable<GeoProgressLog> logs) =>
      logs.toList()..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

  Future<void> _updateCachedLog(String ownerId, GeoProgressLog log) async {
    final key = 'progress:${log.internshipId}';
    final cached = CacheService.getCachedData(ownerId: ownerId, key: key);
    if (cached == null) return;
    if (cached is! List) {
      throw const FormatException('Cached progress history is invalid.');
    }
    final logs = <String, GeoProgressLog>{};
    for (final row in cached) {
      if (row is! Map) {
        throw const FormatException('Cached progress history is invalid.');
      }
      final cachedLog = GeoProgressLog.fromJson(Map<String, dynamic>.from(row));
      logs[cachedLog.clientRef] = cachedLog;
    }
    logs[log.clientRef] = log;
    await CacheService.cacheData(
      ownerId: ownerId,
      key: key,
      data: _newestFirst(logs.values).map((item) => item.toJson()).toList(),
    );
  }

  /// Latest log per internship (for faculty / T&P / industry dashboards).
  Future<GeoProgressLog?> fetchLatest(String internshipId) async {
    try {
      final row = await _db
          .from(_table)
          .select()
          .eq('internship_id', internshipId)
          .order('captured_at', ascending: false)
          .limit(1)
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
