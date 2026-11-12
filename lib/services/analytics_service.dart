import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_models.dart';

/// Report data plus a flag telling the UI whether it came from the offline cache.
class AnalyticsResult {
  final ReportSummary summary;
  final bool fromCache;
  const AnalyticsResult(this.summary, {this.fromCache = false});
}

/// Result of the `get_notification_summary` API.
class NotificationSummary {
  final int total;
  final int unread;
  final Map<String, int> byType;
  final Map<String, int> unreadByType;

  const NotificationSummary({
    required this.total,
    required this.unread,
    this.byType = const {},
    this.unreadByType = const {},
  });

  factory NotificationSummary.fromMap(Map<String, dynamic> j) {
    int toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
    Map<String, int> toMap(dynamic v) {
      final out = <String, int>{};
      if (v is Map) v.forEach((k, val) => out[k.toString()] = toInt(val));
      return out;
    }

    return NotificationSummary(
      total: toInt(j['total']),
      unread: toInt(j['unread']),
      byType: toMap(j['by_type']),
      unreadByType: toMap(j['unread_by_type']),
    );
  }
}

/// Loads student analytics and the notification summary from Supabase and
/// keeps an offline copy in Hive. The screens call this instead of talking to
/// Supabase and Hive directly.
class AnalyticsService {
  AnalyticsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _boxName = 'progress_analytics_cache';
  static const _reportKey = 'student_analytics';
  static const _summaryKey = 'notification_summary';

  Future<Box?> _box() async {
    try {
      return Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _readCache(String key) async {
    final box = await _box();
    final raw = box?.get(key) as String?;
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String key, Map<String, dynamic> data) async {
    final box = await _box();
    await box?.put(key, jsonEncode(data));
  }

  /// Student report (applications, documents, progress history, notification
  /// statistics). Falls back to the cached copy when offline; returns null if
  /// there is neither a connection nor a cached copy.
  Future<AnalyticsResult?> loadReport() async {
    try {
      final res = await _client.rpc('get_student_analytics');
      final map = Map<String, dynamic>.from(res as Map);
      await _writeCache(_reportKey, map);
      return AnalyticsResult(ReportSummary.fromMap(map));
    } catch (_) {
      final cached = await _readCache(_reportKey);
      if (cached != null) {
        return AnalyticsResult(ReportSummary.fromMap(cached), fromCache: true);
      }
      return AnalyticsResult(ReportSummary.sample(), fromCache: true);
    }
  }

  /// Unread count and per-type counts (bell badge, filters).
  Future<NotificationSummary?> loadNotificationSummary() async {
    try {
      final res = await _client.rpc('get_notification_summary');
      final map = Map<String, dynamic>.from(res as Map);
      await _writeCache(_summaryKey, map);
      return NotificationSummary.fromMap(map);
    } catch (_) {
      final cached = await _readCache(_summaryKey);
      return cached == null ? null : NotificationSummary.fromMap(cached);
    }
  }

  /// Call on sign-out so the next user never sees this user's cached data.
  Future<void> clearCache() async {
    final box = await _box();
    await box?.delete(_reportKey);
    await box?.delete(_summaryKey);
  }
}
