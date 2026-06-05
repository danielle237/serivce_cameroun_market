import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/badges_provider.dart';
import '../../../core/theme/app_theme.dart';

// ── Providers annonces pour la page d'accueil ─────────────────────────────────
final _homeEducationRequestsProvider = FutureProvider.autoDispose<List>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/education/requests', forceRefresh: true);
    final data = res.data;
    return data is List ? data.take(5).toList() : [];
  } catch (_) { return []; }
});

final _homeArtisanRequestsProvider = FutureProvider.autoDispose<List>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/artisans/requests', forceRefresh: true);
    final data = res.data;
    return data is List ? data.take(5).toList() : [];
  } catch (_) { return []; }
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _switching = false;

  Future<void> _switchMode(String current) async {
    final next = current == 'provider' ? 'client' : 'provider';
    setState(() => _switching = true);
    try {
      final api = ref.read(apiClientProvider);

      // 1. Changer le mode côté serveur
      await api.patch('/users/mode', data: {'mode': next});

      // 2. Rafraîchir le JWT pour que les nouvelles claims (activeMode) soient incluses
      //    Sans ça, le mode change en base mais le token garde l'ancien rôle
      final storage = ref.read(authStateProvider.notifier);
      final refreshToken = ref.read(authStateProvider).value?.refreshToken;
      if (refreshToken != null) {
        try {
          final refreshRes = await api.post('/auth/refresh',
              data: {'refreshToken': refreshToken});
          final newAccess  = refreshRes.data['accessToken']  as String;
          final newRefresh = refreshRes.data['refreshToken'] as String;
          // Le nouveau JWT contient le user mis à jour avec activeMode
          final userRaw = refreshRes.data['user'];
          Map<String, dynamic> updatedUser;
          if (userRaw is Map) {
            updatedUser = Map<String, dynamic>.from(userRaw);
          } else {
            final cur = ref.read(authStateProvider).value?.user ?? {};
            updatedUser = {...cur, 'activeMode': next};
          }
          await storage.setAuth(newAccess, newRefresh, updatedUser);
        } catch (_) {
          // Fallback : mettre à jour juste activeMode localement
          final cur = ref.read(authStateProvider).value?.user ?? {};
          await storage.updateUser({...cur, 'activeMode': next});
        }
      } else {
        final cur = ref.read(authStateProvider).value?.user ?? {};
        await storage.updateUser({...cur, 'activeMode': next});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next == 'provider'
              ? '🔧 Mode Prestataire activé'
              : '👤 Mode Client activé'),
          backgroundColor: next == 'provider' ? Colors.blue : Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur switch mode: $e'), backgroundColor: Colors.red),
      );
    }
    if (mounted) setState(() => _switching = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final user = auth.value?.user;
    final activeMode = user?['activeMode'] as String? ?? 'client';
    final isProvider = activeMode == 'provider';
    final name = (user?['name'] ?? user?['fullName'] ?? 'Utilisateur')
        .toString().split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: KentePattern(opacity: 0.025)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────────────
                  _Header(
                    name: name,
                    user: user,
                    isProvider: isProvider,
                    switching: _switching,
                    onSwitch: () => _switchMode(activeMode),
                  ),
                  const SizedBox(height: 16),

                  // ── Carte rôle actif ────────────────────────────────────
                  _RoleBanner(isProvider: isProvider, user: user),
                  const SizedBox(height: 20),

                  // ── Grille de services ──────────────────────────────────
                  Text(
                    isProvider ? 'Mes espaces de travail' : 'Nos services',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Consumer(builder: (context, ref, _) {
                    final badges = ref.watch(badgesProvider).value ?? BadgeCounts.empty;
                    return isProvider
                        ? _ProviderGrid(badges: badges)
                        : _ClientGrid(badges: badges);
                  }),

                  const SizedBox(height: 24),

                  // ── Annonces disponibles (prestataire uniquement) ────────
                  if (isProvider) ...[
                    _AnnouncementsSection(user: user),
                    const SizedBox(height: 24),
                  ],

                  // ── Activité récente ────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Activité récente',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      TextButton(onPressed: () {}, child: const Text('Voir tout')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Consumer(builder: (context, ref, _) {
                    final activityAsync = ref.watch(recentActivityProvider);
                    return activityAsync.when(
                      loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )),
                      error: (_, __) => _RecentActivity(isProvider: isProvider, items: const []),
                      data: (items) => _RecentActivity(isProvider: isProvider, items: items),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String name;
  final Map<String, dynamic>? user;
  final bool isProvider;
  final bool switching;
  final VoidCallback onSwitch;

  const _Header({
    required this.name,
    required this.user,
    required this.isProvider,
    required this.switching,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Avatar
      CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.primary.withOpacity(0.12),
        backgroundImage: user?['profilePhotoUrl'] != null
            ? NetworkImage(user!['profilePhotoUrl']) : null,
        child: user?['profilePhotoUrl'] == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
              )
            : null,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bonjour,',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          Text(name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ]),
      ),

      // Toggle Client / Prestataire
      GestureDetector(
        onTap: switching ? null : onSwitch,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isProvider
                  ? [const Color(0xFF1976D2), const Color(0xFF1565C0)]
                  : [const Color(0xFF43A047), const Color(0xFF2E7D32)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: (isProvider ? Colors.blue : Colors.green).withOpacity(0.3),
              blurRadius: 8, offset: const Offset(0, 2),
            )],
          ),
          child: switching
              ? const SizedBox(
                  width: 80, height: 18,
                  child: Center(child: SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isProvider ? Icons.work_outline : Icons.person_outline,
                    color: Colors.white, size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isProvider ? 'Prestataire' : 'Client',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.swap_horiz, color: Colors.white70, size: 14),
                ]),
        ),
      ),
    ]);
  }
}

