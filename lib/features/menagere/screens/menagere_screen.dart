import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/i18n/app_translations.dart';

// ─── Métadonnées services ────────────────────────────────────────────────────
const _servicesMeta = {
  'nettoyage':    {'labelKey': 'nettoyage',    'emoji': '🧹', 'color': 0xFF1565C0},
  'cuisine':      {'labelKey': 'cuisine',      'emoji': '🍳', 'color': 0xFFE65100},
  'garde_enfants':{'labelKey': 'garde_enfants','emoji': '👶', 'color': 0xFFAD1457},
  'repassage':    {'labelKey': 'repassage',    'emoji': '👔', 'color': 0xFF6A1B9A},
  'lessive':      {'labelKey': 'lessive',      'emoji': '🫧', 'color': 0xFF00695C},
  'courses':      {'labelKey': 'courses_svc',  'emoji': '🛒', 'color': 0xFF2E7D32},
};

const _modesMeta = {
  'once':     {'labelKey': 'ponctuel',    'emoji': '1️⃣'},
  'regular':  {'labelKey': 'regulier',    'emoji': '🔄'},
  'live_in':  {'labelKey': 'residentiel', 'emoji': '🏠'},
};

const _pink = Color(0xFFEC4899);

// ═════════════════════════════════════════════════════════════════════════════
class MenagereScreen extends ConsumerStatefulWidget {
  const MenagereScreen({super.key});
  @override
  ConsumerState<MenagereScreen> createState() => _MenagereScreenState();
}

class _MenagereScreenState extends ConsumerState<MenagereScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _hasWorkerProfile = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _checkWorkerProfile();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _checkWorkerProfile() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/menagere/profiles/me');
      if (mounted && res.data != null) setState(() => _hasWorkerProfile = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F6),
      appBar: AppBar(
        title: Text(AppTranslations.of(context).t('menagere')),
        backgroundColor: _pink,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: AppTranslations.of(context).t('become_housekeeper'),
            onPressed: () => context.push('/menagere/publish'),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: AppTranslations.of(context).t('find_tab')),
            Tab(text: AppTranslations.of(context).t('my_contracts')),
            Tab(text: AppTranslations.of(context).t('my_profile')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _FindTab(),
          _ContractsTab(),
          _WorkerTab(),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET TROUVER
// ═════════════════════════════════════════════════════════════════════════════
class _FindTab extends ConsumerStatefulWidget {
  const _FindTab();
  @override
  ConsumerState<_FindTab> createState() => _FindTabState();
}

class _FindTabState extends ConsumerState<_FindTab> {
  final _cityCtrl = TextEditingController();
  String? _filterService;
  String? _filterMode;
  int _maxTarif = 0;

  List<dynamic> _profiles = [];
  bool _loading = false;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  late ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200
          && !_loadingMore && _hasMore) _loadMore();
    });
    _search();
  }

  @override
  void dispose() { _scroll.dispose(); _cityCtrl.dispose(); super.dispose(); }

  Map<String, dynamic> _params(int page) {
    final p = <String, dynamic>{'page': page, 'limit': 10};
    if (_cityCtrl.text.isNotEmpty) p['city'] = _cityCtrl.text.trim();
    if (_filterService != null)    p['service'] = _filterService;
    if (_filterMode != null)       p['mode'] = _filterMode;
    if (_maxTarif > 0)             p['maxTarifJour'] = _maxTarif;
    return p;
  }

  Future<void> _search() async {
    setState(() { _loading = true; _profiles = []; _page = 1; _hasMore = true; });
    try {
      final res = await ref.read(apiClientProvider).get('/menagere/profiles', params: _params(1), forceRefresh: true);
      final raw = res.data;
      final items = raw is Map ? (raw['data'] as List? ?? []) : (raw is List ? raw : []);
      final total = raw is Map ? (raw['total'] as int? ?? items.length) : items.length;
      setState(() { _profiles = items; _hasMore = items.length < total; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ref.read(apiClientProvider).get('/menagere/profiles', params: _params(_page + 1));
      final raw = res.data;
      final items = raw is Map ? (raw['data'] as List? ?? []) : (raw is List ? raw : []);
      final total = raw is Map ? (raw['total'] as int? ?? 0) : 0;
      setState(() {
        _profiles.addAll(items);
        _page++;
        _hasMore = _profiles.length < total;
        _loadingMore = false;
      });
    } catch (_) { setState(() => _loadingMore = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Filtres ────────────────────────────────────────────────────────
      Container(
        color: _pink.withOpacity(0.06),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(children: [
          // Ville
          TextField(
            controller: _cityCtrl,
            decoration: InputDecoration(
              hintText: 'Ville (Yaoundé, Douala…)',
              prefixIcon: const Icon(Icons.location_on_outlined, color: _pink),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: _pink),
                onPressed: _search,
              ),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          // Filtres services
          SizedBox(height: 34, child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(label: AppTranslations.of(context).t('all_services'), selected: _filterService == null,
                onTap: () { setState(() => _filterService = null); _search(); }),
              ..._servicesMeta.entries.map((e) => _FilterChip(
                label: '${e.value['emoji']} ${AppTranslations.of(context).t(e.value['labelKey'] as String)}',
                selected: _filterService == e.key,
                color: Color(e.value['color'] as int),
                onTap: () { setState(() => _filterService = e.key); _search(); },
              )),
            ],
          )),
          const SizedBox(height: 6),
          // Filtres modes
          SizedBox(height: 34, child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(label: AppTranslations.of(context).t('all_modes'), selected: _filterMode == null,
                onTap: () { setState(() => _filterMode = null); _search(); }),
              ..._modesMeta.entries.map((e) => _FilterChip(
                label: '${e.value['emoji']} ${AppTranslations.of(context).t(e.value['labelKey'] as String)}',
                selected: _filterMode == e.key,
                color: _pink,
                onTap: () { setState(() => _filterMode = e.key); _search(); },
              )),
            ],
          )),
        ]),
      ),

      // ── Résultats ──────────────────────────────────────────────────────
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: _pink))
        : _profiles.isEmpty
          ? _EmptyState(onRetry: _search)
          : RefreshIndicator(
              color: _pink,
              onRefresh: _search,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: _profiles.length + (_loadingMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _profiles.length) return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: _pink, strokeWidth: 2)),
                  );
                  return _ProfileCard(
                    profile: Map<String, dynamic>.from(_profiles[i]),
                    onTap: () => context.push('/menagere/profiles/${_profiles[i]['id']}'),
                  );
                },
              ),
            ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET MES CONTRATS
