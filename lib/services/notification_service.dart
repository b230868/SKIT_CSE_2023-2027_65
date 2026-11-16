import 'dart:async';

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

  static final StreamController<void> _updateController =
      StreamController<void>.broadcast();

  static void emitUpdate() {
    if (!_updateController.isClosed) {
      _updateController.add(null);
    }
  }

  @override
  Future<List<AppNotification>> list() async {
    final userId = _currentUserId;
    List<AppNotification> items = [];
    if (userId != null && userId != 'demo-student-id') {
      try {
        final rows = await _db
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        items = rows
            .map<AppNotification>((r) => AppNotification.fromMap(r))
            .toList();
      } catch (_) {}
    }

    final combined = [...NotificationCacheService.localNotifications, ...items];
    final list = combined.isEmpty
        ? NotificationCacheService.sampleNotifications
        : combined;

    return list.map((n) {
      if (NotificationCacheService.isReadLocally(n.id)) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
  }

  /// Live list, newest first (bell badge and Notifications screen).
  @override
  Stream<List<AppNotification>> watch() {
    late final StreamController<List<AppNotification>> controller;
    StreamSubscription? dbSub;
    StreamSubscription? updateSub;

    void pushCurrent() async {
      try {
        final current = await list();
        if (!controller.isClosed) {
          controller.add(current);
        }
      } catch (_) {}
    }

    controller = StreamController<List<AppNotification>>(
      onListen: () {
        pushCurrent();

        updateSub = _updateController.stream.listen((_) {
          pushCurrent();
        });

        final userId = _currentUserId;
        if (userId != null && userId != 'demo-student-id') {
          try {
            dbSub = _db
                .from('notifications')
                .stream(primaryKey: ['id'])
                .eq('user_id', userId)
                .order('created_at', ascending: false)
                .listen((_) {
              pushCurrent();
            }, onError: (_) {});
          } catch (_) {}
        }
      },
      onCancel: () {
        dbSub?.cancel();
        updateSub?.cancel();
      },
    );

    return controller.stream;
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
    emitUpdate();

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

    emitUpdate();
  }

  @override
  Future<void> markRead(String id) async {
    NotificationCacheService.markIdAsReadLocally(id);
    emitUpdate();

    try {
      await NotificationCacheService().markAsRead(id);
    } catch (_) {}

    try {
      await _db
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
    } catch (_) {}

    emitUpdate();
  }

  @override
  Future<void> markAllRead() async {
    NotificationCacheService.markAllAsReadLocally();
    emitUpdate();

    try {
      await NotificationCacheService().markAllAsRead();
    } catch (_) {}

    final userId = _currentUserId;
    if (userId != null) {
      try {
        await _db
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('is_read', false);
      } catch (_) {}
    } else {
      try {
        await _db
            .from('notifications')
            .update({'is_read': true})
            .eq('is_read', false);
      } catch (_) {}
    }

    emitUpdate();
  }

  /// Remove a notification (swipe to dismiss).
  @override
  Future<void> delete(String id) async {
    try {
      await NotificationCacheService().delete(id);
    } catch (_) {}

    try {
      await _db
          .from('notifications')
          .delete()
          .eq('id', id);
    } catch (_) {}

    emitUpdate();
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
    try {
      final row = await _db
          .from('internships')
          .select()
          .eq('id', internshipId)
          .maybeSingle();
      if (row != null) {
        return Internship.fromMap(row);
      }
    } catch (_) {}

    final sample = InternshipService.sampleInternships
        .where((i) => i.id == internshipId);
    if (sample.isNotEmpty) return sample.first;
    return null;
  }
}
