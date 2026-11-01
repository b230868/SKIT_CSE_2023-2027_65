import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_models.dart';

/// Reads, live-updates and manages the signed-in student's notifications.
///
/// Offline support: the latest list is cached in Hive, and "mark as read"
/// actions made without a connection are queued and synced later.
class NotificationCacheService {
  NotificationCacheService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _boxName = 'notifications_offline_cache';
  static const _listKey = 'list';
  static const _pendingKey = 'pending_read';

  String? get _uid => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Hive cache (best effort: the service still works if Hive is unavailable)
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

  Future<void> _patchCache(void Function(Map<String, dynamic> row) patch) async {
    final rows = await _readCache();
    for (final row in rows) {
      patch(row);
    }
    await _writeCache(rows);
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Cached notifications (empty if nothing has been fetched yet).
  Future<List<AppNotification>> getCached() async =>
      (await _readCache()).map(AppNotification.fromMap).toList();

  /// Fetches the latest notifications; falls back to the cache when offline.
  Future<List<AppNotification>> fetchNotifications({int limit = 100}) async {
    final uid = _uid;
    if (uid == null) return [];

    try {
      await syncPending();
      final data = await _client
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      final rows = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await _writeCache(rows);
      return rows.map(AppNotification.fromMap).toList();
    } catch (_) {
      return getCached();
    }
  }

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
  Stream<List<AppNotification>> watch() async* {
    final uid = _uid;
    if (uid == null) {
      yield const [];
      return;
    }

    yield await getCached();

    try {
      await for (final rows in _client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .order('created_at', ascending: false)) {
        final list = rows.map((e) => Map<String, dynamic>.from(e)).toList();
        await _writeCache(list);
        yield list.map(AppNotification.fromMap).toList();
      }
    } catch (_) {
      // Offline or realtime unavailable: the cached list stays on screen.
    }
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  Future<void> markAsRead(String id) async {
    await _patchCache((row) {
      if (row['id'] == id) row['is_read'] = true;
    });
    try {
      await _client.from('notifications').update({'is_read': true}).eq('id', id);
    } catch (_) {
      await _queueRead(id);
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
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (_) {
      for (final id in unreadIds) {
        await _queueRead(id);
      }
    }
  }

  /// Deletes a notification. Throws if the server request fails, so the UI
  /// can restore the item.
  Future<void> delete(String id) async {
    await _client.from('notifications').delete().eq('id', id);
    final rows = await _readCache();
    rows.removeWhere((row) => row['id'] == id);
    await _writeCache(rows);
  }

  // ---------------------------------------------------------------------------
  // Offline queue
  // ---------------------------------------------------------------------------

  Future<void> _queueRead(String id) async {
    final box = await _box();
    if (box == null) return;
    final pending =
        List<String>.from(box.get(_pendingKey, defaultValue: <String>[]) as List);
    if (!pending.contains(id)) pending.add(id);
    await box.put(_pendingKey, pending);
  }

  /// Sends queued offline "mark as read" actions to Supabase.
  Future<void> syncPending() async {
    final box = await _box();
    if (box == null) return;
    final pending =
        List<String>.from(box.get(_pendingKey, defaultValue: <String>[]) as List);
    if (pending.isEmpty) return;

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .inFilter('id', pending);
      await box.delete(_pendingKey);
    } catch (_) {
      // Still offline: keep the queue for next time.
    }
  }
}
