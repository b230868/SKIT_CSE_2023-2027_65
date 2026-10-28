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
    final ownerId = _db.auth.currentUser?.id;
    if (ownerId == null) return const [];
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
    final ownerId = _db.auth.currentUser?.id;
    final pending = ownerId == null
        ? <GeoProgressLog>[]
        : _queue.pending(ownerId: ownerId, internshipId: internshipId);
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
      if (ownerId != null) {
        await CacheService.cacheData(
          ownerId: ownerId,
          key: cacheKey,
          data: logs.map((log) => log.toJson()).toList(),
        );
      }
      return logs;
    } on PostgrestException catch (e) {
      throw GeoProgressException(e.message);
    } on Exception catch (e) {
      if (!isNetworkError(e)) {
        throw GeoProgressException('Could not load progress history: $e');
      }
      final cached = ownerId == null
          ? null
          : CacheService.getCachedData(ownerId: ownerId, key: cacheKey);
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
