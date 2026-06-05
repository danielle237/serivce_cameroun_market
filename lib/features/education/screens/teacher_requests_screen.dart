import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ÉCRAN PRINCIPAL — s'adapte au rôle de l'utilisateur connecté
// ─────────────────────────────────────────────────────────────────────────────
class TeacherRequestsScreen extends ConsumerWidget {
  const TeacherRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Erreur de chargement'))),
      data: (auth) {
        final activeMode = auth.user?['activeMode'] as String? ?? 'client';
        if (activeMode == 'provider') {
          return const _TeacherView();
        } else {
          return const _ParentView();
        }
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VUE PARENT
// ═════════════════════════════════════════════════════════════════════════════
class _ParentView extends StatefulWidget {
  const _ParentView();
  @override
  State<_ParentView> createState() => _ParentViewState();
}

class _ParentViewState extends State<_ParentView> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche d\'enseignant'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Publier une annonce'),
            Tab(icon: Icon(Icons.list_alt), text: 'Mes annonces'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _PublishForm(),
          _MyAnnouncements(),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VUE ENSEIGNANT
// ═════════════════════════════════════════════════════════════════════════════
class _TeacherView extends StatefulWidget {
  const _TeacherView();
  @override
  State<_TeacherView> createState() => _TeacherViewState();
}

class _TeacherViewState extends State<_TeacherView> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annonces de cours'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Annonces ouvertes'),
            Tab(icon: Icon(Icons.send), text: 'Mes propositions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _OpenAnnouncements(),
          _MyProposals(),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET PARENT 1 — Formulaire de publication
// ═════════════════════════════════════════════════════════════════════════════
class _PublishForm extends ConsumerStatefulWidget {
  const _PublishForm();
  @override
  ConsumerState<_PublishForm> createState() => _PublishFormState();
}

// Modèle d'un enfant dans le formulaire
class _ChildEntry {
  TextEditingController nameCtrl = TextEditingController();
  String? classLevel;
  List<String> subjects = [];
  TextEditingController descCtrl = TextEditingController();

  void dispose() { nameCtrl.dispose(); descCtrl.dispose(); }

  bool get isValid => nameCtrl.text.trim().isNotEmpty && classLevel != null && subjects.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'name': nameCtrl.text.trim(),
    'classLevel': classLevel,
    'subjects': subjects,
    'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
  };
}

class _PublishFormState extends ConsumerState<_PublishForm> {
  final _formKey = GlobalKey<FormState>();
  final _budgetCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _availCtrl = TextEditingController();
  String _billingCycle = 'monthly';
  String _mode = 'presential';
  int _sessionsPerWeek = 2;
  final List<String> _availabilities = [];
  bool _loading = false;

  // Multi-enfants
  final List<_ChildEntry> _children = [_ChildEntry()]; // 1 enfant par défaut

  static const _subjects = ['Mathématiques', 'Français', 'Physique-Chimie', 'SVT',
    'Histoire-Géographie', 'Anglais', 'Informatique', 'Philosophie', 'Économie', 'Autre'];
  static const _levels = ['CP', 'CE1', 'CE2', 'CM1', 'CM2', '6ème', '5ème', '4ème',
    '3ème', '2nde', '1ère', 'Terminale', 'Licence 1', 'Licence 2', 'Licence 3', 'Master'];

  @override
  void dispose() {
    for (final c in _children) c.dispose();
    _budgetCtrl.dispose(); _addressCtrl.dispose(); _availCtrl.dispose();
    super.dispose();
  }

  void _addChild() {
    if (_children.length >= 5) {
      _snack('Maximum 5 enfants par annonce', Colors.orange);
      return;
    }
    setState(() => _children.add(_ChildEntry()));
  }

  void _removeChild(int index) {
    if (_children.length == 1) return;
    _children[index].dispose();
    setState(() => _children.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_availabilities.isEmpty) {
      _snack('Ajoutez au moins une disponibilité', Colors.orange);
      return;
    }
    // Valider chaque enfant
    for (int i = 0; i < _children.length; i++) {
      if (!_children[i].isValid) {
        _snack('Complétez les informations de l\'enfant ${i + 1}', Colors.orange);
        return;
      }
    }
    if (_budgetCtrl.text.trim().isEmpty || int.tryParse(_budgetCtrl.text.trim()) == null) {
      _snack('Budget invalide', Colors.orange);
      return;
    }

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/education/requests', data: {
        'children': _children.map((c) => c.toJson()).toList(),
        'budgetPerSession': int.parse(_budgetCtrl.text.trim()),
        'billingCycle': _billingCycle,
        'sessionsPerWeek': _sessionsPerWeek,
        'availabilities': _availabilities,
        'locationAddress': _addressCtrl.text.trim(),
        'mode': _mode,
      });
      if (mounted) {
        final nb = _children.length;
        _snack(
          '✅ Annonce publiée pour $nb enfant${nb > 1 ? 's' : ''} ! '
          'Tous les enseignants W2D ont été notifiés par SMS.',
          Colors.green,
        );
        setState(() {
          for (final c in _children) c.dispose();
          _children.clear();
          _children.add(_ChildEntry());
          _budgetCtrl.clear(); _addressCtrl.clear();
          _billingCycle = 'monthly'; _mode = 'presential';
          _sessionsPerWeek = 2; _availabilities.clear();
        });
        _formKey.currentState!.reset();
      }
    } catch (_) {
      _snack('Erreur lors de la publication. Réessayez.', Colors.red);
    }
    setState(() => _loading = false);
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Bandeau info ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.family_restroom, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Ajoutez vos enfants un par un.\nChaque enfant peut avoir ses propres matières et niveau.\n'
                'Les enseignants verront la composition complète de la famille.',
                style: TextStyle(color: Colors.blue, fontSize: 13),
              )),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Section enfants ───────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              'Mes enfants (${_children.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (_children.length < 5)
              TextButton.icon(
                onPressed: _addChild,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Ajouter un enfant'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF1976D2)),
              ),
          ]),
          const SizedBox(height: 8),

          // Cartes par enfant
          ...List.generate(_children.length, (i) => _ChildCard(
            entry: _children[i],
            index: i,
            canRemove: _children.length > 1,
            onRemove: () => _removeChild(i),
            onChanged: () => setState(() {}),
            subjects: _subjects,
            levels: _levels,
          )),
          const SizedBox(height: 20),

          // ── Budget ─────────────────────────────────────────────────────────
          _label('Budget par séance (FCFA) *'),
          Text(
            _children.length > 1
                ? 'Budget global pour tous les enfants ensemble'
                : 'Budget pour une séance',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _budgetCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec(_children.length > 1 ? 'Ex: 10000 FCFA pour les ${_children.length} enfants' : 'Ex: 5000 FCFA'),
          ),
          const SizedBox(height: 14),

          // ── Type de paiement ───────────────────────────────────────────────
          _label('Type de paiement'),
          Row(children: [
            _cycleChip('daily', 'Journalier', Icons.today),
            const SizedBox(width: 8),
            _cycleChip('weekly', 'Hebdo', Icons.view_week),
            const SizedBox(width: 8),
            _cycleChip('monthly', 'Mensuel', Icons.calendar_month),
          ]),
          const SizedBox(height: 14),

          // ── Séances par semaine ────────────────────────────────────────────
          _label('Séances par semaine'),
          Row(children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF1976D2)),
              onPressed: () => setState(() { if (_sessionsPerWeek > 1) _sessionsPerWeek--; }),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1976D2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$_sessionsPerWeek', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1976D2)),
              onPressed: () => setState(() { if (_sessionsPerWeek < 7) _sessionsPerWeek++; }),
            ),
            Text('séance${_sessionsPerWeek > 1 ? 's' : ''}/semaine',
                style: const TextStyle(color: Colors.grey)),
          ]),
          const SizedBox(height: 14),

          // ── Mode de cours ──────────────────────────────────────────────────
          _label('Mode de cours'),
          Wrap(spacing: 8, children: [
            _modeChip('presential', 'Présentiel', Icons.home),
            _modeChip('online', 'En ligne', Icons.videocam),
            _modeChip('both', 'Les deux', Icons.swap_horiz),
          ]),
          const SizedBox(height: 14),

          // ── Adresse ────────────────────────────────────────────────────────
          _label('Adresse du domicile *'),
          TextFormField(
            controller: _addressCtrl,
            decoration: _dec('Quartier, ville...'),
            validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
          ),
          const SizedBox(height: 14),

          // ── Disponibilités ─────────────────────────────────────────────────
          _label('Vos disponibilités *'),
          TextField(
            controller: _availCtrl,
            decoration: _dec('Ex: Lundi 18h-20h, Samedi 09h-11h'),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) setState(() { _availabilities.add(v.trim()); _availCtrl.clear(); });
            },
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                final v = _availCtrl.text.trim();
                if (v.isNotEmpty) setState(() { _availabilities.add(v); _availCtrl.clear(); });
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter'),
            ),
          ),
          if (_availabilities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: _availabilities.map((a) => Chip(
                label: Text(a, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() => _availabilities.remove(a)),
                backgroundColor: Colors.blue.shade50,
              )).toList(),
            ),
          ],
          const SizedBox(height: 28),

          ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.campaign, size: 22),
            label: Text(
              _children.length > 1
                  ? 'Publier l\'annonce (${_children.length} enfants)'
                  : 'Publier l\'annonce',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)));

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));

  Widget _cycleChip(String value, String label, IconData icon) {
    final sel = _billingCycle == value;
    return GestureDetector(
      onTap: () => setState(() => _billingCycle = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1976D2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? const Color(0xFF1976D2) : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: sel ? Colors.white : Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.grey.shade700,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _modeChip(String value, String label, IconData icon) {
    final sel = _mode == value;
    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1976D2).withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? const Color(0xFF1976D2) : Colors.grey.shade300, width: sel ? 2 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: sel ? const Color(0xFF1976D2) : Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12,
              color: sel ? const Color(0xFF1976D2) : Colors.grey.shade700,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET PARENT 2 — Mes annonces publiées
// ═════════════════════════════════════════════════════════════════════════════
// ── Widget carte d'un enfant dans le formulaire ───────────────────────────────
class _ChildCard extends StatefulWidget {
  final _ChildEntry entry;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final List<String> subjects;
  final List<String> levels;

  const _ChildCard({
    required this.entry,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    required this.subjects,
    required this.levels,
  });

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final childColors = [
      const Color(0xFF1976D2),
      Colors.purple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
    ];
    final color = childColors[widget.index % childColors.length];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Column(children: [
        // En-tête de la carte enfant
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withOpacity(0.15),
                child: Text('${widget.index + 1}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 10),
              Expanded(child: entry.nameCtrl.text.isEmpty
                  ? Text('Enfant ${widget.index + 1}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade500))
                  : Text(entry.nameCtrl.text,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              // Badge matières
              if (entry.subjects.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.subjects.length == 1
                        ? entry.subjects.first
                        : '${entry.subjects.length} matières',
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              if (widget.canRemove)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: widget.onRemove,
                  tooltip: 'Supprimer',
                ),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
            ]),
          ),
        ),

        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Nom de l'enfant
              TextField(
                controller: entry.nameCtrl,
                onChanged: (_) { widget.onChanged(); setState(() {}); },
                decoration: InputDecoration(
                  labelText: 'Prénom de l\'enfant *',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Niveau scolaire
              DropdownButtonFormField<String>(
                value: entry.classLevel,
                decoration: InputDecoration(
                  labelText: 'Niveau scolaire *',
                  prefixIcon: const Icon(Icons.school_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: widget.levels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) { setState(() => entry.classLevel = v); widget.onChanged(); },
              ),
              const SizedBox(height: 12),

              // Matières (multi-sélection)
              const Text('Matières *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: widget.subjects.map((s) {
                  final sel = entry.subjects.contains(s);
                  return FilterChip(
                    label: Text(s, style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : Colors.black87,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                    selected: sel,
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: color,
                    checkmarkColor: Colors.white,
                    onSelected: (v) {
                      setState(() {
                        if (v) entry.subjects.add(s);
                        else entry.subjects.remove(s);
                      });
                      widget.onChanged();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Description optionnelle
              TextField(
                controller: entry.descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Difficultés ou objectifs (optionnel)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _MyAnnouncements extends ConsumerStatefulWidget {
  const _MyAnnouncements();
  @override
  ConsumerState<_MyAnnouncements> createState() => _MyAnnouncementsState();
}

class _MyAnnouncementsState extends ConsumerState<_MyAnnouncements> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/education/requests/mine', forceRefresh: true);
      final data = res.data;
      setState(() {
        _items = data is List ? data : (data['data'] ?? data['items'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 13)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
      ]));
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.folder_open_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Aucune annonce publiée', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 6),
          Text('Allez dans "Publier une annonce" pour commencer',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) => _AnnouncementCard(
          data: Map<String, dynamic>.from(_items[i]),
          onRefresh: _load,
        ),
      ),
    );
  }
}

// ─── Carte d'une annonce (vue parent) ────────────────────────────────────────
class _AnnouncementCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;
  const _AnnouncementCard({required this.data, required this.onRefresh});
  @override
  ConsumerState<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends ConsumerState<_AnnouncementCard> {
  bool _expanded = false;
  bool _actLoading = false;
  // État local du statut — mis à jour immédiatement après toggle (sans attendre le reload)
  late String _localStatus;

  @override
  void initState() {
    super.initState();
    _localStatus = widget.data['status'] as String? ?? 'open';
  }

  Widget _buildChildrenTitle(Map<String, dynamic> r) {
    final children = r['children'] as List?;
    if (children != null && children.isNotEmpty) {
      if (children.length == 1) {
        final c = children[0] as Map<String, dynamic>;
        final subjects = (c['subjects'] as List?)?.join(' · ') ?? '';
        return Text('${c['name']} — ${c['classLevel']}${subjects.isNotEmpty ? '\n$subjects' : ''}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Famille · ${children.length} enfants',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        ...children.take(3).map((c) {
          final child = c as Map<String, dynamic>;
          final subjects = (child['subjects'] as List?)?.take(2).join(', ') ?? '';
          return Text('• ${child['name']} — ${child['classLevel']}${subjects.isNotEmpty ? ' ($subjects)' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.black87));
        }),
        if (children.length > 3)
          Text('+ ${children.length - 3} autre(s)…',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]);
    }
    return Text('${r['subject'] ?? ''} — ${r['classLevel'] ?? ''}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));
  }

  Color _sColor(String s) => {'open': Colors.green, 'paused': Colors.orange,
    'filled': Colors.blue, 'cancelled': Colors.red}[s] ?? Colors.grey;
  String _sLabel(String s) => {'open': '● Active', 'paused': '⏸ En pause',
    'filled': '✓ Pourvue', 'cancelled': '✗ Annulée'}[s] ?? s;
  String _bLabel(String s) => {'daily': 'Journalier', 'weekly': 'Hebdo', 'monthly': 'Mensuel'}[s] ?? s;

  Future<void> _toggle() async {
    setState(() => _actLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.patch('/education/requests/${widget.data['id']}/toggle');
      final newStatus = res.data['status'] as String? ?? (_localStatus == 'open' ? 'paused' : 'open');
      if (mounted) {
        // Mise à jour immédiate du bouton sans attendre le reload
        setState(() => _localStatus = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.data['message'] ?? 'Statut mis à jour'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (mounted) setState(() => _actLoading = false);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Confirmer l\'annulation'),
      content: const Text('Voulez-vous annuler définitivement cette annonce ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Oui, annuler')),
      ],
    ));
    if (ok != true) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/education/requests/${widget.data['id']}/cancel');
      if (mounted) widget.onRefresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur annulation: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _edit() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditSheet(data: widget.data, onSaved: widget.onRefresh),
  );

  Future<void> _acceptContract(String applicationId) async {
    setState(() => _actLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      // Accepte la candidature → crée le contrat + ferme l'annonce
      await api.patch(
        '/education/requests/${widget.data['id']}/applications/$applicationId/accept',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Contrat créé — l\'enseignant a été notifié'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
    setState(() => _actLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.data;
    // Utilise _localStatus pour refléter les changements immédiats après toggle
    final status = _localStatus;
    final apps = r['applications'] as List? ?? [];
    final pendingApps = apps.where((a) => a['status'] == 'pending').toList();
    final canEdit = status == 'open' || status == 'paused';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.school, color: Color(0xFF1976D2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChildrenTitle(r),
                      const SizedBox(height: 2),
                      Text('${r['budgetPerSession']} FCFA · ${_bLabel(r['billingCycle'] ?? 'monthly')}',
                          style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      Text(r['locationAddress'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_sLabel(status),
                        style: TextStyle(color: _sColor(status), fontSize: 12, fontWeight: FontWeight.bold)),
                    if (pendingApps.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                        child: Text('${pendingApps.length} proposition${pendingApps.length > 1 ? 's' : ''}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Boutons d'action ─────────────────────────────────────────────
          if (canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  _actionBtn(Icons.edit_outlined, 'Modifier', Colors.blue, _edit),
                  const SizedBox(width: 8),
                  _actionBtn(
                    status == 'open' ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    status == 'open' ? 'Désactiver' : 'Activer',
                    status == 'open' ? Colors.orange : Colors.green,
                    _actLoading ? null : _toggle,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _actLoading ? null : _cancel,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Annuler l\'annonce',
                  ),
                ],
              ),
            ),

          // ── Propositions de contrat des enseignants ───────────────────────
          if (apps.isNotEmpty) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_outlined, size: 18, color: Color(0xFF1976D2)),
                    const SizedBox(width: 8),
                    Text(
                      '${apps.length} proposition${apps.length > 1 ? 's' : ''} de contrat',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1976D2)),
                    ),
                    const Spacer(),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: apps.map<Widget>((app) => _ContractProposalTile(
                    app: Map<String, dynamic>.from(app),
                    requestStatus: status,
                    requestId: widget.data['id'] as String,
                    onAccept: () => _acceptContract(app['id'] as String),
                    onReject: () async {
                      final api = ref.read(apiClientProvider);
                      await api.patch('/education/requests/${widget.data['id']}/applications/${app['id']}/reject');
                      widget.onRefresh();
                    },
                    onRefresh: widget.onRefresh,
                  )).toList(),
                ),
              ),
            ],
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Text(
                status == 'open'
                    ? 'En attente de propositions d\'enseignants...'
                    : 'Aucune proposition reçue',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

// ─── Tuile proposition de contrat (vue parent) ────────────────────────────────
class _ContractProposalTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> app;
  final String requestStatus;
  final String requestId;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onRefresh;
  const _ContractProposalTile({required this.app, required this.requestStatus,
    required this.requestId, required this.onAccept, required this.onReject,
    required this.onRefresh});

  @override
  ConsumerState<_ContractProposalTile> createState() => _ContractProposalTileState();
}

class _ContractProposalTileState extends ConsumerState<_ContractProposalTile> {
  bool _proposingRate = false;

  Future<void> _proposeFinalRate() async {
    final ctrl = TextEditingController(
        text: widget.app['proposedRate']?.toString() ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('💰 Proposer un devis final'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proposition initiale : ${widget.app['proposedRate']} FCFA/séance',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Votre tarif final (FCFA/séance)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixText: 'FCFA',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "L'enseignant recevra une notification et devra valider ce tarif pour créer le contrat.",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final rate = int.tryParse(ctrl.text.trim());
    if (rate == null || rate <= 0) return;

    setState(() => _proposingRate = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch(
        '/education/requests/${widget.requestId}/applications/${widget.app['id']}/propose-rate',
        data: {'finalRate': rate},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Devis final envoyé — en attente de validation'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _proposingRate = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final teacher = app['teacher'] as Map<String, dynamic>?;
    final appStatus = app['status'] as String? ?? 'pending';
    final finalRateStatus = app['finalRateStatus'] as String? ?? 'none';
    final finalRate = app['finalRate'];
    final colors = {'pending': Colors.orange, 'accepted': Colors.green, 'rejected': Colors.grey};
    final labels = {'pending': 'En attente', 'accepted': '✓ Accepté', 'rejected': 'Rejeté'};

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: appStatus == 'accepted' ? Colors.green.shade200 : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
        color: appStatus == 'accepted' ? Colors.green.shade50 : Colors.grey.shade50,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo de profil
          Stack(children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: teacher?['profilePhotoUrl'] != null
                  ? NetworkImage(teacher!['profilePhotoUrl']) : null,
              backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
              child: teacher?['profilePhotoUrl'] == null
                  ? const Icon(Icons.person, size: 28, color: Color(0xFF1976D2)) : null,
            ),
            if (teacher?['trustScore'] != null && (teacher!['trustScore'] as num) >= 80)
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.verified, size: 10, color: Colors.white),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    final id = teacher?['id'] as String?;
                    if (id != null) context.push('/education/portfolio/$id');
                  },
                  child: Text(
                    teacher?['name'] ?? 'Enseignant',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15,
                      color: Color(0xFF1976D2),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (colors[appStatus] ?? Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors[appStatus] ?? Colors.grey),
                ),
                child: Text(labels[appStatus] ?? appStatus,
                    style: TextStyle(color: colors[appStatus], fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 4),
            // Ville + Trust Score
            Row(children: [
              if (teacher?['city'] != null) ...[
                const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                const SizedBox(width: 2),
                Text(teacher!['city'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
              ],
              if (teacher?['trustScore'] != null) ...[
                const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                const SizedBox(width: 2),
                Text('${teacher!['trustScore']}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              ],
            ]),
            // Séances complétées
            if (teacher?['completedSessions'] != null || teacher?['totalSessions'] != null) ...[
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.check_circle_outline, size: 12, color: Colors.green),
                const SizedBox(width: 3),
                Text(
                  '${teacher?['completedSessions'] ?? teacher?['totalSessions'] ?? 0} séances effectuées',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
              ]),
            ],
          ])),
        ]),
        if (app['proposedRate'] != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.attach_money, size: 16, color: Color(0xFF1976D2)),
            Text(' ${app['proposedRate']} FCFA/séance — Proposition de l\'enseignant',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1976D2))),
          ]),
        ],
        if (app['message'] != null && app['message'].toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(app['message'], style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
        // ── Statut devis final ──────────────────────────────────────────
        if (finalRateStatus == 'proposed' && finalRate != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.schedule, size: 16, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(child: Text(
                '⏳ Devis final de $finalRate FCFA/séance envoyé — en attente de validation par l\'enseignant',
                style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
              )),
            ]),
          ),
        ] else if (finalRateStatus == 'confirmed') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(child: Text(
                '✅ Devis de $finalRate FCFA/séance validé — contrat créé !',
                style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
              )),
            ]),
          ),
        ],

        if (appStatus == 'pending' && widget.requestStatus == 'open') ...[
          const SizedBox(height: 12),
          // Bouton Refuser
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: widget.onReject,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Refuser'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
            )),
            const SizedBox(width: 10),
            // Bouton Proposer devis final
            if (finalRateStatus == 'none' || finalRateStatus == 'rejected')
              Expanded(child: ElevatedButton.icon(
                onPressed: _proposingRate ? null : _proposeFinalRate,
                icon: _proposingRate
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.price_change_outlined, size: 16),
                label: const Text('Proposer devis'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
              ))
            else if (finalRateStatus == 'proposed')
              Expanded(child: OutlinedButton.icon(
                onPressed: _proposingRate ? null : _proposeFinalRate,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Modifier devis'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1976D2),
                    side: const BorderSide(color: Color(0xFF1976D2))),
              )),
          ]),
        ],

        // Bouton message — toujours visible sauf rejeté
        if (appStatus != 'rejected') ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          TextButton.icon(
            onPressed: () {
              final teacherId = app['teacher']?['id'] as String?;
              if (teacherId != null) {
                context.push(
                  '/messages/chat/$teacherId',
                  extra: {
                    'applicationId': app['id'] as String?,
                    'applicationData': {
                      ...Map<String, dynamic>.from(app),
                      'requestId': widget.requestId,
                    },
                  },
                );
              }
            },
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: Text(appStatus == 'accepted'
                ? 'Messagerie avec l\'enseignant'
                : 'Discuter du devis'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF1976D2)),
          ),
        ],
      ]),
    );
  }
}

