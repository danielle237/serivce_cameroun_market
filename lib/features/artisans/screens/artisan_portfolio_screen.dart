import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';

class ArtisanPortfolioScreen extends ConsumerStatefulWidget {
  final String providerId;
  const ArtisanPortfolioScreen({super.key, required this.providerId});

  @override
  ConsumerState<ArtisanPortfolioScreen> createState() => _ArtisanPortfolioScreenState();
}

class _ArtisanPortfolioScreenState extends ConsumerState<ArtisanPortfolioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _isOwn = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final myId = ref.read(authStateProvider).value?.user?['id'];
      _isOwn = myId == widget.providerId;
      final res = await api.get('/artisans/portfolio/${widget.providerId}');
      setState(() { _data = Map<String, dynamic>.from(res.data); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Profil introuvable'))
              : NestedScrollView(
                  headerSliverBuilder: (_, __) => [_buildHeader()],
                  body: TabBarView(controller: _tabs, children: [
                    _buildPortfolio(),
                    _buildRatings(),
                    _buildStats(),
                  ]),
                ),
      floatingActionButton: _isOwn
          ? FloatingActionButton.extended(
              onPressed: _showAddRealisationSheet,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Ajouter une réalisation'),
              backgroundColor: const Color(0xFF1976D2),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    final p = _data!['provider'] as Map<String, dynamic>? ?? {};
    final stats = _data!['stats'] as Map<String, dynamic>? ?? {};
    final trust = _toInt(p['trustScore']);
    final avg   = _toDouble(stats['avgRating']);
    final total = _toInt(stats['totalProjects']);
    final specialties = stats['specialties'] as List? ?? [];

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.orange.shade700,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade900, Colors.orange.shade600],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(height: 40),
            Stack(alignment: Alignment.bottomRight, children: [
              CircleAvatar(
                radius: 46,
                backgroundImage: p['profilePhotoUrl'] != null
                    ? NetworkImage(p['profilePhotoUrl']) : null,
                backgroundColor: Colors.white24,
                child: p['profilePhotoUrl'] == null
                    ? const Icon(Icons.handyman, size: 46, color: Colors.white) : null,
              ),
              if (trust >= 80)
                Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.verified, size: 14, color: Colors.white),
                ),
            ]),
            const SizedBox(height: 10),
            Text(p['name'] ?? 'Artisan',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            if (p['city'] != null)
              Text(p['city'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            if (specialties.isNotEmpty)
              Wrap(
                spacing: 6, alignment: WrapAlignment.center,
                children: specialties.take(3).map<Widget>((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(s.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                )).toList(),
              ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _stat(Icons.star_rounded, avg > 0 ? avg.toStringAsFixed(1) : 'Nouveau', Colors.amber),
              const SizedBox(width: 20),
              _stat(Icons.check_circle_outline, '$total chantiers', Colors.greenAccent),
              const SizedBox(width: 20),
              _stat(Icons.shield_outlined, '$trust%', Colors.lightBlueAccent),
            ]),
          ])),
        ),
      ),
      bottom: TabBar(
        controller: _tabs,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: Colors.white,
        tabs: const [Tab(text: 'Réalisations'), Tab(text: 'Avis'), Tab(text: 'Stats')],
      ),
    );
  }

  Widget _stat(IconData icon, String value, Color color) => Row(children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 4),
    Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
  ]);

  Widget _buildPortfolio() {
    final items = _data!['items'] as List? ?? [];
    if (items.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('Aucune réalisation ajoutée', style: TextStyle(color: Colors.grey, fontSize: 15)),
        if (_isOwn) ...[
          const SizedBox(height: 8),
          const Text('Ajoutez vos chantiers pour convaincre les clients',
              style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
        ],
      ],
    ));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => _PortfolioCard(
        item: Map<String, dynamic>.from(items[i]),
        isOwn: _isOwn,
        onDeleted: _load,
        ref: ref,
      ),
    );
  }

  Widget _buildRatings() {
    final ratingsData = _data!['ratings'] as Map<String, dynamic>?;
    if (ratingsData == null) {
      return FutureBuilder(
        future: ref.read(apiClientProvider).get('/artisans/providers/${widget.providerId}/ratings'),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = Map<String, dynamic>.from(snap.data!.data);
          return _RatingsView(data: d);
        },
      );
    }
    return _RatingsView(data: ratingsData);
  }

  Widget _buildStats() {
    final stats = _data!['stats'] as Map<String, dynamic>? ?? {};
    final avgR = _toDouble(stats['avgRating']);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: _StatCard('${_toInt(stats['totalProjects'])}', 'Chantiers\nterminés',
            Icons.construction_outlined, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          avgR > 0 ? avgR.toStringAsFixed(1) : '—',
          'Note\nmoyenne', Icons.star_rounded, Colors.amber)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          '${_toInt((_data!['provider'] as Map?)?['trustScore'])}%',
          'Score de\nconfiance', Icons.shield_outlined, Colors.green)),
      ]),
    ]);
  }

  void _showAddRealisationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRealisationSheet(onSaved: _load),
    );
  }
}

