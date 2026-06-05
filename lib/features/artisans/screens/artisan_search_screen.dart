import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ArtisanSearchScreen extends ConsumerStatefulWidget {
  const ArtisanSearchScreen({super.key});

  @override
  ConsumerState<ArtisanSearchScreen> createState() => _ArtisanSearchScreenState();
}

class _ArtisanSearchScreenState extends ConsumerState<ArtisanSearchScreen> {
  final _searchCtrl = TextEditingController();

  List<dynamic> _results = [];
  bool _loading = false;
  String? _error;

  // Filtres
  String? _selectedSpecialty;
  double _radius = 10.0;
  double? _lat;
  double? _lng;
  bool _geoLoading = false;

  static const _specialties = [
    'Tous',
    'Électricien', 'Plombier', 'Maçon', 'Peintre en bâtiment',
    'Menuisier bois', 'Menuisier aluminium', 'Soudeur', 'Carreleur',
    'Climaticien', 'Couvreur / Toiturier', 'Poseur de faux plafond',
    'Installateur solaire', 'Mécanicien auto', 'Mécanicien moto',
    'Électricien auto', 'Réparateur d\'électroménager',
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _geoLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() { _geoLoading = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      setState(() { _lat = pos.latitude; _lng = pos.longitude; _geoLoading = false; });
      _search();
    } catch (_) {
      setState(() => _geoLoading = false);
    }
  }

  Future<void> _search() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final lat = _lat ?? 3.848;   // Yaoundé par défaut
      final lng = _lng ?? 11.502;
      final specialty = (_selectedSpecialty == null || _selectedSpecialty == 'Tous')
          ? null : _selectedSpecialty;
      final query = _searchCtrl.text.trim();

      final res = await api.get('/artisans/nearby', params: {
        'lat': '$lat',
        'lng': '$lng',
        'radius': '$_radius',
        if (specialty != null) 'specialty': specialty,
      });

      var data = List<dynamic>.from(res.data is List ? res.data : (res.data['data'] ?? []));

      // Filtre textuel client-side si recherche saisie
      if (query.isNotEmpty) {
        data = data.where((p) {
          final name = (p['name'] as String? ?? '').toLowerCase();
          final city = (p['city'] as String? ?? '').toLowerCase();
          return name.contains(query.toLowerCase()) || city.contains(query.toLowerCase());
        }).toList();
      }

      setState(() { _results = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Trouver un artisan'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou ville…',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () { _searchCtrl.clear(); _search(); })
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Filtres ──────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Localisation + rayon
              Row(children: [
                Icon(Icons.location_on_outlined,
                    size: 16,
                    color: _lat != null ? Colors.green : Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _geoLoading
                      ? 'Localisation…'
                      : _lat != null
                          ? 'Position obtenue'
                          : 'Position non disponible',
                  style: TextStyle(
                    fontSize: 12,
                    color: _lat != null ? Colors.green : Colors.grey,
                  ),
                ),
                const Spacer(),
                Text('Rayon : ${_radius.toInt()} km',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              Slider(
                value: _radius,
                min: 2, max: 50, divisions: 12,
                activeColor: const Color(0xFF1976D2),
                onChanged: (v) => setState(() => _radius = v),
                onChangeEnd: (_) => _search(),
              ),

              // Spécialités
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _specialties.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final sp = _specialties[i];
                    final selected = sp == 'Tous'
                        ? _selectedSpecialty == null
                        : _selectedSpecialty == sp;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedSpecialty = sp == 'Tous' ? null : sp);
                        _search();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF1976D2)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF1976D2)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(sp,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : Colors.black87,
                            )),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),

          // ── Résultats ────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _results.isEmpty
                        ? _buildEmpty()
                        : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 48, color: Colors.red),
    const SizedBox(height: 8),
    Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
    const SizedBox(height: 12),
    ElevatedButton(onPressed: _search, child: const Text('Réessayer')),
  ]));

  Widget _buildEmpty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.handyman_outlined, size: 64, color: Colors.grey.shade300),
    const SizedBox(height: 12),
    const Text('Aucun artisan trouvé dans ce rayon',
        style: TextStyle(fontSize: 15, color: Colors.grey)),
    const SizedBox(height: 4),
    const Text('Essayez d\'augmenter le rayon de recherche',
        style: TextStyle(fontSize: 12, color: Colors.grey)),
  ]));

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            '${_results.length} artisan${_results.length > 1 ? 's' : ''} trouvé${_results.length > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: _results.length,
            itemBuilder: (_, i) => _ArtisanCard(artisan: _results[i]),
          ),
        ),
      ],
    );
  }
}

// ── Carte artisan ─────────────────────────────────────────────────────────────
class _ArtisanCard extends StatelessWidget {
  final dynamic artisan;
  const _ArtisanCard({required this.artisan});

  @override
  Widget build(BuildContext context) {
    final name       = artisan['name']           as String? ?? 'Artisan';
    final city       = artisan['city']           as String?;
    final photo      = artisan['profilePhotoUrl'] as String?;
    final trustScore = (artisan['trustScore'] as num? ?? 0).toDouble();
    final distKm     = (artisan['distanceKm']   as num?);
    final id         = artisan['id']             as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: id != null ? () => context.push('/artisans/portfolio/$id') : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
              child: photo == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2)))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15)),
              if (city != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                  const SizedBox(width: 3),
                  Text(city, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (distKm != null) ...[
                    Text(' · ${distKm}km',
                        style: const TextStyle(fontSize: 12, color: Colors.blue)),
                  ],
                ]),
              ],
              const SizedBox(height: 6),
              // Score de confiance
              Row(children: [
                ...List.generate(5, (i) => Icon(
                  i < trustScore.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 14,
                  color: i < trustScore.round() ? Colors.amber : Colors.grey.shade300,
                )),
                const SizedBox(width: 4),
                Text('${trustScore.toStringAsFixed(1)}/5',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ])),

            // Bouton voir portfolio
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Voir',
                  style: TextStyle(
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }
}
