// Unit tests for the S5 sync refinements (pure logic, no Supabase or Hive).
// Run with:  flutter test test/features/student/s5_sync_logic_test.dart
//
// If your lints complain about relative lib imports, replace the import with
// package:<your_package_name>/features/student/services/sync_merge.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:prashikshan/services/sync_merge.dart';

Map<String, dynamic> row(String id, String createdAt, {bool read = false}) => {
      'id': id,
      'title': 't$id',
      'created_at': createdAt,
      'is_read': read,
    };

void main() {
  final t0 = DateTime.utc(2026, 11, 23, 10);

  group('back-off', () {
    test('doubles each attempt and is capped at 5 minutes', () {
      expect(backoffDelay(0), const Duration(seconds: 5));
      expect(backoffDelay(1), const Duration(seconds: 10));
      expect(backoffDelay(3), const Duration(seconds: 40));
      expect(backoffDelay(10), const Duration(seconds: 300));
      expect(backoffDelay(-2), const Duration(seconds: 5));
    });
  });

  group('PendingRead', () {
    test('a new entry is due immediately', () {
      expect(PendingRead(id: 'a', queuedAt: t0).isDue(t0), isTrue);
    });

    test('after a failed attempt it waits for the back-off', () {
      final p = PendingRead(id: 'a', queuedAt: t0).retried(t0);
      expect(p.attempts, 1);
      expect(p.isDue(t0.add(const Duration(seconds: 9))), isFalse);
      expect(p.isDue(t0.add(const Duration(seconds: 10))), isTrue);
    });

    test('expires after the maximum number of attempts', () {
      var p = PendingRead(id: 'a', queuedAt: t0);
      for (var i = 0; i < maxSyncAttempts; i++) {
        expect(p.isExpired, isFalse);
        p = p.retried(t0);
      }
      expect(p.isExpired, isTrue);
    });

    test('reads the old format (plain id string)', () {
      final p = PendingRead.fromDynamic('abc', now: t0);
      expect(p.id, 'abc');
      expect(p.attempts, 0);
      expect(p.queuedAt, t0);
    });

    test('round-trips through a map', () {
      final p = PendingRead(id: 'a', queuedAt: t0).retried(t0);
      final back = PendingRead.fromDynamic(p.toMap());
      expect(back.id, 'a');
      expect(back.attempts, 1);
      expect(back.lastAttemptAt, t0);
    });

    test('enqueue does not add duplicates', () {
      var q = <PendingRead>[];
      q = enqueue(q, 'a', t0);
      q = enqueue(q, 'a', t0);
      q = enqueue(q, 'b', t0);
      expect(q.map((p) => p.id), ['a', 'b']);
    });
  });

  group('mergeNotificationRows', () {
    test('server version wins and result is newest first', () {
      final merged = mergeNotificationRows(
        cached: [row('1', '2026-11-20T10:00:00Z'), row('2', '2026-11-21T10:00:00Z')],
        incoming: [row('1', '2026-11-20T10:00:00Z', read: true)],
      );
      expect(merged.map((r) => r['id']), ['2', '1']);
      expect(merged.last['is_read'], isTrue);
    });

    test('incremental sync keeps cached rows the server did not send', () {
      final merged = mergeNotificationRows(
        cached: [row('1', '2026-11-20T10:00:00Z')],
        incoming: [row('3', '2026-11-22T10:00:00Z')],
      );
      expect(merged.map((r) => r['id']), ['3', '1']);
    });

    test('full refresh (empty cache) drops rows deleted on the server', () {
      final merged = mergeNotificationRows(
        cached: const [],
        incoming: [row('3', '2026-11-22T10:00:00Z')],
      );
      expect(merged.map((r) => r['id']), ['3']);
    });

    test('a notification read offline stays read until the server knows', () {
      final merged = mergeNotificationRows(
        cached: const [],
        incoming: [row('1', '2026-11-20T10:00:00Z', read: false)],
        pendingReadIds: {'1'},
      );
      expect(merged.single['is_read'], isTrue);
    });
  });

  group('refresh rules', () {
    test('isStale', () {
      expect(isStale(null, t0), isTrue);
      expect(isStale(t0, t0.add(const Duration(minutes: 10))), isFalse);
      expect(isStale(t0, t0.add(const Duration(minutes: 20))), isTrue);
    });

    test('needsFullRefresh', () {
      expect(needsFullRefresh(null, t0), isTrue);
      expect(needsFullRefresh(t0, t0.add(const Duration(hours: 5))), isFalse);
      expect(needsFullRefresh(t0, t0.add(const Duration(hours: 25))), isTrue);
    });
  });

  test('SyncResult.skipped is flagged', () {
    const r = SyncResult.skipped();
    expect(r.skipped, isTrue);
    expect(r.pushed, 0);
  });
}
