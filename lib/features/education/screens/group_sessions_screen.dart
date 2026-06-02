import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';

class GroupSessionsScreen extends ConsumerStatefulWidget {
  const GroupSessionsScreen({super.key});

  @override
  ConsumerState<GroupSessionsScreen> createState() => _GroupSessionsScreenState();
}

class _GroupSessionsScreenState extends ConsumerState<GroupSessionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  bool get _isTeacher =>
      ref.read(authStateProvider).value?.user?['activeMode'] == 'provider';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/education/group-sessions');
      final data = res.data;
      setState(() {
        _sessions = data is List ? data : (data['data'] ?? []);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Cours en groupe'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: _isTeacher ? 'Mes séances' : 'Disponibles'),
            Tab(text: _isTeacher ? 'Créer' : 'Mes inscriptions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SessionsList(
            sessions: _isTeacher
                ? _sessions.where((s) => s['providerId'] ==
                    ref.read(authStateProvider).value?.user?['id']).toList()
                : _sessions,
            loading: _loading,
            isTeacher: _isTeacher,
            onRefresh: _load,
          ),
          _isTeacher
              ? _CreateGroupForm(onCreated: _load)
              : _MyEnrollments(sessions: _sessions, onRefresh: _load),
        ],
      ),
    );
  }
}

// ── Liste des séances de groupe ───────────────────────────────────────────────
class _SessionsList extends ConsumerWidget {
  final List sessions;
  final bool loading, isTeacher;
  final VoidCallback onRefresh;

  const _SessionsList({
    required this.sessions, required this.loading,
    required this.isTeacher, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (sessions.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.group_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          isTeacher ? 'Aucune séance créée' : 'Aucune séance disponible',
          style: const TextStyle(color: Colors.grey, fontSize: 15),
        ),
      ],
    ));

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        itemBuilder: (_, i) => _GroupSessionCard(
          session: Map<String, dynamic>.from(sessions[i]),
          isTeacher: isTeacher,
          onRefresh: onRefresh,
        ),
      ),
    );
  }
}

// ── Carte séance de groupe ───────────────────────────────────────────────────
class _GroupSessionCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> session;
  final bool isTeacher;
  final VoidCallback onRefresh;

  const _GroupSessionCard({
    required this.session, required this.isTeacher, required this.onRefresh,
  });

  @override
  ConsumerState<_GroupSessionCard> createState() => _GroupSessionCardState();
}

class _GroupSessionCardState extends ConsumerState<_GroupSessionCard> {
  bool _loading = false;

  Future<void> _enroll() async {
    final childNameCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Inscrire un enfant'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          'Cours de ${widget.session['subject']} — ${widget.session['classLevel']}\n'
          '${widget.session['pricePerStudent']} FCFA/élève',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: childNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Prénom de l\'enfant *',
            border: OutlineInputBorder(),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
          child: const Text('Inscrire'),
        ),
      ],
    ));

    if (ok != true || childNameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).post(
        '/education/group-sessions/${widget.session['id']}/enroll',
        data: {'childName': childNameCtrl.text.trim()},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Inscription confirmée !'), backgroundColor: Colors.green));
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final enrollments = s['enrollments'] as List? ?? [];
    final max = (s['maxStudents'] as num?)?.toInt() ?? 5;
    final filled = enrollments.length;
    final isFull = s['status'] == 'full' || filled >= max;
    final progress = max > 0 ? filled / max : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // En-tête
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.groups_outlined, color: Color(0xFF1976D2), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['subject']} — ${s['classLevel']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(_fmtDate(s['sessionDate']),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isFull ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isFull ? Colors.red : Colors.green),
              ),
              child: Text(isFull ? 'Complet' : 'Ouvert',
                  style: TextStyle(
                      color: isFull ? Colors.red : Colors.green,
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),

          // Détails
          _row(Icons.access_time, '${s['startTime']} — ${s['endTime']}'),
          _row(Icons.location_on_outlined, s['locationAddress'] ?? ''),
          _row(Icons.attach_money, '${s['pricePerStudent']} FCFA / élève'),

          const SizedBox(height: 12),

          // Jauge inscriptions
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$filled / $max élèves inscrits',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFull ? Colors.red : const Color(0xFF1976D2)),
                ),
              ),
            ])),
          ]),

          // Bouton inscription (parent)
          if (!widget.isTeacher && !isFull) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _enroll,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Inscrire mon enfant'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],

          // Liste élèves inscrits (enseignant)
          if (widget.isTeacher && enrollments.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            const Text('Élèves inscrits',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: enrollments.map((e) => Chip(
                avatar: const Icon(Icons.person, size: 14),
                label: Text(e['childName'] as String? ?? '',
                    style: const TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFF1976D2).withOpacity(0.08),
                padding: EdgeInsets.zero,
              )).toList(),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.grey),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87))),
    ]),
  );

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString());
      return DateFormat('EEEE dd MMMM yyyy', 'fr').format(d);
    } catch (_) { return raw.toString(); }
  }
}