// ─── Sheet de modification ────────────────────────────────────────────────────
class _EditSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onSaved;
  const _EditSheet({required this.data, required this.onSaved});
  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descCtrl;
  late TextEditingController _budgetCtrl;
  late TextEditingController _addressCtrl;
  final _availCtrl = TextEditingController();
  late String _billingCycle;
  late String _mode;
  late int _sessionsPerWeek;
  late List<String> _availabilities;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _descCtrl = TextEditingController(text: d['description'] ?? '');
    _budgetCtrl = TextEditingController(text: d['budgetPerSession']?.toString() ?? '');
    _addressCtrl = TextEditingController(text: d['locationAddress'] ?? '');
    _billingCycle = d['billingCycle'] ?? 'monthly';
    _mode = d['mode'] ?? 'presential';
    _sessionsPerWeek = d['sessionsPerWeek'] ?? 2;
    _availabilities = List<String>.from(d['availabilities'] ?? []);
  }

  @override
  void dispose() {
    _descCtrl.dispose(); _budgetCtrl.dispose();
    _addressCtrl.dispose(); _availCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/education/requests/${widget.data['id']}', data: {
        'description': _descCtrl.text.trim(),
        'budgetPerSession': int.parse(_budgetCtrl.text.trim()),
        'billingCycle': _billingCycle,
        'sessionsPerWeek': _sessionsPerWeek,
        'availabilities': _availabilities,
        'locationAddress': _addressCtrl.text.trim(),
        'mode': _mode,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Annonce modifiée ✅'), backgroundColor: Colors.green));
        widget.onSaved();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur lors de la modification'), backgroundColor: Colors.red));
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
          const Text('Modifier l\'annonce', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(child: Form(
            key: _formKey,
            child: ListView(controller: ctrl, padding: const EdgeInsets.all(16), children: [
              _tf('Description', _descCtrl, hint: 'Objectifs, difficultés...', lines: 3),
              const SizedBox(height: 14),
              _tf('Budget/séance (FCFA) *', _budgetCtrl, hint: '5000', type: TextInputType.number,
                  validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalide' : null),
              const SizedBox(height: 14),
              const Text('Type de paiement', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'daily', label: Text('Journalier')),
                  ButtonSegment(value: 'weekly', label: Text('Hebdo')),
                  ButtonSegment(value: 'monthly', label: Text('Mensuel')),
                ],
                selected: {_billingCycle},
                onSelectionChanged: (s) => setState(() => _billingCycle = s.first),
              ),
              const SizedBox(height: 14),
              const Text('Séances/semaine', style: TextStyle(fontWeight: FontWeight.w600)),
              Row(children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() { if (_sessionsPerWeek > 1) _sessionsPerWeek--; })),
                Text('$_sessionsPerWeek', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() { if (_sessionsPerWeek < 7) _sessionsPerWeek++; })),
              ]),
              const SizedBox(height: 14),
              const Text('Mode', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'presential', label: Text('Présentiel')),
                  ButtonSegment(value: 'online', label: Text('En ligne')),
                  ButtonSegment(value: 'both', label: Text('Les deux')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 14),
              _tf('Adresse *', _addressCtrl, hint: 'Quartier, ville...',
                  validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null),
              const SizedBox(height: 14),
              const Text('Disponibilités', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _availCtrl,
                decoration: InputDecoration(
                  hintText: 'Lundi 18h-20h',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) setState(() { _availabilities.add(v.trim()); _availCtrl.clear(); });
                },
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final v = _availCtrl.text.trim();
                    if (v.isNotEmpty) setState(() { _availabilities.add(v); _availCtrl.clear(); });
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter'),
                ),
              ),
              if (_availabilities.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: _availabilities.map((a) => Chip(
                  label: Text(a, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _availabilities.remove(a)),
                  backgroundColor: Colors.blue.shade50,
                )).toList()),
              ],
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: const Text('Enregistrer', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _tf(String label, TextEditingController ctrl,
      {String? hint, int lines = 1, TextInputType? type, String? Function(String?)? validator}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl, maxLines: lines, keyboardType: type, validator: validator,
        decoration: InputDecoration(hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      ),
    ]);
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET ENSEIGNANT 1 — Annonces ouvertes
// ═════════════════════════════════════════════════════════════════════════════
class _OpenAnnouncements extends ConsumerStatefulWidget {
  const _OpenAnnouncements();
  @override
  ConsumerState<_OpenAnnouncements> createState() => _OpenAnnouncementsState();
}

