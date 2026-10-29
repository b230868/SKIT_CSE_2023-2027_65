import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/internship/models/internship.dart';
import '../models/notification_models.dart';

abstract interface class NotificationDataSource {
  Future<List<AppNotification>> list();
  Stream<List<AppNotification>> watch();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> delete(String id);
  Future<Internship?> internshipFor(String internshipId);
}

class NotificationService implements NotificationDataSource {
  NotificationService({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;
  String get _uid {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before accessing notifications.');
    }
    return userId;
  }

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

  /// Live list, newest first (bell badge and Notifications screen).
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
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('user_id', _uid);
  }

  @override
  Future<void> markAllRead() async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _uid)
        .eq('is_read', false);
  }

  /// New: remove a notification (swipe to dismiss).
  @override
  Future<void> delete(String id) async {
    await _db.from('notifications').delete().eq('id', id).eq('user_id', _uid);
  }

  /// Loads only this user's internship linked by the notification.
  @override
  Future<Internship?> internshipFor(String internshipId) async {
    final row = await _db
        .from('internships')
        .select()
        .eq('id', internshipId)
        .eq('student_id', _uid)
        .maybeSingle();
    return row == null ? null : Internship.fromMap(row);
  }
}