// ── Formulaire création séance de groupe (enseignant) ─────────────────────────
class _CreateGroupForm extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateGroupForm({required this.onCreated});

  @override
  ConsumerState<_CreateGroupForm> createState() => _CreateGroupFormState();
}

class _CreateGroupFormState extends ConsumerState<_CreateGroupForm> {
  final _subjectCtrl  = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _priceCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  String? _level;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 15, minute: 0);
  TimeOfDay _end   = const TimeOfDay(hour: 17, minute: 0);
  int _maxStudents = 4;
  bool _loading = false;

  static const _levels = ['CP', 'CE1', 'CE2', 'CM1', 'CM2', '6ème', '5ème', '4ème',
    '3ème', '2nde', '1ère', 'Terminale'];

  @override
  void dispose() {
    _subjectCtrl.dispose(); _addressCtrl.dispose();
    _priceCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.isEmpty || _level == null || _addressCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Remplissez tous les champs obligatoires'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/education/group-sessions', data: {
        'subject':      _subjectCtrl.text.trim(),
        'classLevel':   _level,
        'sessionDate':  DateFormat('yyyy-MM-dd').format(_date),
        'startTime':    '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}',
        'endTime':      '${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}',
        'locationAddress': _addressCtrl.text.trim(),
        'pricePerStudent': int.parse(_priceCtrl.text.trim()),
        'maxStudents':  _maxStudents,
        'description':  _descCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Séance de groupe créée ! Les parents ont été notifiés.'),
            backgroundColor: Colors.green));
        _subjectCtrl.clear(); _addressCtrl.clear();
        _priceCtrl.clear(); _descCtrl.clear();
        setState(() { _level = null; _maxStudents = 4; });
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Proposez un cours de groupe. Tous les parents dans votre zone recevront une notification SMS.',
              style: TextStyle(color: Colors.blue, fontSize: 13),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        _tf('Matière *', _subjectCtrl, hint: 'Mathématiques, Physique...'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _level,
          decoration: const InputDecoration(labelText: 'Niveau *', border: OutlineInputBorder()),
          items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
          onChanged: (v) => setState(() => _level = v),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today, color: Color(0xFF1976D2)),
          title: Text('Date: ${DateFormat('dd/MM/yyyy').format(_date)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date,
                firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
            if (d != null) setState(() => _date = d);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.access_time, color: Color(0xFF1976D2)),
          title: Text('Horaire: ${_start.format(context)} → ${_end.format(context)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () async {
            final t1 = await showTimePicker(context: context, initialTime: _start);
            if (t1 != null) setState(() => _start = t1);
            final t2 = await showTimePicker(context: context, initialTime: _end);
            if (t2 != null) setState(() => _end = t2);
          },
        ),
        const SizedBox(height: 4),
        _tf('Adresse *', _addressCtrl, hint: 'Lieu du cours'),
        const SizedBox(height: 12),
        _tf('Prix par élève (FCFA) *', _priceCtrl, hint: 'Ex: 3000', type: TextInputType.number),
        const SizedBox(height: 14),
        Row(children: [
          const Text('Nombre max d\'élèves', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF1976D2)),
            onPressed: () => setState(() { if (_maxStudents > 2) _maxStudents--; }),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF1976D2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$_maxStudents', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1976D2)),
            onPressed: () => setState(() { if (_maxStudents < 8) _maxStudents++; }),
          ),
        ]),
        const SizedBox(height: 12),
        _tf('Description (optionnel)', _descCtrl, hint: 'Objectifs, prérequis...', lines: 2),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.groups_outlined),
            label: const Text('Créer la séance de groupe', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tf(String label, TextEditingController ctrl,
      {String? hint, int lines = 1, TextInputType? type}) =>
    TextField(
      controller: ctrl, maxLines: lines, keyboardType: type,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
}

// ── Mes inscriptions (parent) ─────────────────────────────────────────────────
class _MyEnrollments extends ConsumerStatefulWidget {
  final List sessions;
  final VoidCallback onRefresh;
  const _MyEnrollments({required this.sessions, required this.onRefresh});

  @override
  ConsumerState<_MyEnrollments> createState() => _MyEnrollmentsState();
}

class _MyEnrollmentsState extends ConsumerState<_MyEnrollments> {
  List<dynamic> get _myEnrollments {
    final myId = ref.read(authStateProvider).value?.user?['id'];
    return widget.sessions.where((s) {
      final enr = s['enrollments'] as List? ?? [];
      return enr.any((e) => e['clientId'] == myId);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mine = _myEnrollments;
    if (mine.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('Aucune inscription', style: TextStyle(color: Colors.grey, fontSize: 15)),
        const SizedBox(height: 6),
        const Text('Allez dans "Disponibles" pour inscrire votre enfant.',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    ));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mine.length,
      itemBuilder: (_, i) => _GroupSessionCard(
        session: Map<String, dynamic>.from(mine[i]),
        isTeacher: false,
        onRefresh: widget.onRefresh,
      ),
    );
  }
}
