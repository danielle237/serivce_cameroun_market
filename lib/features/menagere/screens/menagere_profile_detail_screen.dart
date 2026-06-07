import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';

const _pink = Color(0xFFEC4899);

const _servicesMeta = {
  'nettoyage':    {'label': 'Nettoyage',    'emoji': '🧹', 'color': 0xFF1565C0},
  'cuisine':      {'label': 'Cuisine',      'emoji': '🍳', 'color': 0xFFE65100},
  'garde_enfants':{'label': 'Garde enfants','emoji': '👶', 'color': 0xFFAD1457},
  'repassage':    {'label': 'Repassage',    'emoji': '👔', 'color': 0xFF6A1B9A},
  'lessive':      {'label': 'Lessive',      'emoji': '🫧', 'color': 0xFF00695C},
  'courses':      {'label': 'Courses',      'emoji': '🛒', 'color': 0xFF2E7D32},
};

// ═══════════════════════════════════════════════════════════════════════════
class MenagereProfileDetailScreen extends ConsumerStatefulWidget {
  final String profileId;
  const MenagereProfileDetailScreen({super.key, required this.profileId});
  @override
  ConsumerState<MenagereProfileDetailScreen> createState() => _State();
}

class _State extends ConsumerState<MenagereProfileDetailScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _reviews = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/menagere/profiles/${widget.profileId}', forceRefresh: true);
      final revRes = await api.get('/menagere/profiles/${widget.profileId}/reviews', params: {'limit': 5});
      if (mounted) setState(() {
        _profile = res.data is Map ? Map<String, dynamic>.from(res.data) : null;
        final revRaw = revRes.data;
        _reviews = revRaw is List ? revRaw : (revRaw is Map ? (revRaw['data'] ?? []) : []);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _showContractSheet() {
    if (_profile == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContractRequestSheet(profile: _profile!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(
      appBar: AppBar(backgroundColor: _pink, foregroundColor: Colors.white, title: const Text('Profil')),
      body: const Center(child: CircularProgressIndicator(color: _pink)));

    if (_profile == null) return Scaffold(
      appBar: AppBar(backgroundColor: _pink, foregroundColor: Colors.white, title: const Text('Profil')),
      body: const Center(child: Text('Profil introuvable')));

    final p = _profile!;
    final services = _parseArray(p['services']);
    final modes    = _parseArray(p['modes']);
    final photos   = _parseArray(p['photos']);
    final langs    = _parseArray(p['languages']);
    final avgRating = (p['avgRating'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F6),
      body: CustomScrollView(slivers: [
        // ── SliverAppBar avec photo ───────────────────────────────────────
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: _pink,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: p['photoUrl'] != null
              ? CachedNetworkImage(imageUrl: p['photoUrl'], fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: _pink.withOpacity(0.3)),
                  errorWidget: (_, __, ___) => _PhotoBg())
              : _PhotoBg(),
          ),
          actions: [
            if (p['isVerified'] == true)
              Container(margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(12)),
                child: const Text('✅ Vérifié', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),

        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Nom + note ────────────────────────────────────────────────
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['fullName'] ?? 'Ménagère',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text('📍 ${p['city'] ?? ''} ${p['quartier'] != null ? '· ${p['quartier']}' : ''}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Icon(Icons.star_rounded, size: 20, color: Colors.amber.shade600),
                Text(' ${avgRating.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
              Text('${p['totalReviews'] ?? 0} avis', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
          ]),
          const SizedBox(height: 16),

          // ── Bio ───────────────────────────────────────────────────────
          if (p['bio'] != null && (p['bio'] as String).isNotEmpty) ...[
            _SectionTitle('À propos'),
            Text(p['bio'], style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151))),
            const SizedBox(height: 16),
          ],

          // ── Services ─────────────────────────────────────────────────
          _SectionTitle('Services proposés'),
          Wrap(spacing: 8, runSpacing: 8,
            children: services.map((s) {
              final meta = _servicesMeta[s] ?? {'emoji': '📦', 'label': s, 'color': 0xFF607D8B};
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(meta['color'] as int).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(meta['color'] as int).withOpacity(0.4)),
                ),
                child: Text('${meta['emoji']}  ${meta['label']}',
                  style: TextStyle(fontSize: 13, color: Color(meta['color'] as int), fontWeight: FontWeight.w600)),
              );
            }).toList()),
          const SizedBox(height: 16),

          // ── Modes ─────────────────────────────────────────────────────
          if (modes.isNotEmpty) ...[
            _SectionTitle('Disponibilité'),
            Wrap(spacing: 8, runSpacing: 8, children: modes.map((m) {
              final labels = {'once': '1️⃣ Ponctuel', 'regular': '🔄 Régulier', 'live_in': '🏠 Résidentiel'};
              return _InfoChip(label: labels[m] ?? m, color: _pink);
            }).toList()),
            const SizedBox(height: 16),
          ],

          // ── Tarifs ────────────────────────────────────────────────────
          _SectionTitle('Tarifs'),
          Row(children: [
            Expanded(child: _TarifCard(label: 'Par jour', value: '${_fmt(p['tarifJour'])} FCFA')),
            const SizedBox(width: 12),
            Expanded(child: _TarifCard(label: 'Par mois', value: '${_fmt(p['tarifMois'])} FCFA')),
          ]),
          const SizedBox(height: 16),

          // ── Stats ─────────────────────────────────────────────────────
          Row(children: [
            _StatBox(icon: Icons.work_history_outlined,
              label: 'Expérience', value: '${p['experienceYears'] ?? 0} ans'),
            const SizedBox(width: 10),
            _StatBox(icon: Icons.assignment_turned_in_outlined,
              label: 'Contrats', value: '${p['totalContracts'] ?? 0}'),
            const SizedBox(width: 10),
            _StatBox(icon: Icons.star_outline_rounded, label: 'Note', value: avgRating.toStringAsFixed(1)),
          ]),
          const SizedBox(height: 16),

          // ── Langues ───────────────────────────────────────────────────
          if (langs.isNotEmpty) ...[
            _SectionTitle('Langues'),
            Wrap(spacing: 6, runSpacing: 6, children: langs.map((l) =>
              _InfoChip(label: '🗣 $l', color: const Color(0xFF6366F1))).toList()),
            const SizedBox(height: 16),
          ],

          // ── Galerie ───────────────────────────────────────────────────
          if (photos.isNotEmpty) ...[
            _SectionTitle('Photos'),
            SizedBox(height: 90, child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.only(right: 8),
                width: 90, height: 90,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(imageUrl: photos[i], fit: BoxFit.cover),
              ),
            )),
            const SizedBox(height: 16),
          ],

          // ── Avis ─────────────────────────────────────────────────────
          if (_reviews.isNotEmpty) ...[
            _SectionTitle('Avis clients (${p['totalReviews'] ?? 0})'),
            ..._reviews.map((r) => _ReviewCard(review: Map<String, dynamic>.from(r))),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 80), // space for FAB
        ]))),
      ]),

      // ── Bouton demander contrat ────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: ElevatedButton.icon(
          onPressed: _showContractSheet,
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Demander un contrat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _pink, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET — Demande de contrat
// ═══════════════════════════════════════════════════════════════════════════
class _ContractRequestSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  const _ContractRequestSheet({required this.profile});
  @override
  ConsumerState<_ContractRequestSheet> createState() => _ContractSheetState();
}