class _OpenAnnouncementsState extends ConsumerState<_OpenAnnouncements> {
  List<dynamic> _items = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? subject, bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/education/requests',
          params: (subject != null && subject.isNotEmpty) ? {'subject': subject} : null,
          forceRefresh: true);
      if (mounted) setState(() { _items = List.from(res.data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher par matière...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(icon: const Icon(Icons.clear),
                onPressed: () { _searchCtrl.clear(); _load(); }),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          ),
          onSubmitted: (_) => _load(),
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('Aucune annonce disponible', style: TextStyle(color: Colors.grey)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _OpenAnnouncementCard(
                        data: Map<String, dynamic>.from(_items[i]),
                        onRefresh: _load,
                      ),
                    ),
                  ),
      ),
    ]);
  }
}

// ─── Carte annonce vue enseignant ─────────────────────────────────────────────
class _OpenAnnouncementCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;
  const _OpenAnnouncementCard({required this.data, required this.onRefresh});
  @override
  ConsumerState<_OpenAnnouncementCard> createState() => _OpenAnnouncementCardState();
}

class _OpenAnnouncementCardState extends ConsumerState<_OpenAnnouncementCard> {
  bool _loading = false;

  String _bLabel(String s) => {'daily': 'Journalier', 'weekly': 'Hebdo', 'monthly': 'Mensuel'}[s] ?? s;

