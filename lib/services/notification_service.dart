import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_models.dart';

abstract interface class NotificationDataSource {
  Future<List<AppNotification>> list();
  Stream<List<AppNotification>> watch();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}

/// Reads are the same as last week. New this week: a live stream so the
/// bell badge and list update the moment a trigger inserts a row, with no
/// manual refresh needed.
class NotificationService implements NotificationDataSource {
  final SupabaseClient _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  @override
  Future<List<AppNotification>> list() async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return rows
        .map<AppNotification>((r) => AppNotification.fromMap(r))
        .toList();
  }

  /// Live list, newest first. Used by both the Notifications screen and
  /// the bell badge so they never go stale.
  @override
  Stream<List<AppNotification>> watch() {
    return _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => AppNotification.fromMap(r)).toList());
  }

  @override
  Future<void> markRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  @override
  Future<void> markAllRead() async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _uid)
        .eq('is_read', false);
  }
}
