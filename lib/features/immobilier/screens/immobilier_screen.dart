import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/i18n/app_translations.dart';

// ═════════════════════════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL IMMOBILIER
// ═════════════════════════════════════════════════════════════════════════════
class ImmobilierScreen extends ConsumerStatefulWidget {
  const ImmobilierScreen({super.key});
  @override
  ConsumerState<ImmobilierScreen> createState() => _ImmobilierScreenState();
}

class _ImmobilierScreenState extends ConsumerState<ImmobilierScreen> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _featured   = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final isOnline = ref.read(isOnlineProvider);
      final results = await Future.wait([
        api.get('/immobilier/categories', forceRefresh: isOnline),
        api.get('/immobilier/featured',   forceRefresh: isOnline),
      ]);
      setState(() {
        _categories = (results[0].data is List)
            ? (results[0].data as List).map((c) => Map<String, dynamic>.from(c)).toList()
            : [];
        _featured = (results[1].data is List)
            ? (results[1].data as List).map((p) => Map<String, dynamic>.from(p)).toList()
            : [];
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(AppTranslations.of(context).t('real_estate')),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/immobilier/search'),
          ),
        ],
      ),
      body: _loading
          ? _LoadingBody()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Catégories depuis la BD ───────────────────────────
                  Text(AppTranslations.of(context).t('what_looking_for'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  _CategoriesGrid(categories: _categories),
                  const SizedBox(height: 28),

                  // ── Annonces en vedette ───────────────────────────────
                  if (_featured.isNotEmpty) ...[
                    Row(children: [
                      Text(AppTranslations.of(context).t('featured'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.push('/immobilier/search'),
                        child: Text(AppTranslations.of(context).t('see_all')),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    ..._featured.map((p) => _PropertyCard(
                      property: p,
                      onTap: () => context.push('/immobilier/${p['id']}'),
                    )),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/immobilier/publish'),
        backgroundColor: const Color(0xFF1B5E20),
        icon: const Icon(Icons.add_home_outlined),
        label: Text(AppTranslations.of(context).t('publish_property')),
      ),
    );
  }
}

// ── Grille catégories ─────────────────────────────────────────────────────────
class _CategoriesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  const _CategoriesGrid({required this.categories});

  Color _parseColor(String? hex, Color fallback) {
    if (hex == null) return fallback;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return fallback; }
  }

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      // Fallback statique si API indisponible
      return _StaticCategoriesGrid();
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.65,
      ),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final cat = categories[i];
        final color = _parseColor(cat['bgColor'] as String?, const Color(0xFF1B5E20));
        final imageUrl = cat['imageUrl'] as String?;

        return GestureDetector(
          onTap: () => context.push('/immobilier/search?categorySlug=${cat['slug']}'),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: color,
              boxShadow: [BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(children: [
                // Image de fond
                if (imageUrl != null)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: color),
                      errorWidget: (_, __, ___) => Container(color: color),
                      memCacheHeight: 200, maxHeightDiskCache: 200,
                      color: Colors.black26,
                      colorBlendMode: BlendMode.darken,
                    ),
                  ),
                // Gradient bas
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                      ),
                    ),
                  ),
                ),
                // Texte
                Positioned(
                  bottom: 12, left: 14, right: 14,
                  child: Row(children: [
                    Text(cat['emoji'] ?? '🏠',
                      style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(cat['label'] ?? '',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black38, blurRadius: 4)]),
                        maxLines: 2),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ── Fallback statique ─────────────────────────────────────────────────────────
class _StaticCategoriesGrid extends StatelessWidget {
  static const _cats = [
    {'slug': 'location',         'label': 'Location',        'emoji': '🏠', 'color': 0xFF1565C0},
    {'slug': 'vente',            'label': 'Vente',           'emoji': '🏗️', 'color': 0xFF2E7D32},
    {'slug': 'bureau',           'label': 'Bureau',          'emoji': '🏢', 'color': 0xFF6A1B9A},
    {'slug': 'colocation',       'label': 'Colocation',      'emoji': '🛏️', 'color': 0xFFE65100},
    {'slug': 'meuble_journalier','label': 'Meublé / jour',   'emoji': '🛋️', 'color': 0xFF00695C},
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.65),
      itemCount: _cats.length,
      itemBuilder: (_, i) {
        final cat = _cats[i];
        final color = Color(cat['color'] as int);
        return GestureDetector(
          onTap: () => context.push('/immobilier/search?categorySlug=${cat['slug']}'),
          child: Container(
            decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat['emoji'] as String, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(cat['label'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ── Carte annonce ─────────────────────────────────────────────────────────────
class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final VoidCallback onTap;
  const _PropertyCard({required this.property, required this.onTap});

  static const _periodLabels = {
    'jour': '/jour', 'mois': '/mois', 'an': '/an', 'total': '',
  };

  static const _slugLabels = {
    'location': 'Location', 'vente': 'Vente', 'bureau': 'Bureau',
    'colocation': 'Colocation', 'meuble_journalier': 'Meublé/j',
  };

  static const _slugColors = {
    'location':         Color(0xFF1565C0),
    'vente':            Color(0xFF2E7D32),
    'bureau':           Color(0xFF6A1B9A),
    'colocation':       Color(0xFFE65100),
    'meuble_journalier':Color(0xFF00695C),
  };

  String _fmt(dynamic v) {
    final n = int.tryParse(v?.toString() ?? '') ?? 0;
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final photo    = property['photoPrincipale'] as String?;
    final slug     = property['categorySlug']   as String? ?? '';
    final label    = _slugLabels[slug] ?? slug;
    final color    = _slugColors[slug] ?? const Color(0xFF1B5E20);
    final prix     = _fmt(property['prix']);
    final periode  = _periodLabels[property['prixPeriode'] ?? 'mois'] ?? '/mois';
    final ville    = property['ville']    as String? ?? '';
    final quartier = property['quartier'] as String? ?? '';
    final surface  = property['surface'];
    final pieces   = property['pieces'];
    final verified = property['verified'] == true;
    final featured = property['featured'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(children: [
              photo != null
                ? CachedNetworkImage(
                    imageUrl: photo, height: 180, width: double.infinity, fit: BoxFit.cover,
                    placeholder: (_, __) => _ImmoShimmer(),
                    errorWidget: (_, __, ___) => _ImmoPlaceholder(),
                    memCacheHeight: 360, maxHeightDiskCache: 360,
                  )
                : _ImmoPlaceholder(),
              // Badge catégorie
              Positioned(top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(10)),
                  child: Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                )),
              // Badge vérifié
              if (verified)
                Positioned(top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600, borderRadius: BorderRadius.circular(10)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 3),
                      Text('Vérifié', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                  )),
              // Badge vedette
              if (featured)
                Positioned(bottom: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700, borderRadius: BorderRadius.circular(10)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 3),
                      Text('Vedette', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                  )),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Titre
              Text(property['title'] ?? '',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),

              // Localisation
              Row(children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('$quartier${quartier.isNotEmpty && ville.isNotEmpty ? ' · ' : ''}$ville',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 10),

              // Caractéristiques
              Row(children: [
                if (surface != null) ...[
                  _FeatureChip(Icons.straighten_rounded, '$surface m²'),
                  const SizedBox(width: 8),
                ],
                if (pieces != null) ...[
                  _FeatureChip(Icons.meeting_room_outlined, '$pieces pièces'),
                  const SizedBox(width: 8),
                ],
              ]),
              const SizedBox(height: 10),

              // Prix
              Row(children: [
                Expanded(
                  child: RichText(text: TextSpan(children: [
                    TextSpan(text: '$prix FCFA',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                    TextSpan(text: periode,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ])),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Voir',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.grey.shade600),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
    ]),
  );
}

class _ImmoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 180, color: Colors.grey.shade200,
    child: Center(child: Icon(Icons.home_outlined, size: 60, color: Colors.grey.shade400)));
}

class _ImmoShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
    child: Container(height: 180, color: Colors.white));
}

// ── Écran de recherche / liste filtrée ────────────────────────────────────────
class ImmobilierSearchScreen extends ConsumerStatefulWidget {
  final String? initialCategorySlug;
  const ImmobilierSearchScreen({super.key, this.initialCategorySlug});
  @override
  ConsumerState<ImmobilierSearchScreen> createState() => _ImmobilierSearchState();
}

class _ImmobilierSearchState extends ConsumerState<ImmobilierSearchScreen> {
  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _categories = [];
  List<String> _villes = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const _limit = 15;
  late final ScrollController _scrollCtrl;

  String? _selectedSlug;
  String? _selectedVille;
  int? _prixMax;
  int? _surfaceMin;

  @override
  void initState() {
    super.initState();
    _selectedSlug = widget.initialCategorySlug;
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _load();
  }

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200
        && !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  Map<String, String> _buildParams() {
    final params = <String, String>{'limit': '$_limit'};
    if (_selectedSlug != null) params['categorySlug'] = _selectedSlug!;
    if (_selectedVille != null) params['ville'] = _selectedVille!;
    if (_prixMax != null) params['prixMax'] = '$_prixMax';
    if (_surfaceMin != null) params['surface'] = '$_surfaceMin';
    return params;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _page = 1; _hasMore = true; _properties = []; });
    try {
      final api = ref.read(apiClientProvider);
      final isOnline = ref.read(isOnlineProvider);
      final params = _buildParams()..['page'] = '1';

      final results = await Future.wait([
        api.get('/immobilier', params: params, forceRefresh: isOnline),
        api.get('/immobilier/categories', forceRefresh: false),
        api.get('/immobilier/villes', forceRefresh: false),
      ]);

      final raw = results[0].data;
      final items = raw is Map ? (raw['data'] as List? ?? []) : (raw is List ? raw : []);
      final pages = raw is Map ? (raw['pages'] as int? ?? 1) : 1;

      setState(() {
        _properties = items.map((p) => Map<String, dynamic>.from(p)).toList();
        _categories = (results[1].data is List)
            ? (results[1].data as List).map((c) => Map<String, dynamic>.from(c)).toList()
            : [];
        _villes = (results[2].data is List)
            ? (results[2].data as List).map((v) => v.toString()).toList()
            : [];
        _hasMore = _page < pages;
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final api = ref.read(apiClientProvider);
      final params = _buildParams()..['page'] = '${_page + 1}';
      final res = await api.get('/immobilier', params: params, forceRefresh: true);
      final raw = res.data;
      final items = raw is Map ? (raw['data'] as List? ?? []) : [];
      final pages = raw is Map ? (raw['pages'] as int? ?? 1) : 1;
      setState(() {
        _page++;
        _properties.addAll(items.map((p) => Map<String, dynamic>.from(p)));
        _hasMore = _page < pages;
        _loadingMore = false;
      });
    } catch (_) { setState(() => _loadingMore = false); }
  }

  @override
  Widget build(BuildContext context) {
    // Label catégorie sélectionnée
    String appBarTitle = 'Annonces';
    if (_selectedSlug != null && _categories.isNotEmpty) {
      final cat = _categories.firstWhere(
        (c) => c['slug'] == _selectedSlug, orElse: () => {});
      if (cat.isNotEmpty) appBarTitle = cat['label'] as String? ?? appBarTitle;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(children: [
        // ── Filtres ───────────────────────────────────────────────────────
        Container(
          color: const Color(0xFF1B5E20),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(children: [
            // Catégories
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final slug = i == 0 ? null : _categories[i-1]['slug'] as String?;
                  final label = i == 0 ? 'Tous' : (_categories[i-1]['label'] as String? ?? '');
                  final emoji = i == 0 ? '🗂️' : (_categories[i-1]['emoji'] as String? ?? '');
                  final sel = _selectedSlug == slug;
                  return GestureDetector(
                    onTap: () { setState(() => _selectedSlug = slug); _load(); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? Colors.white : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? Colors.white : Colors.white.withOpacity(0.3))),
                      child: Text('$emoji $label',
                        style: TextStyle(
                          color: sel ? const Color(0xFF1B5E20) : Colors.white,
                          fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Ville + prix
            Row(children: [
              Expanded(child: _VilleDropdown(
                villes: _villes,
                selected: _selectedVille,
                onChanged: (v) { setState(() => _selectedVille = v); _load(); },
              )),
              const SizedBox(width: 8),
              Expanded(child: _PrixFilter(
                value: _prixMax,
                onChanged: (v) { setState(() => _prixMax = v); _load(); },
              )),
            ]),
            const SizedBox(height: 8),
            _SurfaceFilter(
              value: _surfaceMin,
              onChanged: (v) { setState(() => _surfaceMin = v); _load(); },
            ),
          ]),
        ),

        // ── Liste annonces ────────────────────────────────────────────────
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _properties.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('Aucune annonce', style: TextStyle(color: Colors.grey.shade400)),
              ]))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _properties.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _properties.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                    }
                    return _PropertyCard(
                      property: _properties[i],
                      onTap: () => context.push('/immobilier/${_properties[i]['id']}'),
                    );
                  },
                ),
              ),
        ),
      ]),
    );
  }
}

