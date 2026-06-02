import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class RoleChoiceScreen extends StatefulWidget {
  const RoleChoiceScreen({super.key});

  @override
  State<RoleChoiceScreen> createState() => _RoleChoiceScreenState();
}

class _RoleChoiceScreenState extends State<RoleChoiceScreen>
    with TickerProviderStateMixin {
  String? _selected; // 'client' | 'provider'
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    if (_selected == null) return;
    context.go('/auth/login?tab=register&role=$_selected');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxHeight < 780;
              return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  SizedBox(height: compact ? 8 : 16),

                  // ── Logo compact ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('W2D',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        )),
                  ),
                  const SizedBox(height: 20),

                  // ── Titre ─────────────────────────────────────────────────
                  const Text(
                    'Vous êtes ici pour…',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choisissez votre profil',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: compact ? 16 : 24),

                  // ── Carte Client ──────────────────────────────────────────
                  _RoleCard(
                    selected: _selected == 'client',
                    onTap: () => setState(() => _selected = 'client'),
                    emoji: '🔍',
                    title: 'Je cherche un service',
                    subtitle: 'Artisan, enseignant, ménagère\nprès de chez vous',
                    badge: 'CLIENT',
                    color: const Color(0xFF43A047),
                    features: compact ? [] : [
                      'Comparez les devis',
                      'Paiement sécurisé Mobile Money',
                      'Évaluez après le service',
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Carte Prestataire ─────────────────────────────────────
                  _RoleCard(
                    selected: _selected == 'provider',
                    onTap: () => setState(() => _selected = 'provider'),
                    emoji: '🔧',
                    title: 'Je propose mes services',
                    subtitle: 'Recevez des missions et\ndéveloppez votre clientèle',
                    badge: 'PRESTATAIRE',
                    color: const Color(0xFFF59E0B),
                    features: compact ? [] : [
                      'Missions proches de vous',
                      'Portfolio et avis visibles',
                      'Paiements garantis',
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Bouton continuer ──────────────────────────────────────
                  AnimatedOpacity(
                    opacity: _selected != null ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: _selected != null ? _continue : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _selected != null ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12, offset: const Offset(0, 4),
                            )
                          ] : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _selected == null
                                  ? 'Choisissez un profil'
                                  : _selected == 'client'
                                      ? 'Continuer comme Client'
                                      : 'Continuer comme Prestataire',
                              style: TextStyle(
                                color: _selected != null
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_selected != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded,
                                  color: AppColors.primary, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Lien connexion ────────────────────────────────────────
                  TextButton(
                    onPressed: () => context.go('/auth/login'),
                    child: Text(
                      'Déjà un compte ? Se connecter',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
            }),  // LayoutBuilder
          ),
        ),
      ),
    );
  }
}

// ── Carte de rôle ─────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String emoji, title, subtitle, badge;
  final Color color;
  final List<String> features;

  const _RoleCard({
    required this.selected,
    required this.onTap,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.color,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.2),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, 6),
            )
          ] : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji dans un cercle
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.12) : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge + titre
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: selected ? color : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.black87 : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: selected ? Colors.grey.shade600 : Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Features
                  ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(children: [
                      Icon(Icons.check_circle_rounded,
                          size: 13,
                          color: selected ? color : Colors.white54),
                      const SizedBox(width: 6),
                      Text(f, style: TextStyle(
                        fontSize: 11,
                        color: selected ? Colors.black54 : Colors.white60,
                      )),
                    ]),
                  )),
                ],
              ),
            ),

            // Check indicator
            AnimatedOpacity(
              opacity: selected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.check_circle_rounded, color: color, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
