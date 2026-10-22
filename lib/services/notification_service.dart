import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_models.dart';
import '../models/student_models.dart';

abstract interface class NotificationDataSource {
  Future<List<AppNotification>> list();
  Stream<List<AppNotification>> watch();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> delete(String id);
  Future<Application?> applicationFor(String applicationId);
}

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
    return rows.map<AppNotification>((r) => AppNotification.fromMap(r)).toList();
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

  /// New: remove a notification (swipe to dismiss).
  @override
  Future<void> delete(String id) async {
    await _db.from('notifications').delete().eq('id', id);
  }

  /// New: load the application a notification points to, with its
  /// internship, so the detail screen can open straight from the tap.
  @override
  Future<Application?> applicationFor(String applicationId) async {
    final row = await _db
        .from('applications')
        .select('*, internships(*)')
        .eq('id', applicationId)
        .eq('student_id', _uid)
        .maybeSingle();
    return row == null ? null : Application.fromMap(row);
  }
}
