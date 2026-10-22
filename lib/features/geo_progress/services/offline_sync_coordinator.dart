import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'geo_progress_service.dart';

class OfflineSyncCoordinator with WidgetsBindingObserver {
  OfflineSyncCoordinator({
    Connectivity? connectivity,
    SupabaseClient? client,
    GeoProgressService? progressService,
  }) : _connectivity = connectivity ?? Connectivity(),
       _client = client ?? Supabase.instance.client,
       _progressService = progressService ?? GeoProgressService();

  final Connectivity _connectivity;
  final SupabaseClient _client;
  final GeoProgressService _progressService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<AuthState>? _authSubscription;
  bool _started = false;
  bool _syncing = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (_hasConnection(results)) unawaited(_syncPendingProgress());
      },
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'offline sync',
            context: ErrorDescription(
              'while listening for connectivity changes',
            ),
          ),
        );
      },
    );
    _authSubscription = _client.auth.onAuthStateChange.listen((state) {
      if (state.session != null) unawaited(_syncIfConnected());
    });
    unawaited(_syncIfConnected());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncIfConnected());
    }
  }

  Future<void> dispose() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    await _connectivitySubscription?.cancel();
    await _authSubscription?.cancel();
  }

  Future<void> _syncIfConnected() async {
    try {
      if (_hasConnection(await _connectivity.checkConnectivity())) {
        await _syncPendingProgress();
      }
    } on Exception catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  Future<void> _syncPendingProgress() async {
    if (_syncing || _client.auth.currentUser == null) return;
    _syncing = true;
    try {
      final result = await _progressService.syncPendingProgress();
      if (result.failures.isNotEmpty) {
        final failures = result.failures.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('; ');
        _reportError(
          StateError(
            '${result.remainingCount} progress update(s) remain queued. $failures',
          ),
          StackTrace.current,
        );
      }
    } on Exception catch (error, stackTrace) {
      _reportError(error, stackTrace);
    } finally {
      _syncing = false;
    }
  }

  static bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  static void _reportError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'offline sync',
        context: ErrorDescription('while syncing queued progress updates'),
      ),
    );
  }
}
