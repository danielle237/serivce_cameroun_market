import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/i18n/app_translations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ÉCRAN PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class RentalScreen extends ConsumerStatefulWidget {
  const RentalScreen({super.key});
  @override
  ConsumerState<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends ConsumerState<RentalScreen> {
  int _selected = 0; // 0 = Voitures, 1 = Événements

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(AppTranslations.of(context).t('rental')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(children: [
        // ── Sélecteur côte à côte ─────────────────────────────────────────
        Container(
          color: const Color(0xFF1A237E),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            Expanded(child: _CategoryBtn(
              icon: Icons.directions_car_rounded,
              label: AppTranslations.of(context).t('cars'),
              sublabel: AppTranslations.of(context).t('with_without_driver'),
              selected: _selected == 0,
              onTap: () => setState(() => _selected = 0),
            )),
            const SizedBox(width: 12),
            Expanded(child: _CategoryBtn(
              icon: Icons.chair_alt_rounded,
              label: AppTranslations.of(context).t('equipment'),
              sublabel: AppTranslations.of(context).t('chairs_tents_sound'),
              selected: _selected == 1,
              onTap: () => setState(() => _selected = 1),
            )),
          ]),
        ),
        // ── Contenu ───────────────────────────────────────────────────────
        Expanded(child: _selected == 0 ? const _CarsTab() : const _EventTab()),
      ]),
    );
  }
}

// ── Bouton catégorie ──────────────────────────────────────────────────────────
class _CategoryBtn extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryBtn({
    required this.icon, required this.label, required this.sublabel,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon, size: 22,
            color: selected ? const Color(0xFF1A237E) : Colors.white70),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: selected ? const Color(0xFF1A237E) : Colors.white)),
            Text(sublabel, style: TextStyle(
              fontSize: 10,
              color: selected ? Colors.grey.shade500 : Colors.white60),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET VOITURES
// ═════════════════════════════════════════════════════════════════════════════
class _CarsTab extends ConsumerStatefulWidget {
  const _CarsTab();
  @override
  ConsumerState<_CarsTab> createState() => _CarsTabState();
}

class _CarsTabState extends ConsumerState<_CarsTab> {
  List<dynamic> _cars = [];
  List<dynamic> _myBookings = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _fromCache = false;
  String? _error;
  String _filterType = 'tous';
  int _page = 1;
  static const int _limit = 10;
  late ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
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

  Map<String, dynamic> _carsParams(int page) {
    final p = <String, dynamic>{'page': page, 'limit': _limit};
    if (_filterType != 'tous') p['type'] = _filterType;
    return p;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _page = 1; _cars = []; _hasMore = true; });
    try {
      final api = ref.read(apiClientProvider);
      final isOnline = ref.read(isOnlineProvider);
      final results = await Future.wait([
        api.get('/rental/cars', params: _carsParams(1), forceRefresh: isOnline),
        api.get('/rental/bookings/mine', forceRefresh: isOnline),
      ]);
      final raw = results[0].data;
      final List<dynamic> items = raw is Map ? (raw['data'] as List? ?? []) : (raw is List ? raw : []);
      final int total = raw is Map ? (raw['total'] as int? ?? items.length) : items.length;
      final allBookings = results[1].data is List ? results[1].data as List : [];
      setState(() {
        _cars = items;
        _myBookings = allBookings.where((b) => b['bookingType'] == 'car').toList();
        _fromCache = results[0].extra?['fromCache'] == true || !isOnline;
        _hasMore = _cars.length < total;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = ref.read(isOnlineProvider)
            ? e.toString()
            : 'Hors-ligne · Aucune donnée en cache.\nConnectez-vous pour voir les voitures disponibles.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() { _loadingMore = true; });
    try {
      final api = ref.read(apiClientProvider);
      final nextPage = _page + 1;
      final res = await api.get('/rental/cars', params: _carsParams(nextPage));
      final raw = res.data;
      final List<dynamic> items = raw is Map ? (raw['data'] as List? ?? []) : (raw is List ? raw : []);
      final int total = raw is Map ? (raw['total'] as int? ?? 0) : 0;
      setState(() {
        _cars.addAll(items);
        _page = nextPage;
        _hasMore = _cars.length < total;
        _loadingMore = false;
      });
    } catch (_) { setState(() => _loadingMore = false); }
  }

  void _onFilterChange(String type) {
    setState(() => _filterType = type);
    _load();
  }

  // Types connus statiques pour les chips de filtre
  static const _knownTypes = ['tous', 'berline', 'suv', 'minibus', 'pickup', 'utilitaire'];
  static const _typeLabels = {
    'tous': 'Tous', 'berline': 'Berline', 'suv': 'SUV',
    'minibus': 'Minibus', 'pickup': 'Pickup', 'utilitaire': 'Utilitaire',
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorWidget(onRetry: _load);

    return Column(children: [
      if (_fromCache) const _OfflineBanner(),
      Expanded(child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          // Filtres
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _knownTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _knownTypes[i];
                final sel = _filterType == t;
                return GestureDetector(
                  onTap: () => _onFilterChange(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF1A237E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? const Color(0xFF1A237E) : Colors.grey.shade300),
                      boxShadow: sel ? [BoxShadow(
                        color: const Color(0xFF1A237E).withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 2))] : [],
                    ),
                    child: Text(_typeLabels[t] ?? t,
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.black87,
                        fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Mes réservations voitures ─────────────────────────────────
          if (_myBookings.isNotEmpty) ...[
            _BookingsHeader(count: _myBookings.length),
            ..._myBookings.map((b) => _BookingCard(
              booking: Map<String, dynamic>.from(b),
              onRefresh: _load,
            )),
            const Divider(height: 32),
            const Text('🚗 Voitures disponibles',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
          ],

          if (_cars.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Aucune voiture disponible', style: TextStyle(color: Colors.grey)),
            ))
          else ...[
            ...(_cars.map((car) => _CarCard(
              car: Map<String, dynamic>.from(car),
              onBookWithDriver: (wantDriver) => _showBookingSheet(context,
                car: {...Map<String, dynamic>.from(car), 'wantDriver': wantDriver}),
            ))),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (!_hasMore && _cars.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('${_cars.length} voiture${_cars.length > 1 ? 's' : ''} au total',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400))),
              ),
          ],
        ],
      ),
    ))]);
  }

  void _showBookingSheet(BuildContext ctx, {Map<String, dynamic>? car, Map<String, dynamic>? pack, List<Map<String, dynamic>>? items}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(
        car: car, pack: pack, items: items,
        onBooked: _load,
      ),
    );
  }
}

// ── Carte voiture ─────────────────────────────────────────────────────────────
class _CarCard extends StatefulWidget {
  final Map<String, dynamic> car;
  final void Function(bool wantDriver) onBookWithDriver;
  const _CarCard({required this.car, required this.onBookWithDriver});
  @override
  State<_CarCard> createState() => _CarCardState();
}

