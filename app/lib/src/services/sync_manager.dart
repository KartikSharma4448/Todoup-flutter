import 'dart:async';

import 'package:flutter/foundation.dart';

import 'task_repository.dart';
import '../connectivity_service.dart';

class SyncManager {
  SyncManager({
    required TaskRepository repository,
    required ConnectivityService connectivity,
    this.initialBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(minutes: 2),
    this.onSyncStart,
    this.onSyncComplete,
    this.onSyncError,
  })  : _repository = repository,
        _connectivity = connectivity,
        _currentBackoff = initialBackoff;

  final TaskRepository _repository;
  final ConnectivityService _connectivity;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final VoidCallback? onSyncStart;
  final Future<void> Function(bool synced)? onSyncComplete;
  final void Function(Object error)? onSyncError;

  Duration _currentBackoff;
  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _retryTimer;

  bool get isSyncing => _isSyncing;

  void start() {
    _connectivitySubscription ??= _connectivity.onStatusChange.listen(_handleConnectivityChange);
    if (_connectivity.isOnline) {
      unawaited(syncNow());
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
  }

  Future<bool> syncNow() async {
    if (!_connectivity.isOnline || _isSyncing) {
      return false;
    }
    _retryTimer?.cancel();
    return _runSync();
  }

  void _handleConnectivityChange(bool online) {
    if (!online) {
      return;
    }
    unawaited(syncNow());
  }

  Future<bool> _runSync() async {
    if (_isSyncing) {
      return false;
    }

    _isSyncing = true;
    onSyncStart?.call();

    try {
      final synced = await _repository.syncPending();
      _currentBackoff = _clampDuration(initialBackoff, initialBackoff, maxBackoff);
      await onSyncComplete?.call(synced);
      return synced;
    } catch (error) {
      onSyncError?.call(error);
      _currentBackoff = _clampDuration(
        _currentBackoff + _currentBackoff,
        initialBackoff,
        maxBackoff,
      );
      _scheduleRetry();
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_currentBackoff, () => unawaited(_runSync()));
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value.compareTo(min) < 0) {
      return min;
    }
    if (value.compareTo(max) > 0) {
      return max;
    }
    return value;
  }
}
