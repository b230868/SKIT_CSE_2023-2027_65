import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_models.dart';
import 'sync_merge.dart';

/// Reads, live-updates and manages the signed-in student's notifications.
///
/// Offline support (refined in S5):
///  * the list is cached in Hive and shown instantly;
///  * "mark as read" and "delete" made offline are queued, retried with back-off
///    and dropped after [maxSyncAttempts] failures;
///  * sync downloads only what changed since the last sync, with a full refresh
///    at least once a day;
///  * the server wins on conflicts, except that a notification you read offline
///    stays read until the server has been told.
class NotificationCacheService {
  NotificationCacheService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _boxName = 'notifications_offline_cache';
  static const _listKey = 'list';
  static const _readQueueKey = 'pending_read';
  static const _deleteQueueKey = 'pending_delete';
  static const _lastSyncKey = 'last_sync';
  static const _lastFullKey = 'last_full_sync';
  static const _incrementalLimit = 500;

  String? get _uid => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Hive helpers (best effort: the service still works if Hive is unavailable)
  // ---------------------------------------------------------------------------

  Future<Box?> _box() async {
    try {
      return Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _readCache() async {
    final box = await _box();
    final raw = box?.get(_listKey) as String?;
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCache(List<Map<String, dynamic>> rows) async {
    final box = await _box();
    await box?.put(_listKey, jsonEncode(rows));
  }

  Future<List<PendingRead>> _readQueue(String key) async {
    final box = await _box();
    final raw = (box?.get(key) as List?) ?? const [];
    final out = <PendingRead>[];
    for (final e in raw) {
      try {
        out.add(PendingRead.fromDynamic(e));
      } catch (_) {
        // ignore a damaged entry
      }
    }
    return out;
  }

  Future<void> _writeQueue(String key, List<PendingRead> queue) async {
    final box = await _box();
    await box?.put(key, queue.map((e) => e.toMap()).toList());
  }

  Future<DateTime?> _readDate(String key) async {
    final box = await _box();
    final raw = box?.get(key) as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> _writeDate(String key, DateTime value) async {
    final box = await _box();
    await box?.put(key, value.toUtc().toIso8601String());
  }

  Future<void> _patchCache(
      void Function(Map<String, dynamic> row) patch) async {
    final rows = await _readCache();
    for (final row in rows) {
      patch(row);
    }
    await _writeCache(rows);
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Cached notifications (empty if nothing has been fetched yet).
  Future<List<AppNotification>> getCached() async =>
      (await _readCache()).map(AppNotification.fromMap).toList();

  /// Number of offline actions still waiting to be sent.
  Future<int> pendingCount() async =>
      (await _readQueue(_readQueueKey)).length +
      (await _readQueue(_deleteQueueKey)).length;

  Future<DateTime?> lastSyncedAt() => _readDate(_lastSyncKey);

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Sends queued offline actions, then downloads what changed on the server.
  /// Never throws: the outcome is returned in a [SyncResult].
  Future<SyncResult> sync({bool full = false, int limit = 200}) async {
    final uid = _uid;
    if (uid == null) return const SyncResult.skipped();

    final started = DateTime.now().toUtc();
    try {
      final reads = await _pushQueue(_readQueueKey, _sendReads);
      final deletes = await _pushQueue(_deleteQueueKey, _sendDeletes);

      final lastSync = await _readDate(_lastSyncKey);
      final lastFull = await _readDate(_lastFullKey);
      var doFull = full || lastSync == null || needsFullRefresh(lastFull, started);

      List<Map<String, dynamic>> incoming = const [];
      if (!doFull) {
        try {
          final res = await _client.rpc('get_notifications_since', params: {
            'p_since': lastSync.toIso8601String(),
            'p_limit': _incrementalLimit,
          });
          incoming = (res as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          // Too many changes (or an old server without the API): do a full refresh.
          if (incoming.length >= _incrementalLimit) doFull = true;
        } catch (_) {
          doFull = true;
        }
      }

      if (doFull) {
        final data = await _client
            .from('notifications')
            .select()
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(limit);
        incoming = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      final pendingReads =
          (await _readQueue(_readQueueKey)).map((p) => p.id).toSet();
      final pendingDeletes =
          (await _readQueue(_deleteQueueKey)).map((p) => p.id).toSet();

      final merged = mergeNotificationRows(
        cached: doFull ? const [] : await _readCache(),
        incoming: incoming,
        pendingReadIds: pendingReads,
      ).where((r) => !pendingDeletes.contains(r['id'])).toList();

      await _writeCache(merged);
      // 30 s of overlap so a row changed during this sync is never missed.
      await _writeDate(_lastSyncKey, started.subtract(const Duration(seconds: 30)));
      if (doFull) await _writeDate(_lastFullKey, started);

      return SyncResult(
        pushed: reads.pushed + deletes.pushed,
        pulled: incoming.length,
        dropped: reads.dropped + deletes.dropped,
      );
    } catch (e) {
      return SyncResult(ok: false, error: e.toString());
    }
  }

  /// Full refresh (used by pull-to-refresh). Falls back to the cache when offline.
  Future<List<AppNotification>> fetchNotifications({int limit = 100}) async {
    await sync(full: true, limit: limit);
    return getCached();
  }

  Future<({int pushed, int dropped})> _pushQueue(
    String key,
    Future<void> Function(List<String> ids) send,
  ) async {
    final queue = await _readQueue(key);
    if (queue.isEmpty) return (pushed: 0, dropped: 0);

    final now = DateTime.now();
    final expired = queue.where((p) => p.isExpired).toList();
    final live = queue.where((p) => !p.isExpired).toList();
    final due = live.where((p) => p.isDue(now)).toList();
    final waiting = live.where((p) => !p.isDue(now)).toList();

    if (due.isEmpty) {
      if (expired.isNotEmpty) await _writeQueue(key, waiting);
      return (pushed: 0, dropped: expired.length);
    }

    try {
      await send(due.map((p) => p.id).toList());
      await _writeQueue(key, waiting);
      return (pushed: due.length, dropped: expired.length);
    } catch (_) {
      await _writeQueue(key, [...waiting, ...due.map((p) => p.retried(now))]);
      return (pushed: 0, dropped: expired.length);
    }
  }

  Future<void> _sendReads(List<String> ids) async {
    try {
      // One call for the whole queue (see the 20261109 migration).
      await _client.rpc('mark_notifications_read', params: {'p_ids': ids});
    } catch (_) {
      // Migration not applied yet: fall back to a plain update.
      await _client
          .from('notifications')
          .update({'is_read': true}).inFilter('id', ids);
    }
  }

  Future<void> _sendDeletes(List<String> ids) async {
    await _client.from('notifications').delete().inFilter('id', ids);
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Number of unread notifications (used for the bell badge).
  Future<int> unreadCount() async {
    final uid = _uid;
    if (uid == null) return 0;

    try {
      final res = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', uid)
          .eq('is_read', false);
      return (res as List).length;
    } catch (_) {
      return (await _readCache()).where((m) => m['is_read'] != true).length;
    }
  }

  /// Live list: emits the cached list first, then every realtime change.
  /// Offline reads and deletes that are still queued are applied to every emission,
  /// so the screen never flips back to an older state.
  Stream<List<AppNotification>> watch() async* {
    final uid = _uid;
    if (uid == null) {
      yield const [];
      return;
    }

    yield await getCached();
    unawaited(sync()); // refresh in the background

    try {
      await for (final rows in _client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .order('created_at', ascending: false)) {
        final pendingReads =
            (await _readQueue(_readQueueKey)).map((p) => p.id).toSet();
        final pendingDeletes =
            (await _readQueue(_deleteQueueKey)).map((p) => p.id).toSet();

        final merged = mergeNotificationRows(
          cached: const [],
          incoming: rows.map((e) => Map<String, dynamic>.from(e)).toList(),
          pendingReadIds: pendingReads,
        ).where((r) => !pendingDeletes.contains(r['id'])).toList();

        await _writeCache(merged);
        yield merged.map(AppNotification.fromMap).toList();
      }
    } catch (_) {
      // Offline or realtime unavailable: the cached list stays on screen.
    }
  }

  // ---------------------------------------------------------------------------
  // Writes (all of them work offline)
  // ---------------------------------------------------------------------------

  Future<void> markAsRead(String id) async {
    await _patchCache((row) {
      if (row['id'] == id) row['is_read'] = true;
    });
    try {
      await _sendReads([id]);
    } catch (_) {
      await _queueAction(_readQueueKey, [id]);
    }
  }

  Future<void> markAllAsRead() async {
    final uid = _uid;
    if (uid == null) return;

    final unreadIds = (await _readCache())
        .where((m) => m['is_read'] != true)
        .map((m) => m['id'] as String)
        .toList();
    await _patchCache((row) => row['is_read'] = true);

    try {
      await _client.rpc('mark_all_notifications_read');
    } catch (_) {
      try {
        await _client
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', uid)
            .eq('is_read', false);
      } catch (_) {
        await _queueAction(_readQueueKey, unreadIds);
      }
    }
  }

  /// Deletes a notification. If the server cannot be reached the delete is queued
  /// and sent later; the item disappears from the list immediately.
  Future<void> delete(String id) async {
    final rows = await _readCache();
    rows.removeWhere((row) => row['id'] == id);
    await _writeCache(rows);

    try {
      await _sendDeletes([id]);
    } catch (_) {
      await _queueAction(_deleteQueueKey, [id]);
    }
  }

  Future<void> _queueAction(String key, List<String> ids) async {
    var queue = await _readQueue(key);
    final now = DateTime.now();
    for (final id in ids) {
      queue = enqueue(queue, id, now);
    }
    await _writeQueue(key, queue);
  }

  /// Kept for older callers: sends the queued actions now.
  Future<void> syncPending() async {
    await _pushQueue(_readQueueKey, _sendReads);
    await _pushQueue(_deleteQueueKey, _sendDeletes);
  }

  /// Call on sign-out so the next user never sees this user's cached data.
  Future<void> clear() async {
    final box = await _box();
    for (final key in [
      _listKey,
      _readQueueKey,
      _deleteQueueKey,
      _lastSyncKey,
      _lastFullKey,
    ]) {
      await box?.delete(key);
    }
  }
}