  Future<void> _sendProposal() async {
    final r = widget.data;
    final children = r['children'] as List? ?? [];
    final isFamily = children.length > 1;

    final rateCtrl = TextEditingController(text: r['budgetPerSession']?.toString() ?? '');
    final msgCtrl = TextEditingController();
    String pricingMode = 'family';
    // Contrôleurs de tarif par enfant
    final childRateCtrls = children.map((_) =>
        TextEditingController(text: r['budgetPerSession']?.toString() ?? '')).toList();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(isFamily ? 'Proposition famille' : 'Envoyer une proposition'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (isFamily) ...[
              // Mode de tarification
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mode de tarification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _modeBtn(ctx, setDlgState, 'family', 'Forfait famille', Icons.family_restroom, pricingMode,
                        (v) => setDlgState(() => pricingMode = v))),
                    const SizedBox(width: 8),
                    Expanded(child: _modeBtn(ctx, setDlgState, 'per_child', 'Par enfant', Icons.person, pricingMode,
                        (v) => setDlgState(() => pricingMode = v))),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            if (!isFamily || pricingMode == 'family') ...[
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isFamily ? 'Tarif forfait famille/séance (FCFA)' : 'Votre tarif/séance (FCFA)',
                  hintText: 'Budget parent: ${r['budgetPerSession']} FCFA',
                  border: const OutlineInputBorder(),
                ),
              ),
            ] else ...[
              // Tarif par enfant
              ...List.generate(children.length, (i) {
                final child = children[i] as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: childRateCtrls[i],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${child['name']} — ${child['classLevel']} (FCFA/séance)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl, maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message de présentation (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'Le parent recevra votre proposition et pourra discuter avec vous avant d\'accepter.',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
              child: const Text('Envoyer la proposition'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);

      // Construire childrenRates si per_child
      final childrenRates = (isFamily && pricingMode == 'per_child')
          ? List.generate(children.length, (i) {
              final child = children[i] as Map<String, dynamic>;
              return {
                'childName': child['name'],
                'childIndex': i,
                'ratePerSession': int.tryParse(childRateCtrls[i].text.trim()) ?? 0,
              };
            })
          : <Map<String, dynamic>>[];

      final totalRate = pricingMode == 'per_child'
          ? childrenRates.fold<int>(0, (s, c) => s + (c['ratePerSession'] as int))
          : int.tryParse(rateCtrl.text.trim());

      await api.post('/education/requests/${widget.data['id']}/apply', data: {
        if (msgCtrl.text.trim().isNotEmpty) 'message': msgCtrl.text.trim(),
        'proposedRate': totalRate,
        'pricingMode': isFamily ? pricingMode : 'family',
        if (childrenRates.isNotEmpty) 'childrenRates': childrenRates,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Proposition envoyée ! Le parent a été notifié par SMS.'),
          backgroundColor: Colors.green));
        widget.onRefresh();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vous avez déjà envoyé une proposition à ce parent'),
        backgroundColor: Colors.orange));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.data;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _buildFamilyTitle(r)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
              child: const Text('Ouverte', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 10),
          // Enfants détaillés
          _buildChildrenDetails(r),
          const SizedBox(height: 6),
          _row(Icons.attach_money, '${r['budgetPerSession']} FCFA · ${_bLabel(r['billingCycle'] ?? 'monthly')}'),
          _row(Icons.repeat, '${r['sessionsPerWeek']} séance${(r['sessionsPerWeek'] ?? 1) > 1 ? 's' : ''}/semaine'),
          _row(Icons.location_on, r['locationAddress'] ?? ''),
          _row(Icons.videocam_outlined, r['mode'] == 'online' ? 'En ligne' : r['mode'] == 'both' ? 'Présentiel & En ligne' : 'Présentiel'),
          if (r['availabilities'] != null && (r['availabilities'] as List).isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: (r['availabilities'] as List).map((a) =>
              Chip(label: Text(a.toString(), style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.blue.shade50, padding: EdgeInsets.zero)
            ).toList()),
          ],
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _loading ? null : _sendProposal,
            icon: _loading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: const Text('Envoyer une proposition de contrat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _modeBtn(BuildContext ctx, StateSetter set, String value, String label, IconData icon,
      String current, void Function(String) onTap) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1976D2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? const Color(0xFF1976D2) : Colors.grey.shade300),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: sel ? Colors.white : Colors.grey),
          const SizedBox(width: 4),
          Flexible(child: Text(label,
              style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.grey.shade700,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
        ]),
      ),
    );
  }

  Widget _buildFamilyTitle(Map<String, dynamic> r) {
    final children = r['children'] as List?;
    if (children != null && children.length > 1) {
      return Text('Famille · ${children.length} enfants',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
    }
    if (children != null && children.length == 1) {
      final c = children[0] as Map<String, dynamic>;
      return Text('${c['name']} — ${c['classLevel']}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
    }
    return Text('${r['subject'] ?? ''} — ${r['classLevel'] ?? ''}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
  }

  Widget _buildChildrenDetails(Map<String, dynamic> r) {
    final children = r['children'] as List?;
    if (children == null || children.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.map<Widget>((c) {
          final child = c as Map<String, dynamic>;
          final subjects = (child['subjects'] as List?)?.join(' · ') ?? '';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${children.indexOf(c) + 1}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${child['name']} — ${child['classLevel']}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (subjects.isNotEmpty)
                  Text(subjects, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                if (child['description'] != null && child['description'].toString().isNotEmpty)
                  Text(child['description'].toString(),
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
              ])),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.grey),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87))),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET ENSEIGNANT 2 — Mes propositions envoyées
// ═════════════════════════════════════════════════════════════════════════════
class _MyProposals extends ConsumerStatefulWidget {
  const _MyProposals();
  @override
  ConsumerState<_MyProposals> createState() => _MyProposalsState();
}

class _MyProposalsState extends ConsumerState<_MyProposals> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Mise à jour temps réel — rafraîchit toutes les 30 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _validateFinalRate(Map<String, dynamic> item) async {
    final requestId = (item['request']?['id'] ?? item['requestId']) as String?;
    final appId     = item['id'] as String?;
    if (requestId == null || appId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Valider le devis final ?'),
        content: Text(
          'En validant, vous acceptez le tarif de ${item['finalRate']} FCFA/séance.\n'
          'Un contrat sera créé et l\'annonce sera retirée aux autres enseignants.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Oui, valider'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/education/requests/$requestId/applications/$appId/validate-rate');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 Contrat créé ! Le parent a été notifié.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _withdrawProposal(Map<String, dynamic> item) async {
    final requestId = (item['request']?['id'] ?? item['requestId']) as String?;
    final appId     = item['id'] as String?;
    if (requestId == null || appId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Retirer la candidature ?'),
        content: const Text('Votre proposition sera supprimée. Le parent ne pourra plus vous contacter via cette annonce.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/education/requests/$requestId/applications/$appId/withdraw');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Candidature retirée'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/education/requests/my-proposals',
          forceRefresh: true);
      final data = res.data;
      if (mounted) setState(() {
        _items = data is List ? data : (data['data'] ?? data['items'] ?? []);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 64, color: Colors.red),
      const SizedBox(height: 12),
      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 13)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: () => _load(), child: const Text('Réessayer')),
    ]));
    if (_items.isEmpty) return const Center(
        child: Text('Aucune proposition envoyée', style: TextStyle(color: Colors.grey)));
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = Map<String, dynamic>.from(_items[i]);
          final request = item['request'] as Map<String, dynamic>?;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  request != null ? '${request['subject']} — ${request['classLevel']}' : 'Annonce',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (request?['locationAddress'] != null) ...[
                  const SizedBox(height: 4),
                  Text(request!['locationAddress'], style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(item['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _statusColor(item['status'])),
                    ),
                    child: Text(_statusLabel(item['status']),
                        style: TextStyle(color: _statusColor(item['status']), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  if (item['proposedRate'] != null) ...[
                    const SizedBox(width: 10),
                    Text('${item['proposedRate']} FCFA/séance',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1976D2))),
                  ],
                ]),
                if (item['message'] != null && item['message'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(item['message'],
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],

                // ── Devis final proposé par le parent ──────────────────────
                if (item['finalRateStatus'] == 'proposed' && item['finalRate'] != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.price_change, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Le parent propose un devis final de ${item['finalRate']} FCFA/séance',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        )),
                      ]),
                      const SizedBox(height: 4),
                      const Text(
                        'Validez ce tarif pour créer le contrat. Les autres enseignants ne pourront plus postuler.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _validateFinalRate(item),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('✅ Valider le devis et créer le contrat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],

                // Actions sur la proposition (si pending)
                if (item['status'] == 'pending') ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  // Ligne 1 : Modifier + Discuter
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditSheet(item),
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1976D2),
                          side: const BorderSide(color: Color(0xFF1976D2)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final parentId = item['request']?['clientId'] as String?
                              ?? item['clientId'] as String?;
                          if (parentId != null) {
                            context.push('/messages/chat/$parentId', extra: {
                              'applicationData': {
                                ...Map<String, dynamic>.from(item),
                                'requestId': item['request']?['id'] ?? item['requestId'],
                              },
                            });
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 15),
                        label: const Text('Discuter', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  // Ligne 2 : Supprimer (retirer la candidature)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _withdrawProposal(item),
                      icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                      label: const Text('Retirer ma candidature',
                          style: TextStyle(fontSize: 12, color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],

                // Si accepté — messagerie + cours d'essai
                if (item['status'] == 'accepted') ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          final parentId = item['request']?['clientId'] as String?
                              ?? item['clientId'] as String?;
                          if (parentId != null) context.push('/messages/chat/$parentId');
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 15),
                        label: const Text('Messagerie', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: Colors.green),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _showTrialSessionSheet(context, item),
                        icon: const Icon(Icons.card_giftcard_outlined, size: 15),
                        label: const Text('Cours d\'essai', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: Colors.purple),
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  void _showTrialSessionSheet(BuildContext context, Map<String, dynamic> item) {
    final clientId = item['request']?['clientId'] as String?
        ?? item['clientId'] as String?;
    if (clientId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrialSessionSheet(
        clientId: clientId,
        clientName: item['request']?['parentName'] as String? ?? 'Parent',
        onProposed: () => _load(),
      ),
    );
  }

  void _openEditSheet(Map<String, dynamic> item) {
    final requestId = item['request']?['id'] as String? ?? item['requestId'] as String?;
    if (requestId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProposalSheet(
        application: item,
        requestId: requestId,
        applicationId: item['id'] as String,
        onSaved: () => _load(),
      ),
    );
  }

  Color _statusColor(String? s) => {
    'pending': Colors.orange,
    'accepted': Colors.green,
    'rejected': Colors.grey,
  }[s] ?? Colors.grey;

  String _statusLabel(String? s) => {
    'pending': '⏳ En attente',
    'accepted': '✅ Accepté',
    'rejected': '❌ Rejeté',
  }[s] ?? (s ?? '');
}

// ── Bottom sheet modification proposition enseignant ──────────────────────────
class _EditProposalSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> application;
  final String requestId;
  final String applicationId;
  final VoidCallback onSaved;

  const _EditProposalSheet({
    required this.application,
    required this.requestId,
    required this.applicationId,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditProposalSheet> createState() => _EditProposalSheetState();
}

class _EditProposalSheetState extends ConsumerState<_EditProposalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _rateCtrl;
  late final TextEditingController _messageCtrl;
  late final TextEditingController _scheduleCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rateCtrl     = TextEditingController(text: '${widget.application['proposedRate'] ?? ''}');
    _messageCtrl  = TextEditingController(text: widget.application['message'] as String? ?? '');
    _scheduleCtrl = TextEditingController(text: widget.application['proposedSchedule'] as String? ?? '');
  }

  @override
  void dispose() {
    _rateCtrl.dispose(); _messageCtrl.dispose(); _scheduleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).patch(
        '/education/requests/${widget.requestId}/applications/${widget.applicationId}',
        data: {
          'proposedRate': int.tryParse(_rateCtrl.text.trim()),
          'message': _messageCtrl.text.trim(),
          'proposedSchedule': _scheduleCtrl.text.trim(),
        },
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Proposition mise à jour'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(
            margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              const Text('Modifier ma proposition',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _rateCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Tarif proposé (FCFA/séance)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixText: 'FCFA',
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Message pour le parent',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _scheduleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Disponibilités proposées',
                      hintText: 'Ex: Lundi 17h, Mercredi 15h',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Enregistrer',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Bottom sheet cours d'essai ──────────────────────────────────────────────
class _TrialSessionSheet extends ConsumerStatefulWidget {
  final String clientId;
  final String clientName;
  final VoidCallback onProposed;
  const _TrialSessionSheet({
    required this.clientId,
    required this.clientName,
    required this.onProposed,
  });

  @override
  ConsumerState<_TrialSessionSheet> createState() => _TrialSessionSheetState();
}

class _TrialSessionSheetState extends ConsumerState<_TrialSessionSheet> {
  final _dateCtrl    = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() { _dateCtrl.dispose(); _messageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(
            margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              const Text('Proposer un cours d\'essai',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(children: [
                TextField(
                  controller: _dateCtrl,
                  decoration: InputDecoration(
                    labelText: 'Date et heure proposées',
                    hintText: 'Ex: Samedi 15 juin à 10h',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Message (optionnel)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: const Text('Envoyer la proposition'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _send() async {
    if (_dateCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/education/sessions/trial', data: {
        'clientId': widget.clientId,
        'proposedDate': _dateCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Cours d\'essai proposé — le parent a été notifié'),
          backgroundColor: Colors.purple,
          behavior: SnackBarBehavior.floating,
        ));
        widget.onProposed();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _sending = false);
  }
}
