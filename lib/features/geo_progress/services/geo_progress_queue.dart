import 'package:hive_flutter/hive_flutter.dart';

import '../models/geo_progress_log.dart';

class GeoProgressQueue {
  static const boxName = 'geo_progress_pending';

  GeoProgressQueue({required this._box});

  final Box<Map> _box;

  Future<void> enqueue(GeoProgressLog log, {required String ownerId}) {
    return _box.put(_key(ownerId, log.clientRef), {
      ...log.toInsertJson(),
      'owner_id': ownerId,
      'is_pending_sync': true,
    });
  }

  List<GeoProgressLog> pending({
    required String ownerId,
    String? internshipId,
  }) {
    final logs =
        _box.values
            .where(
              (entry) =>
                  entry['owner_id'] == ownerId &&
                  (internshipId == null ||
                      entry['internship_id'] == internshipId),
            )
            .map(
              (entry) =>
                  GeoProgressLog.fromJson(Map<String, dynamic>.from(entry)),
            )
            .toList()
          ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return logs;
  }

  int count({required String ownerId}) =>
      _box.values.where((entry) => entry['owner_id'] == ownerId).length;

  Future<void> remove({required String ownerId, required String clientRef}) =>
      _box.delete(_key(ownerId, clientRef));

  String _key(String ownerId, String clientRef) => '$ownerId:$clientRef';
}
