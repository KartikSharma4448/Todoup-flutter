import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> initialize() async {
    final initial = await _connectivity.checkConnectivity();
    _isOnline = _isOnlineResult(initial);

    _connectivity.onConnectivityChanged.listen((result) {
      final next = _isOnlineResult(result);
      if (next == _isOnline) {
        return;
      }
      _isOnline = next;
      _controller.add(next);
    });
  }

  void dispose() {
    _controller.close();
  }

  bool _isOnlineResult(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      if (result.isEmpty) return false;
      return result.any((item) => item != ConnectivityResult.none);
    }
    return false;
  }
}
