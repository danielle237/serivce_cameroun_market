import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Statut de connexion
// ─────────────────────────────────────────────────────────────────────────────
enum ConnectionStatus { online, offline, slow }

class ConnectivityNotifier extends AsyncNotifier<ConnectionStatus> {
  StreamSubscription? _sub;

  @override
  Future<ConnectionStatus> build() async {
    ref.onDispose(() => _sub?.cancel());

    // Écoute les changements réseau en temps réel
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final status = _fromResults(results);
      state = AsyncData(status);
    });

    // État initial
    final results = await Connectivity().checkConnectivity();
    return _fromResults(results);
  }

  ConnectionStatus _fromResults(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return ConnectionStatus.offline;
    }
    // Mobile = potentiellement lent (2G/3G)
    if (results.any((r) => r == ConnectivityResult.mobile)) {
      return ConnectionStatus.slow;
    }
    return ConnectionStatus.online;
  }

  /// Rafraîchir manuellement le statut
  Future<void> refresh() async {
    final results = await Connectivity().checkConnectivity();
    state = AsyncData(_fromResults(results));
  }
}

final connectivityProvider =
    AsyncNotifierProvider<ConnectivityNotifier, ConnectionStatus>(
        ConnectivityNotifier.new);

/// Raccourci : `ref.watch(isOnlineProvider)` → true/false
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityProvider).value;
  return status != ConnectionStatus.offline;
});

final isSlowConnectionProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityProvider).value;
  return status == ConnectionStatus.slow;
});