// ── Carte réalisation ─────────────────────────────────────────────────────────
class _PortfolioCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isOwn;
  final VoidCallback onDeleted;
  final WidgetRef ref;
  const _PortfolioCard({required this.item, required this.isOwn,
      required this.onDeleted, required this.ref});

  @override
  State<_PortfolioCard> createState() => _PortfolioCardState();
}

class _PortfolioCardState extends State<_PortfolioCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final photos = item['photos'] as List? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Photos
        if (photos.isNotEmpty) ...[
          SizedBox(
            height: 200,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: PageView.builder(
                itemCount: photos.length,
                itemBuilder: (_, i) {
                  final photo = photos[i] as Map<String, dynamic>;
                  return Stack(fit: StackFit.expand, children: [
                    Image.network(photo['url'] as String? ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        )),
                    if (photo['caption'] != null)
                      Positioned(bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.black54,
                          child: Text(photo['caption'].toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        )),
                    if (photos.length > 1)
                      Positioned(top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                          child: Text('${i + 1}/${photos.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 11)),
                        )),
                  ]);
                },
              ),
            ),
          ),
        ] else
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Center(child: Icon(Icons.construction_outlined, size: 48, color: Colors.orange)),
          ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Titre + spécialité
            Row(children: [
              Expanded(child: Text(item['title'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              if (item['specialty'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(item['specialty'].toString(),
                      style: const TextStyle(fontSize: 11, color: Colors.orange,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 6),

            // Description
            if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
              Text(
                _expanded
                    ? item['description'].toString()
                    : item['description'].toString().length > 120
                        ? '${item['description'].toString().substring(0, 120)}...'
                        : item['description'].toString(),
                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
              ),
              if (item['description'].toString().length > 120)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Voir moins' : 'Voir plus',
                      style: const TextStyle(color: Color(0xFF1976D2), fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 8),
            ],

            // Infos
            Row(children: [
              if (item['city'] != null)
                _chip(Icons.location_on_outlined, item['city'].toString(), Colors.grey),
              if (item['durationDays'] != null) ...[
                const SizedBox(width: 8),
                _chip(Icons.schedule_outlined, '${item['durationDays']}j', Colors.blue),
              ],
              if (item['approximateCost'] != null) ...[
                const SizedBox(width: 8),
                _chip(Icons.attach_money, '${item['approximateCost']} FCFA', Colors.green),
              ],
            ]),

            // Témoignage client
            if (item['clientTestimonial'] != null &&
                item['clientTestimonial'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.format_quote, color: Colors.blue, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(item['clientTestimonial'].toString(),
                      style: const TextStyle(fontSize: 12, color: Colors.blue,
                          fontStyle: FontStyle.italic))),
                ]),
              ),
            ],

            // Bouton supprimer (propriétaire)
            if (widget.isOwn) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Supprimer cette réalisation ?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            child: const Text('Supprimer')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await widget.ref.read(apiClientProvider).delete('/artisans/portfolio/${item['id']}');
                      widget.onDeleted();
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Supprimer', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 12, color: color)),
    ],
  );
}

// ── Avis ─────────────────────────────────────────────────────────────────────
class _RatingsView extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RatingsView({required this.data});

  @override
  Widget build(BuildContext context) {
    final avg = (data['average'] as num?)?.toDouble() ?? 0.0;
    final total = (data['total'] as num?)?.toInt() ?? 0;
    final breakdown = data['breakdown'] as Map<String, dynamic>? ?? {};
    final reviews = data['reviews'] as List? ?? [];

    if (total == 0) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.star_border_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('Aucun avis pour l\'instant', style: TextStyle(color: Colors.grey, fontSize: 15)),
      ],
    ));

    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Row(children: [
            Text(avg.toStringAsFixed(1),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.orange)),
            const Text('/5', style: TextStyle(fontSize: 22, color: Colors.grey)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _bar('Qualité',      breakdown['quality']     ?? 0),
              _bar('Ponctualité',  breakdown['punctuality'] ?? 0),
              _bar('Propreté',     breakdown['cleanliness'] ?? 0),
            ])),
          ]),
          const SizedBox(height: 8),
          Text('$total avis clients', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
      ),
      const SizedBox(height: 12),
      ...reviews.map((r) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(radius: 16, backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.person_outline, size: 18, color: Colors.orange)),
            const SizedBox(width: 8),
            Expanded(child: Text(r['title'] as String? ?? 'Chantier',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Row(children: List.generate(5, (i) => Icon(
              i < (r['overall'] as num? ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
              size: 14, color: Colors.amber,
            ))),
          ]),
          if (r['comment'] != null && r['comment'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r['comment'].toString(),
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ])),
      )),
    ]);
  }

  Widget _bar(String label, dynamic value) {
    final v = (value as num).toDouble();
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child:
      Row(children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
        Expanded(child: LinearProgressIndicator(
          value: v / 5,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(Colors.orange),
          minHeight: 6,
        )),
        const SizedBox(width: 6),
        Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatCard(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Card(
    elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Sheet ajout réalisation ───────────────────────────────────────────────────
class _AddRealisationSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddRealisationSheet({required this.onSaved});
  @override
  ConsumerState<_AddRealisationSheet> createState() => _AddRealisationSheetState();
}

class _AddRealisationSheetState extends ConsumerState<_AddRealisationSheet> {
  final _titleCtrl       = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _cityCtrl        = TextEditingController();
  final _costCtrl        = TextEditingController();
  final _testimonialCtrl = TextEditingController();
  final _photoUrlCtrl    = TextEditingController();
  final _photoCaptionCtrl = TextEditingController();
  String? _specialty;
  int? _durationDays;
  bool _loading = false;
  final List<Map<String, String>> _photos = [];

  static const _specialties = ['electricien', 'plombier', 'macon', 'mecanicien',
    'peintre', 'menuisier', 'soudeur', 'climatisation'];

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _cityCtrl.dispose();
    _costCtrl.dispose(); _testimonialCtrl.dispose();
    _photoUrlCtrl.dispose(); _photoCaptionCtrl.dispose();
    super.dispose();
  }

  void _addPhoto() {
    if (_photoUrlCtrl.text.trim().isEmpty) return;
    setState(() {
      _photos.add({
        'url': _photoUrlCtrl.text.trim(),
        'caption': _photoCaptionCtrl.text.trim(),
      });
      _photoUrlCtrl.clear(); _photoCaptionCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Titre requis'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).post('/artisans/portfolio', data: {
        'title':             _titleCtrl.text.trim(),
        'description':       _descCtrl.text.trim(),
        'specialty':         _specialty,
        'city':              _cityCtrl.text.trim(),
        'photos':            _photos,
        'durationDays':      _durationDays,
        'approximateCost':   int.tryParse(_costCtrl.text.trim()),
        'clientTestimonial': _testimonialCtrl.text.trim().isEmpty
            ? null : _testimonialCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Réalisation ajoutée au portfolio !'),
            backgroundColor: Colors.green));
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92, maxChildSize: 0.97, minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const Text('Ajouter une réalisation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.all(16), children: [
            _tf('Titre *', _titleCtrl, hint: 'Installation tableau électrique 3 pièces'),
            const SizedBox(height: 12),
            const Text('Spécialité', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _specialty,
              decoration: const InputDecoration(border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: _specialties.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _specialty = v),
            ),
            const SizedBox(height: 12),
            _tf('Description détaillée *', _descCtrl, lines: 4,
                hint: 'Décrivez les travaux réalisés, les défis rencontrés, les matériaux utilisés...'
                    '\nPlus votre description est détaillée, plus les clients vous font confiance.'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _tf('Ville', _cityCtrl, hint: 'Douala')),
              const SizedBox(width: 12),
              Expanded(child: _tf('Durée (jours)', null,
                  hint: '3', type: TextInputType.number,
                  onChanged: (v) => _durationDays = int.tryParse(v))),
            ]),
            const SizedBox(height: 12),
            _tf('Budget approximatif (FCFA)', _costCtrl,
                hint: '150000', type: TextInputType.number),
            const SizedBox(height: 16),

            // Photos
            const Text('Photos du chantier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Ajoutez des liens vers vos photos (URL)',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            if (_photos.isNotEmpty) ...[
              ...List.generate(_photos.length, (i) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.image_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    _photos[i]['caption']?.isNotEmpty == true
                        ? _photos[i]['caption']!
                        : 'Photo ${i + 1}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  )),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    onPressed: () => setState(() => _photos.removeAt(i)),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                ]),
              )),
              const SizedBox(height: 8),
            ],
            _tf('URL de la photo', _photoUrlCtrl, hint: 'https://...'),
            const SizedBox(height: 6),
            _tf('Légende (optionnel)', _photoCaptionCtrl, hint: 'Avant / Pendant / Après travaux'),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                label: const Text('Ajouter cette photo'),
              ),
            ),
            const SizedBox(height: 12),

            // Témoignage
            _tf('Témoignage du client (optionnel)', _testimonialCtrl, lines: 2,
                hint: '"Très bon travail, propre et rapide. Je recommande !"'),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: const Text('Enregistrer la réalisation', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget _tf(String label, TextEditingController? ctrl, {
    String? hint, int lines = 1, TextInputType? type, void Function(String)? onChanged,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl,
      maxLines: lines, keyboardType: type,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  ]);
}
