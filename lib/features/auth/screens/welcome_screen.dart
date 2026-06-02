import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

// ─── Provider messages défilants ─────────────────────────────────────────────
final tickerProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/ticker');
    return List<Map<String, dynamic>>.from(
        (res.data as List).map((e) => Map<String, dynamic>.from(e)));
  } catch (_) {
    return [];
  }
});

// ═════════════════════════════════════════════════════════════════════════════
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickerAsync = ref.watch(tickerProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Fond dégradé ──────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Motif kente en filigrane ─────────────────────────────────────
          const Positioned.fill(child: KentePattern(opacity: 0.06)),

          // ── Cercles décoratifs ────────────────────────────────────────────
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 120, left: -40,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.3, right: -20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.15),
              ),
            ),
          ),

          // ── Contenu principal ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Bandeau défilant en haut
                tickerAsync.when(
                  loading: () => const SizedBox(height: 36),
                  error: (_, __) => const SizedBox(height: 36),
                  data: (msgs) => msgs.isEmpty
                      ? const SizedBox(height: 36)
                      : _TickerBanner(messages: msgs),
                ),

                // Corps principal
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: size.height * 0.78,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            const SizedBox(height: 32),

                            // ── Logo ─────────────────────────────────────
                            Container(
                              width: 110, height: 110,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('W2D',
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                          letterSpacing: 1,
                                        )),
                                    Text('trust',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 2,
                                        )),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Titre ─────────────────────────────────────
                            const Text(
                              'Bienvenue sur W2D',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'La plateforme de confiance\npour les services au Cameroun',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white70,
                                height: 1.6,
                              ),
                            ),

                            const SizedBox(height: 36),

                            // ── Features ──────────────────────────────────
                            _FeatureTile(
                              icon: Icons.security_rounded,
                              color: AppColors.secondary,
                              title: 'Fonds sécurisés',
                              subtitle: 'Argent bloqué jusqu\'à validation du service',
                            ),
                            const SizedBox(height: 12),
                            _FeatureTile(
                              icon: Icons.verified_rounded,
                              color: Colors.lightBlueAccent,
                              title: 'Prestataires vérifiés',
                              subtitle: 'Identité et documents contrôlés par W2D',
                            ),
                            const SizedBox(height: 12),
                            _FeatureTile(
                              icon: Icons.phone_android_rounded,
                              color: Colors.greenAccent,
                              title: 'Paiement Mobile Money',
                              subtitle: 'MTN, Orange Money, Visa acceptés',
                            ),

                            const Spacer(),
                            const SizedBox(height: 40),

                            // ── Bouton Se connecter ───────────────────────
                            ElevatedButton.icon(
                              onPressed: () => context.go('/auth/login'),
                              icon: const Icon(Icons.login_rounded, size: 20),
                              label: const Text(
                                'Se connecter',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                minimumSize: const Size(double.infinity, 58),
                                elevation: 4,
                                shadowColor: Colors.black38,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ── Bouton S'enregistrer ──────────────────────
                            OutlinedButton.icon(
                              onPressed: () => context.go('/auth/role-choice'),
                              icon: const Icon(Icons.person_add_rounded, size: 20),
                              label: const Text(
                                'S\'enregistrer',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 58),
                                side: const BorderSide(color: Colors.white60, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Mention légale ────────────────────────────
                            Text(
                              'En continuant, vous acceptez nos Conditions d\'utilisation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.45),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BANDEAU DÉFILANT
// ═════════════════════════════════════════════════════════════════════════════
class _TickerBanner extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  const _TickerBanner({required this.messages});

  @override
  State<_TickerBanner> createState() => _TickerBannerState();
}

class _TickerBannerState extends State<_TickerBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _currentIndex = 0;
  Timer? _switchTimer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
    // Changer de message toutes les 8 secondes si plusieurs messages
    if (widget.messages.length > 1) {
      _switchTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.messages.length;
          });
          _ctrl.reset();
          _ctrl.forward();
        }
      });
    }
  }

  void _startAnimation() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _anim = Tween<double>(begin: 1.0, end: -1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );
    _ctrl.forward();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _ctrl.reset();
        _ctrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _switchTimer?.cancel();
    super.dispose();
  }

  Color _bgColor(String type) {
    switch (type) {
      case 'warning': return const Color(0xFFFF8C00);
      case 'promo':   return const Color(0xFF9C27B0);
      default:        return const Color(0xFF004D2C);
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'warning': return Colors.white;
      case 'promo':   return Colors.yellow;
      default:        return Colors.greenAccent;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'promo':   return Icons.local_offer_rounded;
      default:        return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.messages[_currentIndex];
    final type = msg['type'] as String? ?? 'info';
    final text = msg['message'] as String? ?? '';

    return Container(
      height: 36,
      color: _bgColor(type).withOpacity(0.92),
      child: Row(
        children: [
          // Icône fixe à gauche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(_icon(type), size: 16, color: _iconColor(type)),
          ),
          // Texte défilant
          Expanded(
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, child) {
                  return FractionalTranslation(
                    translation: Offset(_anim.value, 0),
                    child: child,
                  );
                },
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          // Compteur si plusieurs messages
          if (widget.messages.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_currentIndex + 1}/${widget.messages.length}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TUILE DE FEATURE
// ═════════════════════════════════════════════════════════════════════════════
class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _FeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
