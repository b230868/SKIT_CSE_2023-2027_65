import 'dart:math' as math;

/// Pure sync helpers: no Supabase, Hive or Flutter imports, so they are easy to test.

const int maxSyncAttempts = 5;

/// Exponential back-off between retries: 5s, 10s, 20s, 40s ... capped at 5 minutes.
Duration backoffDelay(int attempts) {
  final steps = math.min(attempts < 0 ? 0 : attempts, 6);
  final seconds = 5 * (1 << steps);
  return Duration(seconds: seconds > 300 ? 300 : seconds);
}

/// An action (mark as read / delete) made offline that is waiting to be sent.
class PendingRead {
  final String id;
  final int attempts;
  final DateTime queuedAt;
  final DateTime? lastAttemptAt;

  const PendingRead({
    required this.id,
    required this.queuedAt,
    this.attempts = 0,
    this.lastAttemptAt,
  });

  /// True when the entry may be sent now (never tried, or its back-off passed).
  bool isDue(DateTime now) {
    final last = lastAttemptAt;
    if (attempts == 0 || last == null) return true;
    return now.difference(last) >= backoffDelay(attempts);
  }

  /// True when it failed too many times and should be dropped.
  bool get isExpired => attempts >= maxSyncAttempts;

  PendingRead retried(DateTime now) => PendingRead(
        id: id,
        queuedAt: queuedAt,
        attempts: attempts + 1,
        lastAttemptAt: now,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'attempts': attempts,
        'queued_at': queuedAt.toIso8601String(),
        'last_attempt_at': lastAttemptAt?.toIso8601String(),
      };

  /// Reads both the new format (a map) and the old format (just the id string).
  factory PendingRead.fromDynamic(dynamic value, {DateTime? now}) {
    final fallback = now ?? DateTime.now();
    if (value is String) return PendingRead(id: value, queuedAt: fallback);

    final m = Map<String, dynamic>.from(value as Map);
    return PendingRead(
      id: m['id'] as String,
      attempts: (m['attempts'] as num?)?.toInt() ?? 0,
      queuedAt: DateTime.tryParse((m['queued_at'] ?? '') as String) ?? fallback,
      lastAttemptAt: DateTime.tryParse((m['last_attempt_at'] ?? '') as String),
    );
  }
}

/// Adds [id] to the queue unless it is already there.
List<PendingRead> enqueue(List<PendingRead> queue, String id, DateTime now) {
  if (queue.any((p) => p.id == id)) return queue;
  return [...queue, PendingRead(id: id, queuedAt: now)];
}

/// Merges notification rows from the server into the cached rows.
///
/// * the server wins for every row it sends;
/// * rows only in the cache are kept (an incremental sync only sends changes);
/// * a row still waiting to be marked read on the server stays read locally;
/// * the result is sorted newest first.
///
/// For a full refresh pass `cached: const []` so rows deleted on the server vanish.
List<Map<String, dynamic>> mergeNotificationRows({
  required List<Map<String, dynamic>> cached,
  required List<Map<String, dynamic>> incoming,
  Set<String> pendingReadIds = const {},
}) {
  final byId = <String, Map<String, dynamic>>{
    for (final r in cached) r['id'] as String: Map<String, dynamic>.from(r),
  };
  for (final r in incoming) {
    byId[r['id'] as String] = Map<String, dynamic>.from(r);
  }
  for (final id in pendingReadIds) {
    final row = byId[id];
    if (row != null) row['is_read'] = true;
  }

  DateTime created(Map<String, dynamic> r) =>
      DateTime.tryParse((r['created_at'] ?? '') as String) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  final list = byId.values.toList()
    ..sort((a, b) => created(b).compareTo(created(a)));
  return list;
}

/// Cached data older than [maxAge] should be refreshed.
bool isStale(DateTime? lastSynced, DateTime now,
    {Duration maxAge = const Duration(minutes: 15)}) {
  if (lastSynced == null) return true;
  return now.difference(lastSynced) > maxAge;
}

/// A full download (which also removes server-deleted rows) is done at least daily.
bool needsFullRefresh(DateTime? lastFull, DateTime now,
    {Duration every = const Duration(hours: 24)}) {
  if (lastFull == null) return true;
  return now.difference(lastFull) > every;
}

/// Outcome of one sync run.
class SyncResult {
  final bool ok;
  final bool skipped;
  final int pushed;
  final int pulled;
  final int dropped;
  final String? error;

  const SyncResult({
    this.ok = true,
    this.skipped = false,
    this.pushed = 0,
    this.pulled = 0,
    this.dropped = 0,
    this.error,
  });

  const SyncResult.skipped() : this(skipped: true);
}
