import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

const _cities = ['Yaoundé', 'Douala', 'Bafoussam', 'Garoua', 'Bamenda', 'Ngaoundéré', 'Bertoua', 'Ebolowa'];
const _langues = ['Français', 'Anglais', 'Duala', 'Ewondo', 'Bassa', 'Fulfulde', 'Bamiléké'];

// ═══════════════════════════════════════════════════════════════════════════
class MenagerePublishScreen extends ConsumerStatefulWidget {
  const MenagerePublishScreen({super.key});
  @override
  ConsumerState<MenagerePublishScreen> createState() => _State();
}

class _State extends ConsumerState<MenagerePublishScreen> {
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _bioCtrl      = TextEditingController();
  final _quartierCtrl = TextEditingController();
  final _tarifJourCtrl  = TextEditingController();
  final _tarifMoisCtrl  = TextEditingController();
  final _photoUrlCtrl   = TextEditingController();

  String? _city;
  int _experience = 0;
  final List<String> _services   = [];
  final List<String> _modes      = [];
  final List<String> _languages  = [];
  bool _childcareExp = false;
  bool _loading   = false;
  bool _hasProfile = false;
  int _step = 0;

  final _pageCtrl = PageController();

  @override
  void initState() { super.initState(); _loadExisting(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _bioCtrl.dispose();
    _quartierCtrl.dispose(); _tarifJourCtrl.dispose(); _tarifMoisCtrl.dispose();
    _photoUrlCtrl.dispose(); _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final res = await ref.read(apiClientProvider).get('/menagere/profiles/me');
      if (res.data is Map && res.data != null) {
        final p = Map<String, dynamic>.from(res.data);
        _nameCtrl.text     = p['fullName'] ?? '';
        _phoneCtrl.text    = p['phone'] ?? '';
        _bioCtrl.text      = p['bio'] ?? '';
        _quartierCtrl.text = p['quartier'] ?? '';
        _tarifJourCtrl.text  = (p['tarifJour'] ?? '').toString();
        _tarifMoisCtrl.text  = (p['tarifMois'] ?? '').toString();
        _photoUrlCtrl.text   = p['photoUrl'] ?? '';
        _city = p['city'];
        _experience = p['experienceYears'] ?? 0;
        _childcareExp = p['hasChildcareExperience'] ?? false;
        _services
          ..clear()
          ..addAll(_parseArray(p['services']));
        _modes
          ..clear()
          ..addAll(_parseArray(p['modes']));
        _languages
          ..clear()
          ..addAll(_parseArray(p['languages']));
        setState(() => _hasProfile = true);
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrez votre nom complet')));
      return;
    }
    if (_services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez au moins un service')));
      return;
    }
    if (_modes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez au moins un mode')));
      return;
    }
    setState(() => _loading = true);
    try {
      final data = {
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'city': _city,
        'quartier': _quartierCtrl.text.trim(),
        if (_photoUrlCtrl.text.isNotEmpty) 'photoUrl': _photoUrlCtrl.text.trim(),
        'services': _services,
        'modes': _modes,
        'languages': _languages,
        'hasChildcareExperience': _childcareExp,
        'experienceYears': _experience,
        if (_tarifJourCtrl.text.isNotEmpty) 'tarifJour': int.tryParse(_tarifJourCtrl.text) ?? 0,
        if (_tarifMoisCtrl.text.isNotEmpty) 'tarifMois': int.tryParse(_tarifMoisCtrl.text) ?? 0,
      };
      if (_hasProfile) {
        await ref.read(apiClientProvider).patch('/menagere/profiles/me', data: data);
      } else {
        await ref.read(apiClientProvider).post('/menagere/profiles', data: data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_hasProfile ? '✅ Profil mis à jour !' : '✅ Profil publié !'),
            backgroundColor: const Color(0xFF16A34A)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _prev() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F6),
      appBar: AppBar(
        title: Text(_hasProfile ? 'Modifier mon profil' : 'Devenir ménagère'),
        backgroundColor: _pink, foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
      body: Column(children: [
        // Steps indicator
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _StepDot(n: 1, active: _step >= 0, label: 'Infos'),
            _StepLine(active: _step >= 1),
            _StepDot(n: 2, active: _step >= 1, label: 'Services'),
            _StepLine(active: _step >= 2),
            _StepDot(n: 3, active: _step >= 2, label: 'Tarifs'),
          ]),
        ),

        Expanded(child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStep1(),
            _buildStep2(),
            _buildStep3(),
          ],
        )),

        // Boutons navigation
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))]),
          child: Row(children: [
            if (_step > 0) Expanded(flex: 1, child: OutlinedButton(
              onPressed: _prev,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _pink), foregroundColor: _pink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Retour'),
            )),
            if (_step > 0) const SizedBox(width: 10),
            Expanded(flex: 2, child: ElevatedButton(
              onPressed: _loading ? null : _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_step < 2 ? 'Continuer' : (_hasProfile ? 'Mettre à jour' : 'Publier mon profil'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            )),
          ]),
        ),
      ]),
    );
  }

  // ── Étape 1 : Informations personnelles ───────────────────────────────────
  Widget _buildStep1() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('Nom complet *'),
      _TF(controller: _nameCtrl, hint: 'Marie Dupont'),
      const SizedBox(height: 12),
      _Label('Téléphone'),
      _TF(controller: _phoneCtrl, hint: '+237 6XX XXX XXX', type: TextInputType.phone),
      const SizedBox(height: 12),
      _Label('URL photo de profil'),
      _TF(controller: _photoUrlCtrl, hint: 'https://...'),
      const SizedBox(height: 12),
      _Label('Ville *'),
      DropdownButtonFormField<String>(
        value: _city,
        hint: const Text('Sélectionnez une ville'),
        decoration: _inputDeco(),
        items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _city = v),
      ),
      const SizedBox(height: 12),
      _Label('Quartier'),
      _TF(controller: _quartierCtrl, hint: 'Bastos, Mvan, Bonamoussadi…'),
      const SizedBox(height: 12),
      _Label('Années d\'expérience: $_experience'),
      Slider(
        value: _experience.toDouble(), min: 0, max: 20, divisions: 20,
        activeColor: _pink,
        onChanged: (v) => setState(() => _experience = v.toInt())),
      const SizedBox(height: 12),
      _Label('Présentation'),
      TextField(
        controller: _bioCtrl, maxLines: 4,
        decoration: _inputDeco(hint: 'Parlez de vous, votre expérience, vos points forts…'),
      ),
      const SizedBox(height: 12),
      _Label('Langues parlées'),
      Wrap(spacing: 8, runSpacing: 8,
        children: _langues.map((l) {
          final sel = _languages.contains(l);
          return FilterChip(
            label: Text(l),
            selected: sel,
            onSelected: (v) => setState(() => v ? _languages.add(l) : _languages.remove(l)),
            selectedColor: _pink.withOpacity(0.15),
            checkmarkColor: _pink,
          );
        }).toList()),
    ]),
  );

  // ── Étape 2 : Services & modes ─────────────────────────────────────────────
  Widget _buildStep2() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('Services proposés * (plusieurs possibles)'),
      const SizedBox(height: 8),
      ..._servicesMeta.entries.map((e) {
        final sel = _services.contains(e.key);
        final color = Color(e.value['color'] as int);
        return GestureDetector(
          onTap: () => setState(() => sel ? _services.remove(e.key) : _services.add(e.key)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: sel ? color.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? color : Colors.grey.shade300, width: sel ? 1.5 : 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
            child: Row(children: [
              Text(e.value['emoji'] as String, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text(e.value['label'] as String,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: sel ? color : Colors.black87)),
              const Spacer(),
              if (sel) Icon(Icons.check_circle_rounded, color: color, size: 20)
              else Icon(Icons.circle_outlined, color: Colors.grey.shade300, size: 20),
            ]),
          ),
        );
      }),
      const SizedBox(height: 8),
      if (_services.contains('garde_enfants')) ...[
        CheckboxListTile(
          value: _childcareExp, activeColor: _pink,
          onChanged: (v) => setState(() => _childcareExp = v ?? false),
          title: const Text('Expérience confirmée en garde d\'enfants'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 8),
      _Label('Modes de travail * (plusieurs possibles)'),
      const SizedBox(height: 8),
      ...{
        'once':    {'label': 'Ponctuel (une seule fois)',    'emoji': '1️⃣'},
        'regular': {'label': 'Régulier (plusieurs fois/sem)','emoji': '🔄'},
        'live_in': {'label': 'Résidentiel (habite chez client)','emoji': '🏠'},
      }.entries.map((e) {
        final sel = _modes.contains(e.key);
        return GestureDetector(
          onTap: () => setState(() => sel ? _modes.remove(e.key) : _modes.add(e.key)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: sel ? _pink.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? _pink : Colors.grey.shade300, width: sel ? 1.5 : 1)),
            child: Row(children: [
              Text(e.value['emoji'] as String, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(e.value['label'] as String,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: sel ? _pink : Colors.black87))),
              if (sel) const Icon(Icons.check_circle_rounded, color: _pink, size: 20)
              else Icon(Icons.circle_outlined, color: Colors.grey.shade300, size: 20),
            ])),
        );
      }),
    ]),
  );

  // ── Étape 3 : Tarifs ───────────────────────────────────────────────────────
  Widget _buildStep3() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _pink.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _pink.withOpacity(0.2))),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: _pink, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Indiquez vos tarifs habituels. Le client pourra vous proposer un montant à la demande du contrat.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4))),
        ])),
      const SizedBox(height: 20),
      _Label('Tarif journalier (FCFA)'),
      _TF(controller: _tarifJourCtrl, hint: 'Ex: 5000', type: TextInputType.number),
      const SizedBox(height: 16),
      _Label('Tarif mensuel (FCFA)'),
      _TF(controller: _tarifMoisCtrl, hint: 'Ex: 80000', type: TextInputType.number),
      const SizedBox(height: 24),

      // Récap services sélectionnés
      if (_services.isNotEmpty) ...[
        _Label('Récapitulatif de votre profil'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('👩‍💼 ${_nameCtrl.text}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (_city != null) Text('📍 $_city ${_quartierCtrl.text.isNotEmpty ? '· ${_quartierCtrl.text}' : ''}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6,
              children: _services.map((s) {
                final meta = _servicesMeta[s] ?? {'emoji': '📦', 'label': s, 'color': 0xFF607D8B};
                return Chip(
                  label: Text('${meta['emoji']} ${meta['label']}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  backgroundColor: Color(meta['color'] as int).withOpacity(0.1),
                  side: BorderSide.none, padding: EdgeInsets.zero);
              }).toList()),
          ])),
      ],
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS LOCAUX
// ═══════════════════════════════════════════════════════════════════════════

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))));
}

class _TF extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType type;
  const _TF({required this.controller, required this.hint, this.type = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, keyboardType: type,
    decoration: _inputDeco(hint: hint));
}

InputDecoration _inputDeco({String? hint}) => InputDecoration(
  hintText: hint,
  filled: true, fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _pink)),
);

class _StepDot extends StatelessWidget {
  final int n;
  final bool active;
  final String label;
  const _StepDot({required this.n, required this.active, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
    AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: active ? _pink : Colors.grey.shade200,
        shape: BoxShape.circle),
      child: Center(child: Text('$n',
        style: TextStyle(color: active ? Colors.white : Colors.grey.shade400, fontWeight: FontWeight.bold)))),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(fontSize: 10, color: active ? _pink : Colors.grey.shade400, fontWeight: FontWeight.w600)),
  ]);
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 50, height: 2,
      color: active ? _pink : Colors.grey.shade200));
}

List<String> _parseArray(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => e.toString()).toList();
  if (v is String) return v.split(',').where((s) => s.isNotEmpty).toList();
  return [];
}