class _VilleDropdown extends StatelessWidget {
  final List<String> villes;
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _VilleDropdown({required this.villes, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(0.3))),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: selected,
        hint: const Text('Ville', style: TextStyle(color: Colors.white70, fontSize: 12)),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
        dropdownColor: const Color(0xFF1B5E20),
        items: [
          const DropdownMenuItem<String?>(value: null,
            child: Text('Toutes les villes', style: TextStyle(color: Colors.white, fontSize: 12))),
          ...villes.map((v) => DropdownMenuItem<String?>(value: v,
            child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 12)))),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

class _PrixFilter extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _PrixFilter({required this.value, required this.onChanged});

  static const _options = [
    {'label': 'Tout prix', 'value': null},
    {'label': '< 100k',   'value': 100000},
    {'label': '< 300k',   'value': 300000},
    {'label': '< 1M',     'value': 1000000},
    {'label': '< 5M',     'value': 5000000},
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(0.3))),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: value,
        hint: const Text('Prix max', style: TextStyle(color: Colors.white70, fontSize: 12)),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
        dropdownColor: const Color(0xFF1B5E20),
        items: _options.map((o) => DropdownMenuItem<int?>(
          value: o['value'] as int?,
          child: Text(o['label'] as String,
            style: const TextStyle(color: Colors.white, fontSize: 12)))).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

// ── Filtre surface minimum ────────────────────────────────────────────────────
class _SurfaceFilter extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _SurfaceFilter({required this.value, required this.onChanged});

  static const _options = [
    {'label': 'Toute surface', 'value': null},
    {'label': '> 20 m²',  'value': 20},
    {'label': '> 50 m²',  'value': 50},
    {'label': '> 100 m²', 'value': 100},
    {'label': '> 200 m²', 'value': 200},
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: _options.map((o) {
      final sel = value == (o['value'] as int?);
      return GestureDetector(
        onTap: () => onChanged(o['value'] as int?),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? Colors.white : Colors.white.withOpacity(0.3))),
          child: Text(o['label'] as String,
            style: TextStyle(
              fontSize: 11,
              color: sel ? const Color(0xFF1B5E20) : Colors.white,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ),
      );
    }).toList()),
  );
}

// ── Loading body ──────────────────────────────────────────────────────────────
class _LoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      Container(height: 20, width: 180, color: Colors.white, margin: const EdgeInsets.only(bottom: 14)),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.65,
        children: List.generate(4, (_) => Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)))),
      ),
      const SizedBox(height: 28),
      ...List.generate(2, (_) => Container(
        height: 280, margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
    ]),
  );
}
