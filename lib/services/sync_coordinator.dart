import 'dart:async';

import 'package:flutter/widgets.dart';

import 'analytics_service.dart';
import 'notification_cache_service.dart';

enum SyncPhase { idle, syncing, offline }

class SyncState {
  final SyncPhase phase;
  final int pending; // offline actions waiting to be sent
  final DateTime? lastSyncedAt;

  const SyncState({
    this.phase = SyncPhase.idle,
    this.pending = 0,
    this.lastSyncedAt,
  });
}

/// Keeps notifications and analytics in sync in the background:
/// on start, when the app returns to the foreground, and every few minutes.
/// Listen to [state] to show a banner (see SyncStatusBanner).
class SyncCoordinator with WidgetsBindingObserver {
  SyncCoordinator._();
  static final SyncCoordinator instance = SyncCoordinator._();

  final ValueNotifier<SyncState> state = ValueNotifier(const SyncState());

  final _notifications = NotificationCacheService();
  final _analytics = AnalyticsService();

  Timer? _timer;
  bool _started = false;
  bool _running = false;

  /// Safe to call many times; only the first call starts the background sync.
  void start({Duration interval = const Duration(minutes: 2)}) {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) => syncNow());
    unawaited(syncNow());
  }

  /// Call on sign-out (together with clearing the caches).
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
    state.value = const SyncState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncNow());
  }

  Future<void> syncNow({bool full = false}) async {
    if (_running) return;
    _running = true;

    try {
      state.value = SyncState(
        phase: SyncPhase.syncing,
        pending: await _notifications.pendingCount(),
        lastSyncedAt: await _notifications.lastSyncedAt(),
      );

      final result = await _notifications.sync(full: full);
      final report = await _analytics.loadReport();

      final offline =
          (!result.ok && !result.skipped) || (report?.fromCache ?? false);

      state.value = SyncState(
        phase: offline ? SyncPhase.offline : SyncPhase.idle,
        pending: await _notifications.pendingCount(),
        lastSyncedAt: await _notifications.lastSyncedAt(),
      );
    } finally {
      _running = false;
    }
  }
}