// ── Bannière rôle actif ───────────────────────────────────────────────────────
class _RoleBanner extends StatelessWidget {
  final bool isProvider;
  final Map<String, dynamic>? user;

  const _RoleBanner({required this.isProvider, required this.user});

  @override
  Widget build(BuildContext context) {
    final score = user?['trustScore'] ?? '0.0';
    final kyc = (user?['kycStatus'] ?? 'unverified') == 'verified';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProvider
              ? [const Color(0xFF1565C0), const Color(0xFF1976D2)]
              : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: (isProvider ? Colors.blue : Colors.green).withOpacity(0.25),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isProvider ? Icons.engineering_outlined : Icons.person_outline,
            color: Colors.white, size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isProvider ? '🔧 MODE PRESTATAIRE' : '👤 MODE CLIENT',
                style: const TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800,
                    letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kyc ? Colors.white.withOpacity(0.2) : Colors.orange.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                kyc ? '✅ Vérifié' : '⏳ KYC en cours',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            isProvider
                ? 'Vous êtes en mode prestataire — gérez vos missions'
                : 'Vous êtes en mode client — accédez à tous les services',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ])),
        Column(children: [
          Text('$score', style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('/5.0', style: TextStyle(color: Colors.white60, fontSize: 11)),
          Row(children: List.generate(5, (i) => Icon(
            Icons.star_rounded,
            size: 12,
            color: i < (double.tryParse('$score')?.round() ?? 0)
                ? Colors.amber : Colors.white30,
          ))),
        ]),
      ]),
    );
  }
}

// ── Grille client ─────────────────────────────────────────────────────────────
class _ClientGrid extends StatelessWidget {
  final BadgeCounts badges;
  const _ClientGrid({required this.badges});

