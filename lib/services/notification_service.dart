import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/internship/data/internship_service.dart';
import '../features/internship/models/internship.dart';
import '../models/notification_models.dart';
import 'notification_cache_service.dart';

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
    if (userId == null || userId == 'demo-student-id') {
      return NotificationCacheService.sampleNotifications;
    }
    try {
      final rows = await _db
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final list = rows
          .map<AppNotification>((r) => AppNotification.fromMap(r))
          .toList();
      final combined = [...NotificationCacheService.localNotifications, ...list];
      return combined.isEmpty
          ? NotificationCacheService.sampleNotifications
          : combined;
    } catch (_) {
      return NotificationCacheService.sampleNotifications;
    }
  }

  /// Live list, newest first (bell badge and Notifications screen).
  @override
  Stream<List<AppNotification>> watch() {
    final userId = _currentUserId;
    if (userId == null || userId == 'demo-student-id') {
      return Stream.value(NotificationCacheService.sampleNotifications);
    }
    return _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) {
          final list =
              rows.map((r) => AppNotification.fromMap(r)).toList();
          final combined = [...NotificationCacheService.localNotifications, ...list];
          return combined.isEmpty
              ? NotificationCacheService.sampleNotifications
              : combined;
        });
  }

  /// Dispatches a notification to a student across cloud database and local cache
  static Future<void> notifyStudent({
    required String studentId,
    required String title,
    required String body,
    String type = 'document',
    String? internshipId,
  }) async {
    final notif = AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      isRead: false,
      createdAt: DateTime.now(),
      applicationId: internshipId,
    );
    NotificationCacheService.addLocalNotification(notif);

    try {
      final client = Supabase.instance.client;
      final payload = <String, dynamic>{
        'user_id': studentId,
        'title': title,
        'body': body,
        'type': type,
        'is_read': false,
      };
      if (internshipId != null) {
        payload['internship_id'] = internshipId;
      }
      await client.from('notifications').insert(payload);
    } catch (_) {
      // Best-effort in offline/mock environment
    }
  }

  @override
  Future<void> markRead(String id) async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      await _db
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', userId);
    } catch (_) {}
  }

  @override
  Future<void> markAllRead() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      await _db
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (_) {}
  }

  /// Remove a notification (swipe to dismiss).
  @override
  Future<void> delete(String id) async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      await _db
          .from('notifications')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } catch (_) {}
  }

  /// Loads only this user's internship linked by the notification.
  @override
  Future<Internship?> internshipFor(String internshipId) async {
    if (internshipId.startsWith('demo-')) {
      final sample = InternshipService.sampleInternships
          .where((i) => i.id == internshipId);
      if (sample.isNotEmpty) return sample.first;
      return InternshipService.sampleInternships.first;
    }
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
