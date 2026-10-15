import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static const String _boxName = 'prashikshan_offline_cache';
  static Box? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
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

  static Future<void> cacheDashboardStats(
    String key,
    Map<String, dynamic> stats,
  ) async {
    try {
      final payload = {
        'cached_at': DateTime.now().toIso8601String(),
        'data': stats,
      };
      await box.put('dashboard_$key', jsonEncode(payload));
    } catch (_) {
      // Gracefully ignore caching failure
    }
  }

  static Map<String, dynamic>? getCachedDashboardStats(String key) {
    try {
      final raw = box.get('dashboard_$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      return decoded['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> cacheStudentMonitoring(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final payload = {
        'cached_at': DateTime.now().toIso8601String(),
        'data': items,
      };
      await box.put('student_monitoring', jsonEncode(payload));
    } catch (_) {
      // Gracefully ignore caching failure
    }
  }

  static List<Map<String, dynamic>>? getCachedStudentMonitoring() {
    try {
      final raw = box.get('student_monitoring');
      if (raw == null) return null;
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      final list = decoded['data'] as List?;
      if (list == null) return null;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> cacheReportData(Map<String, dynamic> data) async {
    try {
      final payload = {
        'cached_at': DateTime.now().toIso8601String(),
        'data': data,
      };
      await box.put('faculty_reports', jsonEncode(payload));
    } catch (_) {
      // Gracefully ignore caching failure
    }
  }

  static Map<String, dynamic>? getCachedReportData() {
    try {
      final raw = box.get('faculty_reports');
      if (raw == null) return null;
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      return decoded['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