class _CarCardState extends State<_CarCard> {
  bool _wantDriver = true;

  String _typeLabel(String t) => {'berline': 'Berline', 'suv': 'SUV',
    'minibus': 'Minibus', 'pickup': 'Pickup', 'utilitaire': 'Utilitaire'}[t] ?? t;

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final photoUrl = car['photoUrl'] as String?;
    final priceWithDriver    = num.tryParse(car['pricePerDay']?.toString() ?? '') ?? 0;
    final priceWithoutDriver = num.tryParse(car['priceWithoutDriverPerDay']?.toString() ?? '') ?? priceWithDriver;
    final pricePerDay = _wantDriver ? priceWithDriver : priceWithoutDriver;
    final driverName = car['driverName'] as String?;
    final driverPhotoUrl = car['driverPhotoUrl'] as String?;
    final driverRating = num.tryParse(car['driverRating']?.toString() ?? '') ?? 0;
    final driverTrips = car['driverTrips'] ?? 0;
    final hasDriver = car['withDriver'] == true && driverName != null;

    // Disponibilité
    final isAvailable = car['isAvailable'] != false; // true par défaut si champ absent
    final unavailableUntil = car['unavailableUntil'] as String?;
    final unavailableReason = car['unavailableReason'] as String?; // 'active' | 'confirmed'

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: isAvailable ? null : Border.all(color: Colors.red.shade200),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isAvailable ? 0.08 : 0.04),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Photo voiture
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Stack(children: [
            // Overlay gris si indisponible
            if (!isAvailable)
              Container(
                height: 180, width: double.infinity,
                color: Colors.transparent,
                child: Stack(children: [
                  photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        height: 180, width: double.infinity, fit: BoxFit.cover,
                        placeholder: (_, __) => _ShimmerBox(height: 180),
                        errorWidget: (_, __, ___) => _CarPlaceholder(),
                        memCacheHeight: 360, maxHeightDiskCache: 360,
                        color: Colors.black38, colorBlendMode: BlendMode.darken,
                      )
                    : _CarPlaceholder(),
                ]),
              )
            else
              photoUrl != null
                ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    height: 180, width: double.infinity, fit: BoxFit.cover,
                    placeholder: (_, __) => _ShimmerBox(height: 180),
                    errorWidget: (_, __, ___) => _CarPlaceholder(),
                    memCacheHeight: 360,
                    maxHeightDiskCache: 360,
                  )
                : _CarPlaceholder(),
            // Badge type
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12)),
                child: Text(_typeLabel(car['type'] ?? ''),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            // Prix ou badge INDISPONIBLE
            Positioned(
              top: 12, right: 12,
              child: isAvailable
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E),
                      borderRadius: BorderRadius.circular(12)),
                    child: Text('${_fmt(pricePerDay)} F/j',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.car_rental, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        unavailableReason == 'active' ? '🔴 En location' : '🔒 Réservée',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
            ),
            // Bandeau retour prévu si actif
            if (!isAvailable && unavailableUntil != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  color: Colors.red.shade800.withOpacity(0.85),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.event_available_outlined, size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Retour prévu le $unavailableUntil',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            // Toggle chauffeur sur la photo
            if (hasDriver)
              Positioned(
                bottom: 12, left: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(24)),
                  child: Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _wantDriver = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: _wantDriver ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.person_rounded, size: 14,
                            color: _wantDriver ? const Color(0xFF1A237E) : Colors.white70),
                          const SizedBox(width: 4),
                          Text('Avec chauffeur', style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold,
                            color: _wantDriver ? const Color(0xFF1A237E) : Colors.white70)),
                        ]),
                      ),
                    )),
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _wantDriver = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: !_wantDriver ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.person_off_outlined, size: 14,
                            color: !_wantDriver ? const Color(0xFF1A237E) : Colors.white70),
                          const SizedBox(width: 4),
                          Text('Sans chauffeur', style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold,
                            color: !_wantDriver ? const Color(0xFF1A237E) : Colors.white70)),
                        ]),
                      ),
                    )),
                  ]),
                ),
              ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Nom + sièges
            Row(children: [
              Expanded(child: Text(car['name'] ?? '',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              Row(children: [
                const Icon(Icons.people_outline, size: 15, color: Colors.grey),
                const SizedBox(width: 3),
                Text('${car['seats']} places',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ]),
            const SizedBox(height: 4),
            Text('${car['brand'] ?? ''} ${car['year'] ?? ''} · ${car['color'] ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),

            if (car['description'] != null) ...[
              const SizedBox(height: 8),
              Text(car['description'],
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Profil chauffeur (si dispo et sélectionné)
            if (hasDriver && _wantDriver)
              Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: driverPhotoUrl != null
                    ? CachedNetworkImageProvider(driverPhotoUrl,
                        maxHeight: 88, maxWidth: 88)
                    : null,
                  backgroundColor: const Color(0xFF1A237E).withOpacity(0.1),
                  child: driverPhotoUrl == null
                    ? const Icon(Icons.person, color: Color(0xFF1A237E)) : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(driverName!,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text('${driverRating.toStringAsFixed(1)} · $driverTrips courses',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200)),
                  child: const Text('Chauffeur inclus',
                    style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ])
            else
              Row(children: [
                const Icon(Icons.person_off_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(!hasDriver ? 'Sans chauffeur (auto-conduite)' : 'Sans chauffeur sélectionné',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: isAvailable
                ? ElevatedButton.icon(
                    onPressed: () => widget.onBookWithDriver(_wantDriver),
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Réserver cette voiture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.lock_clock_outlined, size: 18, color: Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(
                        unavailableUntil != null
                          ? 'Disponible à partir du $unavailableUntil'
                          : 'Indisponible actuellement',
                        style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ),
            ),
          ]),
        ),
      ]),
    );
  }

  String _fmt(num v) {
    final s = v.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Shimmer placeholder ──────────────────────────────────────────────────────
class _ShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  const _ShimmerBox({required this.height, this.width});
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey.shade300,
    highlightColor: Colors.grey.shade100,
    child: Container(
      height: height,
      width: width ?? double.infinity,
      color: Colors.white,
    ),
  );
}

class _CarPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 180, color: Colors.grey.shade200,
    child: const Center(child: Icon(Icons.directions_car_rounded, size: 60, color: Colors.grey)),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET ÉVÉNEMENTS
// ═════════════════════════════════════════════════════════════════════════════
class _EventTab extends ConsumerStatefulWidget {
  const _EventTab();
  @override
  ConsumerState<_EventTab> createState() => _EventTabState();
}

class _EventTabState extends ConsumerState<_EventTab> {
  List<dynamic> _items = [];        // items de la page courante (catégorie filtrée)
  List<dynamic> _allLoadedItems = []; // tous les items vus (pour le panier)
  List<dynamic> _packs = [];
  List<dynamic> _myBookings = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _fromCache = false;
  String _selectedCategory = 'tous';
  int _page = 1;
  static const int _limit = 10;
  late ScrollController _scrollCtrl;
  final Map<String, int> _cart = {};

  // Métadonnées connues — fallback si catégorie non reconnue
  static const Map<String, Map<String, dynamic>> _knownCatMeta = {
    'tous':      {'label': 'Tous',      'emoji': '🗂️', 'color': 0xFF1A237E},
    'chaises':   {'label': 'Chaises',   'emoji': '🪑', 'color': 0xFF6D4C41},
    'tables':    {'label': 'Tables',    'emoji': '🪵', 'color': 0xFF795548},
    'tentes':    {'label': 'Tentes',    'emoji': '⛺', 'color': 0xFF2E7D32},
    'sono':      {'label': 'Sono',      'emoji': '🔊', 'color': 0xFF1565C0},
    'energie':   {'label': 'Énergie',   'emoji': '⚡', 'color': 0xFFF57F17},
    'cuisine':   {'label': 'Cuisine',   'emoji': '🫕', 'color': 0xFFE53935},
    'vaisselle': {'label': 'Vaisselle', 'emoji': '🍽️', 'color': 0xFF6A1B9A},
  };

  // Catégories chargées dynamiquement depuis la BD
  List<String> _categoriesFromDb = [];

  // Retourne les métadonnées d'une catégorie (connue ou générée automatiquement)
  Map<String, dynamic> _metaFor(String cat) {
    if (_knownCatMeta.containsKey(cat)) return _knownCatMeta[cat]!;
    // Catégorie inconnue → générée automatiquement
    return {
      'label': cat[0].toUpperCase() + cat.substring(1),
      'emoji': '📦',
      'color': 0xFF607D8B,
    };
  }

  @override
  void initState() {
    super.initState();
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

  Map<String, dynamic> _itemsParams(int page) {
    final p = <String, dynamic>{'page': page, 'limit': _limit};
    if (_selectedCategory != 'tous') p['category'] = _selectedCategory;
    return p;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _page = 1; _items = []; _hasMore = true; });
    final api = ref.read(apiClientProvider);
    final isOnline = ref.read(isOnlineProvider);

    // Catégories chargées indépendamment — ne bloquent pas l'affichage des items
    api.get('/rental/event-categories', forceRefresh: isOnline).then((r) {
      if (r.data is List && mounted) {
        setState(() {
          _categoriesFromDb = (r.data as List).map((c) => c.toString()).toList();
        });
      }
    }).catchError((_) {});

    try {
      final results = await Future.wait([
        api.get('/rental/event-items', params: _itemsParams(1), forceRefresh: isOnline),
        api.get('/rental/packs', forceRefresh: isOnline),
        api.get('/rental/bookings/mine', forceRefresh: isOnline),
      ]);
      final raw = results[0].data;
      final List<dynamic> items = raw is Map ? (raw['data'] as List? ?? []) : (raw is List ? raw : []);
      final int total = raw is Map ? (raw['total'] as int? ?? items.length) : items.length;
      final allBookings = results[2].data is List ? results[2].data as List : [];
      final newIds = items.map((i) => i['id']).toSet();
      _allLoadedItems.removeWhere((i) => newIds.contains(i['id']));
      _allLoadedItems.addAll(items);
      setState(() {
        _items = items;
        _packs = results[1].data is List ? results[1].data : [];
        _myBookings = allBookings.where((b) => b['bookingType'] == 'event').toList();
        _fromCache = results[0].extra?['fromCache'] == true || !isOnline;
        _hasMore = _items.length < total;
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final api = ref.read(apiClientProvider);
      final nextPage = _page + 1;
      final res = await api.get('/rental/event-items', params: _itemsParams(nextPage));
      final raw = res.data;
      final List<dynamic> items = raw is Map ? (raw['data'] as List? ?? []) : (raw is List ? raw : []);
      final int total = raw is Map ? (raw['total'] as int? ?? 0) : 0;
      // Accumuler dans _allLoadedItems
      final newIds = items.map((i) => i['id']).toSet();
      _allLoadedItems.removeWhere((i) => newIds.contains(i['id']));
      _allLoadedItems.addAll(items);
      setState(() {
        _items.addAll(items);
        _page = nextPage;
        _hasMore = _items.length < total;
        _loadingMore = false;
      });
    } catch (_) { setState(() => _loadingMore = false); }
  }

  void _onCategoryChange(String cat) {
    setState(() => _selectedCategory = cat);
    _load();
  }

  // Le panier utilise _allLoadedItems pour avoir les prix même après changement de catégorie
  int get _cartTotal {
    int total = 0;
    for (final item in _allLoadedItems) {
      final qty = _cart[item['id']] ?? 0;
      if (qty > 0) {
        final price = num.tryParse(item['pricePerUnitPerDay']?.toString() ?? '') ?? 0;
        total += (price * qty).toInt();
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Catégories dynamiques depuis la BD — avec fallback sur les items locaux
    final categories = ['tous', ...(_categoriesFromDb.isNotEmpty
        ? _categoriesFromDb
        : _items.map((i) => i['category'] as String? ?? '').where((c) => c.isNotEmpty).toSet().toList()..sort())];

    return Column(children: [
      if (_fromCache) const _OfflineBanner(),
      Expanded(child: Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          controller: _scrollCtrl,
          padding: EdgeInsets.fromLTRB(16, 16, 16, _cart.values.any((v) => v > 0) ? 100 : 16),
          children: [
            // ── Mes réservations matériel ────────────────────────────────────
            if (_myBookings.isNotEmpty) ...[
              _BookingsHeader(count: _myBookings.length),
              ..._myBookings.map((b) => _BookingCard(
                booking: Map<String, dynamic>.from(b),
                onRefresh: _load,
              )),
              const Divider(height: 32),
            ],

            // ── Section Packs ───────────────────────────────────────────────
            if (_packs.isNotEmpty) ...[
              Row(children: [
                const Text('📦 Nos Packs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${_packs.length} pack${_packs.length > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _packs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _PackCard(
                    pack: Map<String, dynamic>.from(_packs[i]),
                    onBook: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _BookingSheet(
                        pack: Map<String, dynamic>.from(_packs[i]),
                        onBooked: _load,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Catalogue ───────────────────────────────────────────────────
            const Text('🗂️ Catalogue à la carte',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            // Filtres catégories
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final meta = _metaFor(cat) ?? {'label': cat, 'emoji': '📦', 'color': 0xFF1A237E};
                  final sel = _selectedCategory == cat;
                  final color = Color(meta['color'] as int);
                  return GestureDetector(
                    onTap: () => _onCategoryChange(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? color : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? color : Colors.grey.shade300),
                      ),
                      child: Text('${meta['emoji']} ${meta['label']}',
                        style: TextStyle(
                          color: sel ? Colors.white : Colors.black87,
                          fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ── Grille 4 colonnes ────────────────────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = Map<String, dynamic>.from(_items[i]);
                final qty = _cart[item['id']] ?? 0;
                final cat = item['category'] as String? ?? '';
                final meta = _metaFor(cat) ?? {'color': 0xFF1A237E, 'emoji': '📦'};
                final color = Color(meta['color'] as int);
                final price = num.tryParse(item['pricePerUnitPerDay']?.toString() ?? '') ?? 0;
                final photoUrl = item['photoUrl'] as String?;

                return GestureDetector(
                  onTap: () => _showItemDetail(context, item, qty, color),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: qty > 0 ? Border.all(color: color, width: 2) : null,
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(children: [
                      // Image ou emoji
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: photoUrl,
                              height: 60, width: double.infinity, fit: BoxFit.cover,
                              placeholder: (_, __) => _ShimmerBox(height: 60),
                              errorWidget: (_, __, ___) => _ItemEmoji(
                                emoji: item['emoji'] ?? meta['emoji'] as String,
                                color: color),
                              memCacheHeight: 120,
                              maxHeightDiskCache: 120,
                            )
                          : _ItemEmoji(emoji: item['emoji'] ?? meta['emoji'] as String, color: color),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                        child: Column(children: [
                          Text(item['name'] ?? '',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                            maxLines: 2, textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('${price.toInt()} F/j',
                            style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      // Bouton +/-
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                        child: qty == 0
                          ? GestureDetector(
                              onTap: () => setState(() => _cart[item['id']] = 1),
                              child: Container(
                                height: 24, width: double.infinity,
                                decoration: BoxDecoration(
                                  color: color, borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.add, color: Colors.white, size: 16),
                              ),
                            )
                          : Row(children: [
                              _QtyBtn(icon: Icons.remove, color: color,
                                onTap: () => setState(() {
                                  if (((_cart[item['id']] ?? 1) - 1) <= 0) _cart.remove(item['id']);
                                  else _cart[item['id']] = (_cart[item['id']] ?? 1) - 1;
                                })),
                              Expanded(child: Text('$qty',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color))),
                              _QtyBtn(icon: Icons.add, color: color,
                                onTap: () => setState(() => _cart[item['id']] = (_cart[item['id']] ?? 0) + 1)),
                            ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
            // Indicateur chargement / fin de liste
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (!_hasMore && _items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('${_items.length} article${_items.length > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400))),
              ),
          ],
        ),
      ),

      // ── Barre panier flottante ────────────────────────────────────────────
      if (_cart.values.any((v) => v > 0))
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: GestureDetector(
            onTap: () {
              // Utilise _allLoadedItems pour inclure les items de toutes les catégories visitées
              final selectedItems = _allLoadedItems
                .where((i) => (_cart[i['id']] ?? 0) > 0)
                .map((i) => {
                  ...Map<String, dynamic>.from(i),
                  'quantity': _cart[i['id']] ?? 0,
                }).toList();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _BookingSheet(
                  items: selectedItems.cast<Map<String, dynamic>>(),
                  onBooked: () { setState(() => _cart.clear()); _load(); },
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF1976D2)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF1A237E).withOpacity(0.4),
                  blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  '${_cart.values.fold(0, (a, b) => a + b)} article(s)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                Text('${_fmt(_cartTotal)} FCFA/j',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ]),
            ),
          ),
        ),
    ]))]);
  }

  void _showItemDetail(BuildContext ctx, Map<String, dynamic> item, int currentQty, Color color) {
    final stock = (item['stockTotal'] as num?)?.toInt() ?? 999;
    final price = num.tryParse(item['pricePerUnitPerDay']?.toString() ?? '') ?? 0;
    final deposit = num.tryParse(item['depositPerUnit']?.toString() ?? '') ?? 0;
    final qtyCtrl = TextEditingController(text: currentQty > 0 ? '$currentQty' : '');
    int qty = currentQty;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Photo
              if (item['photoUrl'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: item['photoUrl'],
                    height: 140, width: double.infinity, fit: BoxFit.cover,
                    placeholder: (_, __) => _ShimmerBox(height: 140),
                    errorWidget: (_, __, ___) => const SizedBox(),
                    memCacheHeight: 280,
                    maxHeightDiskCache: 280,
                  )),
              const SizedBox(height: 14),
              // Nom + prix
              Text(item['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('${price.toInt()} FCFA / unité / jour',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Text('Caution: ${deposit.toInt()} FCFA/u',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 12),
              // Stock restant
              Row(children: [
                Icon(Icons.inventory_2_outlined, size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('Stock disponible : ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                Text('$stock unités', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: stock < 10 ? Colors.red : Colors.green)),
              ]),
              const SizedBox(height: 16),
              // Sélecteur quantité
              Row(children: [
                const Text('Quantité souhaitée :', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                // Bouton –
                _QtyBtn(icon: Icons.remove, color: color,
                  onTap: () {
                    if (qty > 0) {
                      setModal(() => qty--);
                      qtyCtrl.text = '$qty';
                    }
                  }),
                const SizedBox(width: 8),
                // Champ texte
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: qtyCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: color)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: color, width: 2)),
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v) ?? 0;
                      setModal(() => qty = n.clamp(0, stock));
                      if (n > stock) qtyCtrl.text = '$stock';
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton +
                _QtyBtn(icon: Icons.add, color: color,
                  onTap: () {
                    if (qty < stock) {
                      setModal(() => qty++);
                      qtyCtrl.text = '$qty';
                    }
                  }),
              ]),
              // Total estimé
              if (qty > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Text('$qty × ${price.toInt()} FCFA/j = ',
                      style: const TextStyle(fontSize: 13)),
                    Text('${(qty * price).toInt()} FCFA/j',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                    const Spacer(),
                    Text('+ ${(qty * deposit).toInt()} caution',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: qty == 0 ? null : () {
                  setState(() {
                    if (qty <= 0) _cart.remove(item['id']);
                    else _cart[item['id']] = qty;
                  });
                  Navigator.pop(ctx2);
                },
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: Text(qty == 0 ? 'Entrez une quantité' : 'Ajouter $qty au panier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Item emoji placeholder ────────────────────────────────────────────────────
class _ItemEmoji extends StatelessWidget {
  final String emoji;
  final Color color;
  const _ItemEmoji({required this.emoji, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    height: 60, width: double.infinity,
    color: color.withOpacity(0.08),
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
  );
}

// ── Bouton quantité ───────────────────────────────────────────────────────────
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 22, height: 22,
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Icon(icon, size: 14, color: color),
    ),
  );
}

// ── Carte pack ────────────────────────────────────────────────────────────────
class _PackCard extends StatelessWidget {
  final Map<String, dynamic> pack;
  final VoidCallback onBook;
  const _PackCard({required this.pack, required this.onBook});

  static const _eventColors = {
    'deuil': Color(0xFF546E7A),
    'mariage': Color(0xFFE91E63),
    'bapteme': Color(0xFF1565C0),
    'anniversaire': Color(0xFFF57C00),
    'conference': Color(0xFF2E7D32),
  };

  @override
  Widget build(BuildContext context) {
    final eventType = pack['eventType'] as String? ?? 'deuil';
    final color = _eventColors[eventType] ?? const Color(0xFF1A237E);
    final price = num.tryParse(pack['totalPrice']?.toString() ?? '') ?? 0;
    final photoUrl = pack['photoUrl'] as String?;

    return GestureDetector(
      onTap: onBook,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(children: [
            // Image de fond
            if (photoUrl != null)
              CachedNetworkImage(
                imageUrl: photoUrl, height: 160, width: 220, fit: BoxFit.cover,
                placeholder: (_, __) => _ShimmerBox(height: 160, width: 220),
                errorWidget: (_, __, ___) => Container(height: 160, width: 220, color: color.withOpacity(0.2)),
                memCacheHeight: 320,
                maxHeightDiskCache: 320,
              )
            else
              Container(height: 160, width: 220,
                decoration: BoxDecoration(gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
            // Overlay gradient
            Container(
              height: 160, width: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            ),
            // Contenu
            Positioned(
              bottom: 10, left: 12, right: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pack['name'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 2),
                const SizedBox(height: 4),
                Row(children: [
                  if (pack['capacity'] != null)
                    Text('${pack['capacity']} pers. · ',
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  Text('${price.toInt()} F/j',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ]),
            ),
            // Badge type
            Positioned(top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Text(eventType[0].toUpperCase() + eventType.substring(1),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHEET DE RÉSERVATION
// ═════════════════════════════════════════════════════════════════════════════
class _BookingSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? car;
  final Map<String, dynamic>? pack;
  final List<Map<String, dynamic>>? items;
  final VoidCallback onBooked;
  const _BookingSheet({this.car, this.pack, this.items, required this.onBooked});
  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _delivery = 'pickup';
  String _addressMode = 'manual'; // 'manual' | 'geo'
  final _addressCtrl = TextEditingController();
  bool _loading = false;
  bool _geoLoading = false;
  bool _withDeposit = true; // caution activée par défaut
  double? _geoLat, _geoLng;

  Future<void> _useGeolocation() async {
    setState(() => _geoLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack('Activez la localisation dans les paramètres', Colors.orange);
        setState(() => _geoLoading = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _snack('Permission de localisation refusée', Colors.red);
          setState(() => _geoLoading = false);
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

      // Reverse geocoding → nom de rue / quartier
      String adresse = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[];
          if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
          if (p.subLocality != null && p.subLocality!.isNotEmpty) parts.add(p.subLocality!);
          if (p.locality != null && p.locality!.isNotEmpty) parts.add(p.locality!);
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) parts.add(p.administrativeArea!);
          if (parts.isNotEmpty) adresse = parts.join(', ');
        }
      } catch (_) {
        // Fallback sur coordonnées si geocoding échoue
      }

      setState(() {
        _geoLat = pos.latitude;
        _geoLng = pos.longitude;
        _addressMode = 'geo';
        _addressCtrl.text = adresse;
        _geoLoading = false;
      });
    } catch (e) {
      _snack('Impossible d\'obtenir la position', Colors.red);
      setState(() => _geoLoading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static const _deliveryFee = 5000;

  int get _nbDays {
    if (_startDate == null || _endDate == null) return 1;
    return _endDate!.difference(_startDate!).inDays.clamp(1, 365);
  }

  bool get _wantDriver => widget.car?['wantDriver'] as bool? ?? true;

  // Prix BASE = toujours le prix sans chauffeur (ou pricePerDay si pas de séparation)
  int get _baseCarPrice {
    final withDriver    = num.tryParse(widget.car!['pricePerDay']?.toString() ?? '') ?? 0;
    final withoutDriver = num.tryParse(widget.car!['priceWithoutDriverPerDay']?.toString() ?? '');
    // Si la voiture a un prix séparé sans chauffeur → base = sans chauffeur
    // Le chauffeur est affiché en ligne séparée
    if (withoutDriver != null) return withoutDriver.toInt();
    // Pas de séparation → tout dans pricePerDay
    return withDriver.toInt();
  }

  // Frais chauffeur = pricePerDay - priceWithoutDriverPerDay (0 si pas de séparation)
  int get _driverFeePerDay {
    if (!_wantDriver || widget.car == null) return 0;
    final withDriver    = num.tryParse(widget.car!['pricePerDay']?.toString() ?? '') ?? 0;
    final withoutDriver = num.tryParse(widget.car!['priceWithoutDriverPerDay']?.toString() ?? '');
    if (withoutDriver == null) return 0; // pas de séparation
    return (withDriver - withoutDriver).toInt().clamp(0, 9999999);
  }

  int get _rentalAmount {
    if (widget.car != null) {
      return _baseCarPrice * _nbDays;
    }
    if (widget.pack != null) {
      final p = num.tryParse(widget.pack!['totalPrice']?.toString() ?? '') ?? 0;
      return (p * _nbDays).toInt();
    }
    if (widget.items != null) {
      return widget.items!.fold(0, (sum, i) {
        final p = num.tryParse(i['pricePerUnitPerDay']?.toString() ?? '') ?? 0;
        final q = i['quantity'] as int? ?? 0;
        return sum + (p * q * _nbDays).toInt();
      });
    }
    return 0;
  }

  int get _deposit {
    if (widget.car != null)
      return (num.tryParse(widget.car!['deposit']?.toString() ?? '') ?? 0).toInt();
    if (widget.pack != null)
      return (num.tryParse(widget.pack!['deposit']?.toString() ?? '') ?? 0).toInt();
    if (widget.items != null) {
      return widget.items!.fold(0, (sum, i) {
        final d = num.tryParse(i['depositPerUnit']?.toString() ?? '') ?? 0;
        final q = i['quantity'] as int? ?? 0;
        return sum + (d * q).toInt();
      });
    }
    return 0;
  }

  int get _driverTotal => _driverFeePerDay * _nbDays;
  int get _depositAmount => _withDeposit ? _deposit : 0;
  int get _total => _rentalAmount + _driverTotal + _depositAmount + (_delivery == 'delivery' ? _deliveryFee : 0);

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? now : (_startDate ?? now).add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked))
          _endDate = picked.add(const Duration(days: 1));
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _book() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez les dates'), backgroundColor: Colors.orange));
      return;
    }
    if (_delivery == 'delivery' && _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez votre adresse de livraison'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final fmt = (DateTime d) => d.toIso8601String().substring(0, 10);
      await api.post('/rental/bookings', data: {
        'bookingType': widget.car != null ? 'car' : 'event',
        if (widget.car != null) 'carId': widget.car!['id'],
        if (widget.car != null) 'withDriver': widget.car!['wantDriver'] ?? true,
        if (widget.pack != null) 'packId': widget.pack!['id'],
        if (widget.items != null) 'items': widget.items!.map((i) => {
          'itemId': i['id'],
          'itemName': i['name'],
          'quantity': i['quantity'],
          'pricePerUnitPerDay': i['pricePerUnitPerDay'],
        }).toList(),
        'startDate': fmt(_startDate!),
        'endDate': fmt(_endDate!),
        'deliveryOption': _delivery,
        'withDeposit': _withDeposit,
        if (_delivery == 'delivery') 'deliveryAddress': _addressCtrl.text.trim(),
        if (_delivery == 'delivery' && _geoLat != null) 'deliveryLat': _geoLat,
        if (_delivery == 'delivery' && _geoLng != null) 'deliveryLng': _geoLng,
        if (_delivery == 'delivery') 'deliveryFee': _deliveryFee,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Réservation envoyée ! Vous serez contacté pour confirmation.'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        widget.onBooked();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.car != null
        ? '${widget.car!['name'] ?? 'Voiture'} · ${(widget.car!['wantDriver'] as bool? ?? true) ? 'Avec chauffeur' : 'Sans chauffeur'}'
        : widget.pack != null
            ? widget.pack!['name'] ?? 'Pack'
            : '${widget.items?.fold(0, (s, i) => s! + (i['quantity'] as int? ?? 0))} articles';

    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Réserver — $title',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Divider(),
          Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.all(20), children: [

            // ── Info chauffeur (si voiture avec chauffeur) ─────────────────
            if (widget.car != null) ...[
              _CarDriverSummary(car: widget.car!, wantDriver: _wantDriver,
                driverFeePerDay: _driverFeePerDay, baseCarPricePerDay: _baseCarPrice),
              const SizedBox(height: 20),
            ],

            // Dates
            const Text('📅 Dates de location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _DatePick(label: 'Début', date: _startDate, onTap: () => _pickDate(true))),
              const SizedBox(width: 12),
              Expanded(child: _DatePick(label: 'Fin', date: _endDate, onTap: () => _pickDate(false))),
            ]),
            if (_startDate != null && _endDate != null) ...[
              const SizedBox(height: 8),
              Text('Durée : $_nbDays jour${_nbDays > 1 ? 's' : ''}',
                style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),

            // Livraison
            const Text('🚚 Mode de récupération', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _DeliveryChip(
                label: '🏠 Retrait sur place', value: 'pickup', selected: _delivery,
                onTap: () => setState(() => _delivery = 'pickup'))),
              const SizedBox(width: 10),
              Expanded(child: _DeliveryChip(
                label: '🚚 Livraison (+${_deliveryFee}F)', value: 'delivery', selected: _delivery,
                onTap: () => setState(() => _delivery = 'delivery'))),
            ]),
            if (_delivery == 'delivery') ...[
              const SizedBox(height: 14),
              const Text('📍 Adresse de livraison',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              // Toggle géolocalisation / manuel
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: _geoLoading ? null : _useGeolocation,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _addressMode == 'geo'
                        ? const Color(0xFF1A237E) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _addressMode == 'geo'
                          ? const Color(0xFF1A237E) : Colors.grey.shade300)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _geoLoading
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.my_location_rounded, size: 16,
                            color: _addressMode == 'geo' ? Colors.white : Colors.grey),
                      const SizedBox(width: 6),
                      Text('Ma position', style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _addressMode == 'geo' ? Colors.white : Colors.black87)),
                    ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _addressMode = 'manual'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _addressMode == 'manual'
                        ? const Color(0xFF1A237E) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _addressMode == 'manual'
                          ? const Color(0xFF1A237E) : Colors.grey.shade300)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.edit_location_outlined, size: 16,
                        color: _addressMode == 'manual' ? Colors.white : Colors.grey),
                      const SizedBox(width: 6),
                      Text('Saisir manuellement', style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _addressMode == 'manual' ? Colors.white : Colors.black87)),
                    ]),
                  ),
                )),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _addressCtrl,
                readOnly: _addressMode == 'geo',
                maxLines: _addressMode == 'manual' ? 2 : 1,
                decoration: InputDecoration(
                  hintText: _addressMode == 'geo'
                    ? 'Position GPS détectée'
                    : 'Quartier, rue, repère...',
                  prefixIcon: Icon(
                    _addressMode == 'geo' ? Icons.gps_fixed : Icons.home_outlined,
                    color: const Color(0xFF1A237E)),
                  filled: _addressMode == 'geo',
                  fillColor: _addressMode == 'geo'
                    ? const Color(0xFFE8EAF6) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Toggle caution
            if (_deposit > 0) ...[
              const SizedBox(height: 20),
              Row(children: [
                const Text('🔐 Caution', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: _withDeposit,
                    activeColor: const Color(0xFF1A237E),
                    onChanged: (v) => setState(() => _withDeposit = v),
                  ),
                ),
              ]),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _withDeposit ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _withDeposit ? Colors.orange.shade200 : Colors.green.shade200)),
                child: Row(children: [
                  Icon(
                    _withDeposit ? Icons.lock_outline : Icons.lock_open_outlined,
                    size: 18,
                    color: _withDeposit ? Colors.orange.shade700 : Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _withDeposit
                      ? 'Caution de ${_fmt(_deposit)} FCFA bloquée — remboursée à la restitution'
                      : 'Sans caution — vous êtes responsable en cas de dommages',
                    style: TextStyle(
                      fontSize: 12,
                      color: _withDeposit ? Colors.orange.shade700 : Colors.green.shade700),
                  )),
                ]),
              ),
            ],
            const SizedBox(height: 20),

            // Récap
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: [
                // Voiture
                if (widget.car != null) ...[
                  _RecapRow(
                    'Voiture · $_nbDays jour${_nbDays > 1 ? 's' : ''}',
                    '${_fmt(_baseCarPrice * _nbDays)} FCFA'),
                  if (_wantDriver && _driverFeePerDay > 0)
                    _RecapRow(
                      '🧑‍✈️ Chauffeur · $_nbDays jour${_nbDays > 1 ? 's' : ''}'
                      ' (${_fmt(_driverFeePerDay)} F/j)',
                      '${_fmt(_driverTotal)} FCFA',
                      color: const Color(0xFF1565C0)),
                ] else
                  _RecapRow('Location · $_nbDays jour${_nbDays > 1 ? 's' : ''}',
                    '${_fmt(_rentalAmount)} FCFA'),
                if (_withDeposit)
                  _RecapRow('Caution (remboursable)', '${_fmt(_depositAmount)} FCFA')
                else
                  _RecapRow('Caution', 'Sans caution', color: Colors.green.shade700),
                if (_delivery == 'delivery')
                  _RecapRow('Frais de livraison', '${_fmt(_deliveryFee)} FCFA'),
                const Divider(),
                _RecapRow('Total à payer', '${_fmt(_total)} FCFA', bold: true),
              ]),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _loading ? null : _book,
              icon: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline),
              label: const Text('Confirmer la réservation', style: TextStyle(fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ La caution est bloquée et remboursée après vérification à la restitution.',
              style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
          ])),
        ]),
      ),
    );
  }
}

// ── Résumé voiture + chauffeur dans le sheet de réservation ──────────────────
class _CarDriverSummary extends StatelessWidget {
  final Map<String, dynamic> car;
  final bool wantDriver;
  final int driverFeePerDay;
  final int baseCarPricePerDay;
  const _CarDriverSummary({
    required this.car, required this.wantDriver,
    required this.driverFeePerDay, required this.baseCarPricePerDay,
  });

  String _fmt(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = car['photoUrl'] as String?;
    final driverName = car['driverName'] as String?;
    final driverPhotoUrl = car['driverPhotoUrl'] as String?;
    final driverRating = num.tryParse(car['driverRating']?.toString() ?? '') ?? 0;
    final driverTrips = car['driverTrips'] ?? 0;
    final hasDriver = car['withDriver'] == true && driverName != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A237E).withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Photo + badge
        if (photoUrl != null)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Stack(children: [
              CachedNetworkImage(
                imageUrl: photoUrl,
                height: 140, width: double.infinity, fit: BoxFit.cover,
                placeholder: (_, __) => _ShimmerBox(height: 140),
                errorWidget: (_, __, ___) => const SizedBox(),
                memCacheHeight: 280, maxHeightDiskCache: 280,
              ),
              // Badge mode
              Positioned(top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: wantDriver && hasDriver
                        ? const Color(0xFF1A237E) : Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(wantDriver && hasDriver
                        ? Icons.person_rounded : Icons.person_off_outlined,
                      size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(wantDriver && hasDriver ? 'Avec chauffeur' : 'Sans chauffeur',
                      style: const TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold)),
                  ]),
                )),
            ]),
          ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Nom voiture
            Text('${car['name'] ?? ''} · ${car['brand'] ?? ''}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),

            // Détail prix/jour
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: [
                // Prix location/jour
                Row(children: [
                  const Icon(Icons.directions_car_rounded, size: 15, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Expanded(child: Text('Location / jour',
                    style: TextStyle(fontSize: 12, color: Colors.grey))),
                  Text('${_fmt(baseCarPricePerDay)} FCFA/j',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
                // Prix chauffeur/jour (si avec chauffeur)
                if (wantDriver && hasDriver && driverFeePerDay > 0) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Text('🧑‍✈️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('Chauffeur / jour',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1565C0)))),
                    Text('+ ${_fmt(driverFeePerDay)} FCFA/j',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: Color(0xFF1565C0))),
                  ]),
                ],
                // Total /jour
                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.calculate_outlined, size: 15, color: Colors.black54),
                  const SizedBox(width: 6),
                  const Expanded(child: Text('Total / jour',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  Text('${_fmt(wantDriver && hasDriver ? baseCarPricePerDay + driverFeePerDay : baseCarPricePerDay)} FCFA/j',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                      color: Color(0xFF1A237E))),
                ]),
              ]),
            ),

            // Profil chauffeur
            if (wantDriver && hasDriver) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100)),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: driverPhotoUrl != null
                        ? CachedNetworkImageProvider(driverPhotoUrl,
                            maxHeight: 88, maxWidth: 88) : null,
                    backgroundColor: const Color(0xFF1A237E).withOpacity(0.1),
                    child: driverPhotoUrl == null
                        ? const Icon(Icons.person, color: Color(0xFF1A237E)) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(driverName!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text('${driverRating.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('· $driverTrips courses',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300)),
                    child: const Text('Inclus',
                      style: TextStyle(color: Colors.green, fontSize: 11,
                        fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            ] else if (!wantDriver) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('Vous conduisez vous-même',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _DatePick extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DatePick({required this.label, required this.date, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: date != null ? const Color(0xFF1A237E) : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: date != null ? const Color(0xFFE8EAF6) : Colors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(date != null
            ? '${date!.day.toString().padLeft(2,'0')}/${date!.month.toString().padLeft(2,'0')}/${date!.year}'
            : 'Choisir',
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: date != null ? const Color(0xFF1A237E) : Colors.grey)),
      ]),
    ),
  );
}

class _DeliveryChip extends StatelessWidget {
  final String label, value, selected;
  final VoidCallback onTap;
  const _DeliveryChip({required this.label, required this.value, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFE8EAF6) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? const Color(0xFF1A237E) : Colors.grey.shade300, width: sel ? 2 : 1)),
        child: Text(label, style: TextStyle(
          fontSize: 12, color: sel ? const Color(0xFF1A237E) : Colors.black87,
          fontWeight: sel ? FontWeight.bold : FontWeight.normal),
          textAlign: TextAlign.center),
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _RecapRow(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(
        fontSize: 13,
        color: color ?? (bold ? Colors.black : Colors.grey.shade700),
        fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
      Text(value, style: TextStyle(
        fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: color ?? (bold ? const Color(0xFF1A237E) : Colors.black87))),
    ]),
  );
}

// ── Bandeau hors-ligne ────────────────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: const Color(0xFFF59E0B),
    child: Row(children: [
      const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
      const SizedBox(width: 8),
      const Expanded(
        child: Text(
          'Hors-ligne · Données en cache — tirez pour actualiser',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ]),
  );
}

class _PriceRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _PriceRow(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(
        fontSize: 12,
        color: color ?? (bold ? Colors.black87 : Colors.grey.shade600),
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal))),
      Text(value, style: TextStyle(
        fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: color ?? (bold ? const Color(0xFF1A237E) : Colors.black87))),
    ]),
  );
}

