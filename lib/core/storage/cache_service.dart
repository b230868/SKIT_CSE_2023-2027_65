import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static const String _boxName = 'prashikshan_offline_cache';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
        'CacheService has not been initialized. Call init() first.',
      );
    }
    return _box!;
  }

  static String _ownerKey(String ownerId, String key) => 'owner:$ownerId:$key';

  static Future<void> cacheData({
    required String ownerId,
    required String key,
    required Object data,
  }) async {
    await box.put(
      _ownerKey(ownerId, key),
      jsonEncode({'cached_at': DateTime.now().toIso8601String(), 'data': data}),
    );
  }

  static Object? getCachedData({required String ownerId, required String key}) {
    final raw = box.get(_ownerKey(ownerId, key));
    if (raw == null) return null;
    if (raw is! String) {
      throw const FormatException('Cached data has an invalid format.');
    }
    final payload = jsonDecode(raw);
    if (payload is! Map<String, dynamic> || !payload.containsKey('data')) {
      throw const FormatException('Cached data has an invalid format.');
    }
    return payload['data'];
  }

  static Future<void> removeCachedData({
    required String ownerId,
    required String key,
  }) async {
    await box.delete(_ownerKey(ownerId, key));
  }

  static Future<void> clearOwnerCache(String ownerId) async {
    final prefix = 'owner:$ownerId:';
    final keys = box.keys
        .where((key) => key is String && key.startsWith(prefix))
        .toList();
    await box.deleteAll(keys);
  }

  static Future<void> cacheDashboardStats(
    String key,
    Map<String, dynamic> stats,
  ) async {
    await box.put(
      'dashboard_$key',
      jsonEncode({
        'cached_at': DateTime.now().toIso8601String(),
        'data': stats,
      }),
    );
  }

  static Map<String, dynamic>? getCachedDashboardStats(String key) {
    final data = _getLegacyData('dashboard_$key');
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  static Future<void> cacheStudentMonitoring(
    List<Map<String, dynamic>> items,
  ) async {
    await box.put(
      'student_monitoring',
      jsonEncode({
        'cached_at': DateTime.now().toIso8601String(),
        'data': items,
      }),
    );
  }

  static List<Map<String, dynamic>>? getCachedStudentMonitoring() {
    final data = _getLegacyData('student_monitoring');
    if (data == null) return null;
    if (data is! List) {
      throw const FormatException(
        'Cached student monitoring has an invalid format.',
      );
    }
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<void> cacheReportData(Map<String, dynamic> data) async {
    await box.put(
      'faculty_reports',
      jsonEncode({'cached_at': DateTime.now().toIso8601String(), 'data': data}),
    );
  }

  static Map<String, dynamic>? getCachedReportData() {
    final data = _getLegacyData('faculty_reports');
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  static Object? _getLegacyData(String key) {
    final raw = box.get(key);
    if (raw == null) return null;
    if (raw is! String) {
      throw const FormatException('Cached data has an invalid format.');
    }
    final payload = jsonDecode(raw);
    if (payload is! Map<String, dynamic> || !payload.containsKey('data')) {
      throw const FormatException('Cached data has an invalid format.');
    }
    return payload['data'];
  }
}