  @override
  Widget build(BuildContext context) {
    final services = [
      _ServiceItem('🎓', 'Éducation',  const Color(0xFF4F46E5), '/education',   badges.education),
      _ServiceItem('🔧', 'Artisans',   const Color(0xFFF59E0B), '/artisans',    badges.artisans),
      _ServiceItem('🏠', 'Immobilier', const Color(0xFF10B981), '/immobilier',  0),
      _ServiceItem('🧹', 'Ménagère',   const Color(0xFFEC4899), '/menagere',    0),
      _ServiceItem('🛵', 'Moto',       const Color(0xFFEF4444), '/moto',        0),
      _ServiceItem('🛒', 'Marché',     const Color(0xFF8B5CF6), '/marketplace', 0),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: services.map((s) => _ServiceCard(item: s)).toList(),
    );
  }
}

// ── Grille prestataire ────────────────────────────────────────────────────────
class _ProviderGrid extends StatelessWidget {
  final BadgeCounts badges;
  const _ProviderGrid({required this.badges});

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ServiceItem('🔧', 'Mes devis',     const Color(0xFFF59E0B), '/artisans',              badges.artisans),
      _ServiceItem('🎓', 'Mes cours',     const Color(0xFF4F46E5), '/education',             badges.education),
      _ServiceItem('🧹', 'Mes missions',  const Color(0xFFEC4899), '/menagere',              0),
      _ServiceItem('🛵', 'Mes livraisons',const Color(0xFFEF4444), '/moto',                  0),
      _ServiceItem('🏠', 'Mes biens',     const Color(0xFF10B981), '/immobilier',            0),
      _ServiceItem('💼', 'Mon portfolio', const Color(0xFF0EA5E9), '/artisans/portfolio/me', 0),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: modules.map((s) => _ServiceCard(item: s, isProvider: true)).toList(),
    );
  }
}

// ── Carte service ─────────────────────────────────────────────────────────────
class _ServiceItem {
  final String icon, label, route;
  final Color color;
  final int badge;
  const _ServiceItem(this.icon, this.label, this.color, this.route, this.badge);
}

