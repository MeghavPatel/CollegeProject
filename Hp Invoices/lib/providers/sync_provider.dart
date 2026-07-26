import 'dart:async';
import 'package:flutter/material.dart';

class SyncProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingSyncCount => _pendingSyncCount;

  Timer? _syncTimer;

  SyncProvider() {
    // Poll/simulate network status fluctuations for testing offline-first
    _syncTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      // Periodic check or background sync triggers
      if (_isOnline && _pendingSyncCount > 0) {
        syncPendingQueue();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  // Manually toggle online/offline state to demonstrate offline resilience in UI
  void toggleConnection() {
    _isOnline = !_isOnline;
    notifyListeners();

    if (_isOnline && _pendingSyncCount > 0) {
      syncPendingQueue();
    }
  }

  void incrementPendingQueue() {
    _pendingSyncCount++;
    notifyListeners();
  }

  Future<void> syncPendingQueue() async {
    if (!_isOnline || _isSyncing || _pendingSyncCount == 0) return;

    _isSyncing = true;
    notifyListeners();

    // Simulate batch sync uploading to cloud database
    await Future.delayed(const Duration(seconds: 3));

    _pendingSyncCount = 0;
    _isSyncing = false;
    notifyListeners();
  }
}