// ═════════════════════════════════════════════════════════════════════════════
class _ContractsTab extends ConsumerStatefulWidget {
  const _ContractsTab();
  @override
  ConsumerState<_ContractsTab> createState() => _ContractsTabState();
}

class _ContractsTabState extends ConsumerState<_ContractsTab> {
  List<dynamic> _contracts = [];
  bool _loading = true;
  String _role = 'client'; // client ou worker

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider)
          .get('/menagere/contracts', params: {'role': _role}, forceRefresh: true);
      final raw = res.data;
      setState(() {
        _contracts = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) : []);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Toggle client / travailleuse
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(child: _RoleBtn(label: 'En tant que client', selected: _role == 'client',
            onTap: () { setState(() => _role = 'client'); _load(); })),
          const SizedBox(width: 10),
          Expanded(child: _RoleBtn(label: 'En tant que ménagère', selected: _role == 'worker',
            onTap: () { setState(() => _role = 'worker'); _load(); })),
        ]),
      ),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: _pink))
        : _contracts.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('Aucun contrat', style: TextStyle(color: Colors.grey.shade400)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: _pink),
                child: const Text('Trouver une ménagère', style: TextStyle(color: Colors.white)),
              ),
            ]))
          : RefreshIndicator(
              color: _pink,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: _contracts.length,
                itemBuilder: (_, i) => _ContractCard(
                  contract: Map<String, dynamic>.from(_contracts[i]),
                  role: _role,
                  onTap: () => context.push('/menagere/contracts/${_contracts[i]['id']}'),
                ),
              ),
            ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET MON PROFIL (TRAVAILLEUSE)
// ═════════════════════════════════════════════════════════════════════════════
class _WorkerTab extends ConsumerStatefulWidget {
  const _WorkerTab();
  @override
  ConsumerState<_WorkerTab> createState() => _WorkerTabState();
}

