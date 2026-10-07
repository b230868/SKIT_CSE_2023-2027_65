import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prashikshan/features/geo_progress/models/geo_progress_log.dart';
import 'package:prashikshan/features/geo_progress/services/geo_progress_queue.dart';

void main() {
  late Directory hiveDirectory;
  late Box<Map> box;
  late GeoProgressQueue queue;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('geo-progress-');
    Hive.init(hiveDirectory.path);
    box = await Hive.openBox<Map>('test_geo_progress_pending');
    queue = GeoProgressQueue(box: box);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  GeoProgressLog makeLog({
    required String clientRef,
    required String internshipId,
    required DateTime capturedAt,
  }) => GeoProgressLog(
    clientRef: clientRef,
    internshipId: internshipId,
    progressPercent: 25,
    taskSummary: 'Completed setup',
    latitude: 26.9,
    longitude: 75.8,
    accuracyM: 12,
    capturedAt: capturedAt,
    isPendingSync: true,
  );

  test(
    'persists pending logs and scopes them by owner and internship',
    () async {
      final older = makeLog(
        clientRef: 'log-a',
        internshipId: 'internship-a',
        capturedAt: DateTime.utc(2026, 10, 4),
      );
      final newer = makeLog(
        clientRef: 'log-b',
        internshipId: 'internship-a',
        capturedAt: DateTime.utc(2026, 10, 5),
      );
      final otherInternship = makeLog(
        clientRef: 'log-c',
        internshipId: 'internship-b',
        capturedAt: DateTime.utc(2026, 10, 6),
      );

      await queue.enqueue(older, ownerId: 'owner-a');
      await queue.enqueue(newer, ownerId: 'owner-a');
      await queue.enqueue(otherInternship, ownerId: 'owner-b');

      final pending = queue.pending(
        ownerId: 'owner-a',
        internshipId: 'internship-a',
      );
      expect(pending.map((log) => log.clientRef), ['log-b', 'log-a']);
      expect(pending.every((log) => log.isPendingSync), isTrue);
      expect(queue.pending(ownerId: 'owner-b').single.clientRef, 'log-c');
      expect(queue.count(ownerId: 'owner-a'), 2);
    },
  );

  test(
    'reopens persisted entries and removes only the specified owner entry',
    () async {
      final log = makeLog(
        clientRef: 'shared-reference',
        internshipId: 'internship-a',
        capturedAt: DateTime.utc(2026, 10, 4),
      );
      await queue.enqueue(log, ownerId: 'owner-a');
      await queue.enqueue(log, ownerId: 'owner-b');

      await box.close();
      box = await Hive.openBox<Map>('test_geo_progress_pending');
      queue = GeoProgressQueue(box: box);
      expect(queue.pending(ownerId: 'owner-a').single.clientRef, log.clientRef);

      await queue.remove(ownerId: 'owner-a', clientRef: log.clientRef);
      expect(queue.count(ownerId: 'owner-a'), 0);
      expect(queue.count(ownerId: 'owner-b'), 1);
    },
  );
}