class _ServiceCard extends ConsumerWidget {
  final _ServiceItem item;
  final bool isProvider;
  const _ServiceCard({required this.item, this.isProvider = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        if (item.route == '/artisans/portfolio/me') {
          final userId = ref.read(authStateProvider).value?.user?['id'];
          if (userId != null) context.push('/artisans/portfolio/$userId');
        } else {
          context.push(item.route);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                color: item.color.withOpacity(0.12),
                blurRadius: 8, offset: const Offset(0, 3),
              )],
              border: Border.all(color: item.color.withOpacity(0.15)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(item.icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: item.color),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ]),
          ),
          if (item.badge > 0)
            Positioned(
              top: -4, right: -4,
              child: Container(
                width: item.badge > 9 ? 22 : 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 4,
                  )],
                ),
                child: Center(
                  child: Text(
                    item.badge > 99 ? '99+' : '${item.badge}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Activité récente ──────────────────────────────────────────────────────────
class _RecentActivity extends StatelessWidget {
  final bool isProvider;
  final List<Map<String, dynamic>> items;
  const _RecentActivity({required this.isProvider, required this.items});

  static const _iconMap = {
    'artisan':       Icons.handyman_outlined,
    'artisan_quote': Icons.request_quote_outlined,
    'education':     Icons.school_outlined,
    'education_app': Icons.assignment_outlined,
  };

  static const _colorMap = {
    'artisan':       Color(0xFFF59E0B),
    'artisan_quote': Color(0xFFF59E0B),
    'education':     Color(0xFF4F46E5),
    'education_app': Color(0xFF4F46E5),
  };

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('Aucune activité récente',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ]),
        ),
      );
    }
    return Column(
      children: items.asMap().entries.map((e) {
        final i = e.key;
        final item = e.value;
        final type = item['type'] as String? ?? 'artisan';
        final icon = _iconMap[type] ?? Icons.circle_outlined;
        final color = _colorMap[type] ?? AppColors.primary;
        final amount = item['amount'];
        final subtitle = amount != null
            ? '${item['subtitle']} · ${_fmt(amount)} FCFA'
            : item['subtitle'] as String? ?? '';
        return Column(children: [
          _ActivityCard(
            icon: icon,
            color: color,
            title: item['title'] as String? ?? '',
            subtitle: subtitle,
            status: item['status'] as String? ?? '',
          ),
          if (i < items.length - 1) const SizedBox(height: 8),
        ]);
      }).toList(),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    final n = v is int ? v : (v is double ? v.toInt() : int.tryParse(v.toString()) ?? 0);
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }
}

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle, status;
  const _ActivityCard({
    required this.icon, required this.color,
    required this.title, required this.subtitle, required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Text(status,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION ANNONCES — visible seulement en mode prestataire
// Affiche éducation + artisans, clic direct pour proposer un contrat
// ═════════════════════════════════════════════════════════════════════════════
class _AnnouncementsSection extends ConsumerWidget {
  final Map<String, dynamic>? user;
  const _AnnouncementsSection({this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final professions = (user?['professions'] as List?)?.cast<String>() ?? [];
    final isTeacher = professions.any((p) {
      final pl = p.toLowerCase();
      return pl.contains('enseig') || pl.contains('professeur') ||
             pl.contains('cours') || pl.contains('education') || pl.contains('tuteur');
    });
    final isArtisan = professions.any((p) {
      final pl = p.toLowerCase();
      return pl.contains('artisan') || pl.contains('électric') || pl.contains('plomb') ||
             pl.contains('maçon') || pl.contains('menuisier') || pl.contains('peintre') ||
             pl.contains('carreleur') || pl.contains('soudeur');
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('📋 Annonces disponibles',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),

      // Annonces éducation
      if (isTeacher || professions.isEmpty)
        _AnnouncementsList(
          icon: '📚',
          label: 'Cours particuliers',
          color: const Color(0xFF1976D2),
          provider: _homeEducationRequestsProvider,
          onTap: (item) => context.push('/education/requests'),
        ),

      if ((isTeacher || professions.isEmpty) && (isArtisan || professions.isEmpty))
        const SizedBox(height: 10),

      // Annonces artisans
      if (isArtisan || professions.isEmpty)
        _AnnouncementsList(
          icon: '🔧',
          label: 'Travaux & services',
          color: const Color(0xFFF59E0B),
          provider: _homeArtisanRequestsProvider,
          onTap: (item) {
            final id = item['id'] as String?;
            if (id != null) context.push('/artisans/quotes/$id?title=${Uri.encodeComponent(item['title'] ?? 'Demande')}');
          },
        ),

      // Si aucune catégorie détectée, afficher les deux
      if (!isTeacher && !isArtisan && professions.isNotEmpty)
        Text('Completez votre profil pour voir les annonces correspondantes',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
    ]);
  }
}

class _AnnouncementsList extends ConsumerWidget {
  final String icon, label;
  final Color color;
  final ProviderBase<AsyncValue<List>> provider;
  final void Function(Map<String, dynamic>) onTap;

  const _AnnouncementsList({
    required this.icon, required this.label, required this.color,
    required this.provider, required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const SizedBox(height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('$icon $label',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('${items.length}',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          ...items.map((item) => _AnnouncementTile(
            item: Map<String, dynamic>.from(item),
            color: color,
            onTap: () => onTap(Map<String, dynamic>.from(item)),
          )),
        ]);
      },
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color color;
  final VoidCallback onTap;
  const _AnnouncementTile({required this.item, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = item['title'] ?? item['subject'] ?? 'Annonce';
    final location = item['locationAddress'] ?? item['location'] ?? '';
    final budget = item['budgetPerSession'] ?? item['budgetMin'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.assignment_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toString(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (location.toString().isNotEmpty)
              Text(location.toString(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (budget != null) ...[
            const SizedBox(width: 8),
            Text('${budget} FCFA',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: color, size: 18),
        ]),
      ),
    );
  }
}
