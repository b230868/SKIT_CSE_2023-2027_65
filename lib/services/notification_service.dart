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
  String? get _currentUserId => _db.auth.currentUser?.id;

  @override
  Future<List<AppNotification>> list() async {
    final userId = _currentUserId;
    if (userId == null) return const [];
    final rows = await _db
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows
        .map<AppNotification>((r) => AppNotification.fromMap(r))
        .toList();
  }

  /// Live list, newest first (bell badge and Notifications screen).
  @override
  Stream<List<AppNotification>> watch() {
    final userId = _currentUserId;
    if (userId == null) return const Stream.empty();
    return _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => AppNotification.fromMap(r)).toList());
  }

  @override
  Future<void> markRead(String id) async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('user_id', userId);
  }

  @override
  Future<void> markAllRead() async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Remove a notification (swipe to dismiss).
  @override
  Future<void> delete(String id) async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _db.from('notifications').delete().eq('id', id).eq('user_id', userId);
  }

  /// Loads only this user's internship linked by the notification.
  @override
  Future<Internship?> internshipFor(String internshipId) async {
    final userId = _currentUserId;
    if (userId == null) return null;
    final row = await _db
        .from('internships')
        .select()
        .eq('id', internshipId)
        .eq('student_id', userId)
        .maybeSingle();
    return row == null ? null : Internship.fromMap(row);
  }
}