class _WorkerTabState extends ConsumerState<_WorkerTab> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/menagere/profiles/me', forceRefresh: true);
      setState(() { _profile = res.data is Map ? Map<String, dynamic>.from(res.data) : null; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _pink));

    if (_profile == null) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.badge_outlined, size: 64, color: _pink),
        const SizedBox(height: 16),
        const Text('Vous n\'avez pas encore de profil ménagère',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Publiez votre profil pour trouver des clients',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => context.push('/menagere/publish'),
          icon: const Icon(Icons.add),
          label: const Text('Créer mon profil'),
          style: ElevatedButton.styleFrom(backgroundColor: _pink, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        ),
      ],
    ));

    final p = _profile!;
    final services = (p['services'] as String? ?? '').split(',').where((s) => s.isNotEmpty).toList();
    final avgRating = (p['avgRating'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header profil
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            CircleAvatar(radius: 36,
              backgroundImage: p['photoUrl'] != null ? NetworkImage(p['photoUrl']) : null,
              backgroundColor: _pink.withOpacity(0.1),
              child: p['photoUrl'] == null ? const Icon(Icons.person, size: 36, color: _pink) : null),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['fullName'] ?? 'Mon profil',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text(p['city'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                const SizedBox(width: 3),
                Text(avgRating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(' · ${p['totalReviews'] ?? 0} avis',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p['isVerified'] == true ? const Color(0xFF16A34A).withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(p['isVerified'] == true ? '✅ Vérifié' : '⏳ En attente vérif.',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: p['isVerified'] == true ? const Color(0xFF16A34A) : Colors.orange.shade700))),
              ]),
            ])),
          ]),
        ),
        const SizedBox(height: 12),

        // Disponibilité
        _SectionCard(title: 'Disponibilité', child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(p['isAvailable'] == true ? '🟢 Disponible' : '🔴 Non disponible',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Switch(
              value: p['isAvailable'] == true,
              activeColor: _pink,
              onChanged: (_) async {
                await ref.read(apiClientProvider).patch('/menagere/profiles/availability', data: {});
                _load();
              },
            ),
          ],
        )),
        const SizedBox(height: 10),

        // Services
        _SectionCard(title: 'Services proposés', child: Wrap(spacing: 8, runSpacing: 8,
          children: services.map((s) {
            final meta = _servicesMeta[s] ?? {'emoji': '📦', 'label': s, 'color': 0xFF607D8B};
            return Chip(
              label: Text('${meta['emoji']} ${meta['label']}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              backgroundColor: Color(meta['color'] as int).withOpacity(0.1),
              side: BorderSide(color: Color(meta['color'] as int).withOpacity(0.3)),
              padding: EdgeInsets.zero,
            );
          }).toList()
        )),
        const SizedBox(height: 10),

        // Tarifs
        _SectionCard(title: 'Tarifs', child: Row(children: [
          _TarifBadge(label: 'Par jour',
            value: '${_fmt(p['tarifJour'])} FCFA'),
          const SizedBox(width: 12),
          _TarifBadge(label: 'Par mois',
            value: '${_fmt(p['tarifMois'])} FCFA'),
        ])),
        const SizedBox(height: 10),

        // Stats
        _SectionCard(title: 'Statistiques', child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(icon: Icons.assignment_turned_in_outlined, label: 'Contrats',
              value: '${p['totalContracts'] ?? 0}'),
            _StatItem(icon: Icons.star_outline_rounded, label: 'Note',
              value: avgRating.toStringAsFixed(1)),
            _StatItem(icon: Icons.rate_review_outlined, label: 'Avis',
              value: '${p['totalReviews'] ?? 0}'),
          ],
        )),
        const SizedBox(height: 16),

        // Bouton modifier
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () => context.push('/menagere/publish').then((_) => _load()),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Modifier mon profil'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _pink, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () => context.push('/menagere/worker-dashboard'),
          icon: const Icon(Icons.dashboard_outlined, color: _pink),
          label: const Text('Tableau de bord', style: TextStyle(color: _pink)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _pink),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS RÉUTILISABLES
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onTap;
  const _ProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final services = (profile['services'] as String? ?? '').split(',').where((s) => s.isNotEmpty).toList();
    final avgRating = (profile['avgRating'] as num?)?.toDouble() ?? 0.0;
    final photo = profile['photoUrl'] as String?;
    final isVerified = profile['isVerified'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo + badge
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: photo != null
                ? CachedNetworkImage(imageUrl: photo, height: 140, width: double.infinity, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(height: 140, color: Colors.grey.shade100),
                    errorWidget: (_, __, ___) => _PhotoPlaceholder())
                : _PhotoPlaceholder(),
            ),
            if (isVerified) Positioned(top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(8)),
                child: const Text('✅ Vérifié', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )),
          ]),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(profile['fullName'] ?? 'Ménagère',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                Text(' ${avgRating.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 2),
              Text('📍 ${profile['city'] ?? ''} ${profile['quartier'] != null ? '· ${profile['quartier']}' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 6),
              // Services chips
              Wrap(spacing: 6, runSpacing: 4,
                children: services.take(4).map((s) {
                  final meta = _servicesMeta[s] ?? {'emoji': '📦', 'label': s, 'color': 0xFF607D8B};
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(meta['color'] as int).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${meta['emoji']} ${meta['label']}',
                      style: TextStyle(fontSize: 10, color: Color(meta['color'] as int), fontWeight: FontWeight.w600)),
                  );
                }).toList()),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_fmt(profile['tarifJour'])} FCFA/j',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _pink)),
                  Text('${_fmt(profile['tarifMois'])} FCFA/mois',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ])),
                Text('${profile['experienceYears'] ?? 0} ans exp.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: _pink, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Voir', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Map<String, dynamic> contract;
  final String role;
  final VoidCallback onTap;
  const _ContractCard({required this.contract, required this.role, required this.onTap});

  static const _statusColors = {
    'pending':   Color(0xFFF59E0B),
    'active':    Color(0xFF16A34A),
    'paused':    Color(0xFF6366F1),
    'completed': Color(0xFF64748B),
    'cancelled': Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    final status   = contract['status'] as String? ?? 'pending';
    final color    = _statusColors[status] ?? Colors.grey;
    final profile  = contract['profile'] is Map ? Map<String, dynamic>.from(contract['profile']) : null;
    final services = (contract['services'] as String? ?? '').split(',').where((s) => s.isNotEmpty).toList();
    final name = role == 'client'
        ? (profile?['fullName'] ?? contract['workerName'] ?? 'Ménagère')
        : (contract['clientName'] ?? 'Client');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // Header statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
            ),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(status.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              const Spacer(),
              Text(contract['mode'] as String? ?? '',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _pink.withOpacity(0.1),
                backgroundImage: profile?['photoUrl'] != null ? NetworkImage(profile!['photoUrl']) : null,
                child: profile?['photoUrl'] == null ? const Icon(Icons.person, color: _pink) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(contract['address'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 4),
                Wrap(spacing: 4, runSpacing: 4,
                  children: services.take(3).map((s) {
                    final meta = _servicesMeta[s] ?? {'emoji': '📦', 'label': s, 'color': 0xFF607D8B};
                    return Text('${meta['emoji']}', style: const TextStyle(fontSize: 16));
                  }).toList()),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${_fmt(contract['salaireMensuel'])} F/mois',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _pink)),
                const SizedBox(height: 4),
                Text(contract['startDate'] ?? '',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, this.color = _pink, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : Colors.grey.shade300),
      ),
      child: Text(label, style: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
    ),
  );
}

class _RoleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RoleBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? _pink : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? _pink : Colors.grey.shade300),
      ),
      child: Text(label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.grey.shade700)),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _pink)),
      const SizedBox(height: 10),
      child,
    ]),
  );
}

class _TarifBadge extends StatelessWidget {
  final String label, value;
  const _TarifBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: _pink.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _pink)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]),
  ));
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, size: 22, color: _pink),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
  ]);
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('Aucune ménagère trouvée', style: TextStyle(color: Colors.grey.shade400)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: _pink),
        child: const Text('Réessayer', style: TextStyle(color: Colors.white))),
    ],
  ));
}

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 140, color: _pink.withOpacity(0.08),
    child: const Center(child: Icon(Icons.person_outline, size: 60, color: _pink)),
  );
}

String _fmt(dynamic v) {
  final n = num.tryParse(v?.toString() ?? '') ?? 0;
  return n.toInt().toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}