class _ContractSheetState extends ConsumerState<_ContractRequestSheet> {
  String _mode = 'regular';
  final List<String> _selectedServices = [];
  String _startDate = '';
  String _endDate   = '';
  String _address   = '';
  String _city      = '';
  String _note      = '';
  int _daysPerWeek  = 5;
  bool _submitting  = false;

  final _addrCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _addrCtrl.dispose(); _cityCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez au moins un service')));
      return;
    }
    if (_startDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez une date de début')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final profile = widget.profile;
      await api.post('/menagere/contracts', data: {
        'profileId': profile['id'],
        'workerId': profile['userId'],
        'mode': _mode,
        'services': _selectedServices,
        'startDate': _startDate,
        if (_endDate.isNotEmpty) 'endDate': _endDate,
        'daysPerWeek': _daysPerWeek,
        'address': _addrCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'clientNote': _noteCtrl.text.trim(),
        'salaireMensuel': profile['tarifMois'] ?? 0,
        'salaireJournalier': profile['tarifJour'] ?? 0,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Demande envoyée ! En attente de confirmation.'), backgroundColor: Color(0xFF16A34A)));
      }
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = _parseArray(widget.profile['services']);
    final salaireMensuel = _fmt(widget.profile['tarifMois']);
    final salaireJour    = _fmt(widget.profile['tarifJour']);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            Text('Demander ${widget.profile['fullName'] ?? 'la ménagère'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('$salaireMensuel FCFA/mois · $salaireJour FCFA/jour',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 20),

            // Mode
            _Label('Mode de contrat'),
            Row(children: [
              _ModeBtn(label: '1️⃣ Ponctuel',    value: 'once',    current: _mode, onTap: (v) => setState(() => _mode = v)),
              const SizedBox(width: 8),
              _ModeBtn(label: '🔄 Régulier',    value: 'regular', current: _mode, onTap: (v) => setState(() => _mode = v)),
              const SizedBox(width: 8),
              _ModeBtn(label: '🏠 Résidentiel', value: 'live_in', current: _mode, onTap: (v) => setState(() => _mode = v)),
            ]),
            const SizedBox(height: 14),

            // Services
            _Label('Services souhaités'),
            Wrap(spacing: 8, runSpacing: 8, children: services.map((s) {
              final meta = _servicesMeta[s] ?? {'emoji': '📦', 'label': s, 'color': 0xFF607D8B};
              final sel = _selectedServices.contains(s);
              return GestureDetector(
                onTap: () => setState(() => sel ? _selectedServices.remove(s) : _selectedServices.add(s)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? Color(meta['color'] as int) : Color(meta['color'] as int).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Color(meta['color'] as int).withOpacity(0.5)),
                  ),
                  child: Text('${meta['emoji']}  ${meta['label']}',
                    style: TextStyle(color: sel ? Colors.white : Color(meta['color'] as int),
                      fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),

            // Dates
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Label('Date de début *'),
                _DateField(value: _startDate, onChanged: (v) => setState(() => _startDate = v)),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Label('Date de fin'),
                _DateField(value: _endDate, onChanged: (v) => setState(() => _endDate = v)),
              ])),
            ]),
            const SizedBox(height: 14),

            // Jours/semaine
            _Label('Jours par semaine: $_daysPerWeek'),
            Slider(value: _daysPerWeek.toDouble(), min: 1, max: 7, divisions: 6,
              activeColor: _pink,
              onChanged: (v) => setState(() => _daysPerWeek = v.toInt())),
            const SizedBox(height: 14),

            // Adresse
            _Label('Adresse d\'intervention'),
            _FormField(controller: _addrCtrl, hint: 'Ex: Rue 1234, Bastos', onChanged: (v) => _address = v),
            const SizedBox(height: 10),
            _FormField(controller: _cityCtrl, hint: 'Ville (Yaoundé, Douala…)', onChanged: (v) => _city = v),
            const SizedBox(height: 14),

            // Note
            _Label('Note (optionnelle)'),
            _FormField(controller: _noteCtrl, hint: 'Informations supplémentaires…', maxLines: 3, onChanged: (v) => _note = v),
            const SizedBox(height: 24),

            // Bouton
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Envoyer la demande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS LOCAUX
// ═══════════════════════════════════════════════════════════════════════════

class _PhotoBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: _pink.withOpacity(0.2),
    child: const Center(child: Icon(Icons.person, size: 80, color: _pink)));
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))));
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)));
}