class _ErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorWidget({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 60, color: Colors.red),
      const SizedBox(height: 12),
      const Text('Erreur de chargement', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
    ],
  ));
}

// ── En-tête section réservations ──────────────────────────────────────────────
class _BookingsHeader extends StatelessWidget {
  final int count;
  const _BookingsHeader({required this.count});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      const Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFF1A237E)),
      const SizedBox(width: 8),
      Text('Mes réservations ($count)',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A237E))),
    ]),
  );
}

// ── Carte réservation ─────────────────────────────────────────────────────────
class _BookingCard extends ConsumerWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onRefresh;
  const _BookingCard({required this.booking, required this.onRefresh});

  static const _statusColors = {
    'pending':   Color(0xFFF59E0B),
    'confirmed': Color(0xFF10B981),
    'active':    Color(0xFF1A237E),
    'returned':  Color(0xFF8B5CF6),
    'completed': Color(0xFF6B7280),
    'cancelled': Color(0xFFEF4444),
  };
  static const _statusLabels = {
    'pending':   'En attente',
    'confirmed': '✓ Confirmée',
    'active':    '▶ En cours',
    'returned':  'Rendu',
    'completed': '✓ Terminée',
    'cancelled': '✗ Annulée',
  };
  static const _depositLabels = {
    'held':      '🔐 Caution bloquée',
    'refunded':  '✅ Caution remboursée',
    'kept':      '⚠️ Caution retenue',
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
  Widget build(BuildContext context, WidgetRef ref) {
    final status       = booking['status']        as String? ?? 'pending';
    final depositStatus= booking['depositStatus'] as String? ?? 'held';
    final statusColor  = _statusColors[status] ?? Colors.grey;
    final startDate    = booking['startDate']     as String? ?? '';
    final endDate      = booking['endDate']       as String? ?? '';
    final nbDays       = booking['nbDays'] ?? 1;
    final total        = booking['totalPaid'];
    final items        = booking['items']         as List?   ?? [];
    final delivery     = booking['deliveryOption']as String? ?? 'pickup';
    final car          = booking['car']  != null ? Map<String, dynamic>.from(booking['car']  as Map) : null;
    final pack         = booking['pack'] != null ? Map<String, dynamic>.from(booking['pack'] as Map) : null;
    // withDriver peut être bool ou "true"/"false" string selon la version
    final _wd = booking['withDriver'];
    final withDriver = _wd == true || _wd == 'true';


    // Titre principal
    String title = '';
    if (car != null) {
      title = '${car['name'] ?? 'Voiture'} · ${car['brand'] ?? ''}';
    } else if (pack != null) {
      title = '📦 ${pack['name'] ?? 'Pack événement'}';
    } else if (items.isNotEmpty) {
      final totalQty = items.fold<int>(0, (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0));
      title = '🪑 $totalQty article${totalQty > 1 ? 's' : ''}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Photo voiture ou pack ──────────────────────────────────────
        if (car?['photoUrl'] != null || pack?['photoUrl'] != null)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Stack(children: [
              CachedNetworkImage(
                imageUrl: (car?['photoUrl'] ?? pack?['photoUrl']) as String,
                height: 130, width: double.infinity, fit: BoxFit.cover,
                placeholder: (_, __) => _ShimmerBox(height: 130),
                errorWidget: (_, __, ___) => const SizedBox(),
                memCacheHeight: 260,
                maxHeightDiskCache: 260,
              ),
              // Badge statut sur la photo
              Positioned(top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(_statusLabels[status] ?? status,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                )),
              // Badge jours
              Positioned(bottom: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text('$startDate → $endDate · $nbDays j',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                )),
            ]),
          )
        else
          // Sans photo — bandeau statut simple
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              Expanded(child: Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.4))),
                child: Text(_statusLabels[status] ?? status,
                  style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Titre si photo présente
            if (car?['photoUrl'] != null || pack?['photoUrl'] != null)
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),

            const SizedBox(height: 8),

            // ── Info chauffeur ─────────────────────────────────────────
            if (car != null && withDriver && car['driverName'] != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100)),
                child: Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: car['driverPhotoUrl'] != null
                        ? CachedNetworkImageProvider(
                            car['driverPhotoUrl'] as String,
                            maxHeight: 80, maxWidth: 80)
                        : null,
                    backgroundColor: const Color(0xFF1A237E).withOpacity(0.1),
                    child: car['driverPhotoUrl'] == null
                        ? const Icon(Icons.person, size: 18, color: Color(0xFF1A237E)) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(car['driverName'] as String,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text('${num.tryParse(car['driverRating']?.toString() ?? '')?.toStringAsFixed(1) ?? '—'}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Avec chauffeur',
                      style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ] else if (car != null && !withDriver) ...[
              Row(children: [
                const Icon(Icons.person_off_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                const Text('Sans chauffeur', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
              const SizedBox(height: 8),
            ],

            // ── Dates + livraison ──────────────────────────────────────
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text('$startDate → $endDate',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 12),
              Icon(delivery == 'delivery'
                ? Icons.local_shipping_outlined : Icons.store_outlined,
                size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(delivery == 'delivery' ? 'Livraison' : 'Retrait sur place',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            const SizedBox(height: 8),

            // ── Détail prix ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: [
                _PriceRow('Location · $nbDays j',
                  '${_fmt(booking['rentalAmount'])} FCFA'),
                if ((num.tryParse(booking['driverFee']?.toString() ?? '') ?? 0) > 0)
                  _PriceRow('🧑‍✈️ Chauffeur · $nbDays j',
                    '${_fmt(booking['driverFee'])} FCFA',
                    color: const Color(0xFF1565C0)),
                if ((num.tryParse(booking['depositAmount']?.toString() ?? '') ?? 0) > 0)
                  _PriceRow('Caution', '${_fmt(booking['depositAmount'])} FCFA',
                    color: Colors.orange.shade700),
                if ((num.tryParse(booking['deliveryFee']?.toString() ?? '') ?? 0) > 0)
                  _PriceRow('Livraison', '${_fmt(booking['deliveryFee'])} FCFA'),
                const Divider(height: 12),
                _PriceRow('Total payé', '${_fmt(total)} FCFA', bold: true),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(_depositLabels[depositStatus] ?? depositStatus,
                    style: TextStyle(fontSize: 11,
                      color: depositStatus == 'refunded' ? Colors.green
                        : depositStatus == 'kept' ? Colors.red : Colors.orange)),
                ]),
              ]),
            ),
        // Articles détail si événement
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4,
            children: [
              ...items.take(4).map<Widget>((i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)),
                child: Text('${i['itemName']} ×${i['quantity']}',
                  style: const TextStyle(fontSize: 11)),
              )),
              if (items.length > 4)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('+${items.length - 4} autres',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
            ],
          ),
        ],
            // ── Bouton annuler si pending ──────────────────────────────
            if (status == 'pending') ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final api = ref.read(apiClientProvider);
                    try {
                      await api.patch('/rental/bookings/${booking['id']}/cancel');
                      onRefresh();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Erreur: $e'), backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating));
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Annuler'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12)),
                )),
            ],
          ]),
        ),
      ]),
    );
  }
}
