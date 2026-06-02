import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../api/api_client.dart';

/// Bandeau animé affiché en haut de l'écran quand l'appareil est hors ligne.
/// Se rétracte automatiquement quand la connexion revient + rejoue la queue.
class OfflineBanner extends ConsumerStatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _heightAnim;
  bool _wasOffline = false;
  bool _showReconnected = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _heightAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final isSlow   = ref.watch(isSlowConnectionProvider);

    // Détecter le retour en ligne
    ref.listen(isOnlineProvider, (prev, next) {
      if (prev == false && next == true) {
        // Vient de se reconnecter → rejouer la queue
        final api = ref.read(apiClientProvider);
        api.replayOfflineQueue();
        setState(() => _showReconnected = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showReconnected = false);
        });
      }
      if (next == false) {
        setState(() => _wasOffline = true);
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    });

    if (isOnline && !_showReconnected) return widget.child;

    return Column(
      children: [
        // ── Bandeau hors-ligne ────────────────────────────────────────────
        if (!isOnline)
          SizeTransition(
            sizeFactor: _heightAnim,
            axisAlignment: -1,
            child: Material(
              color: const Color(0xFF1A1A1A),
              child: SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Pas de connexion internet',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            )),
                        Text('Les données affichées sont en cache local',
                            style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ]),
                    ),
                    // Nombre d'actions en attente
                    Consumer(builder: (_, ref, __) {
                      final count = ref.watch(apiClientProvider).pendingActionsCount;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count en attente',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      );
                    }),
                  ]),
                ),
              ),
            ),
          ),

        // ── Bandeau connexion lente ───────────────────────────────────────
        if (isOnline && isSlow && !_showReconnected)
          Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              color: const Color(0xFFF59E0B).withOpacity(0.9),
              child: const Row(children: [
                Icon(Icons.signal_cellular_alt_1_bar_rounded,
                    color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text('Connexion lente détectée — chargement en cours…',
                    style: TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),

        // ── Bandeau reconnecté ────────────────────────────────────────────
        if (_showReconnected)
          AnimatedOpacity(
            opacity: _showReconnected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: Colors.green.shade600,
              child: const Row(children: [
                Icon(Icons.wifi_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Connexion rétablie — données synchronisées',
                    style: TextStyle(color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),

        Expanded(child: widget.child),
      ],
    );
  }
}