class _TarifCard extends StatelessWidget {
  final String label, value;
  const _TarifCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: _pink.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _pink)),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
    ]));
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatBox({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
    child: Column(children: [
      Icon(icon, size: 20, color: _pink),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ])));
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const CircleAvatar(radius: 16, backgroundColor: Color(0xFFF3F4F6),
          child: Icon(Icons.person, size: 18, color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(child: Text('Client', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 14,
          color: i < (review['rating'] as int? ?? 0) ? Colors.amber.shade600 : Colors.grey.shade300))),
      ]),
      if (review['comment'] != null && (review['comment'] as String).isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(review['comment'], style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4)),
      ],
    ]));
}

class _ModeBtn extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _ModeBtn({required this.label, required this.value, required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = value == current;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _pink : Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? _pink : Colors.grey.shade300)),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: sel ? Colors.white : Colors.grey.shade700)))));
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)));
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  const _FormField({required this.controller, required this.hint, this.maxLines = 1, this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, maxLines: maxLines, onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint, filled: true, fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    ));
}

class _DateField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _DateField({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final d = await showDatePicker(context: context,
        initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (_, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: _pink)), child: child!));
      if (d != null) onChanged('${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300)),
      child: Row(children: [
        Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text(value.isEmpty ? 'JJ/MM/AAAA' : value,
          style: TextStyle(color: value.isEmpty ? Colors.grey.shade400 : Colors.black87, fontSize: 13)),
      ])));
}

List<String> _parseArray(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => e.toString()).toList();
  if (v is String) return v.split(',').where((s) => s.isNotEmpty).toList();
  return [];
}

String _fmt(dynamic v) {
  final n = num.tryParse(v?.toString() ?? '') ?? 0;
  return n.toInt().toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}
