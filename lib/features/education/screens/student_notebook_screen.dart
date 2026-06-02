import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';

class StudentNotebookScreen extends ConsumerStatefulWidget {
  final String contractId;
  final String studentName;

  const StudentNotebookScreen({
    super.key,
    required this.contractId,
    required this.studentName,
  });

  @override
  ConsumerState<StudentNotebookScreen> createState() => _StudentNotebookScreenState();
}

class _StudentNotebookScreenState extends ConsumerState<StudentNotebookScreen> {
  List<dynamic> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        '/education/sessions',
        params: {'contractId': widget.contractId, 'status': 'validated'},
      );
      final data = res.data;
      setState(() {
        _sessions = (data is List ? data : data['data'] ?? [])
            .where((s) => s['homeworkLeft'] != null || s['studentState'] != null || s['suggestions'] != null)
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = ref.read(authStateProvider).value?.user?['activeMode'] == 'provider';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Carnet — ${widget.studentName}'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _sessions.isEmpty
                  ? _buildEmpty()
                  : CustomScrollView(
                      slivers: [
                        // Graphique progression
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _ProgressChart(sessions: _sessions),
                          ),
                        ),
                        // Résumé stats
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: _StatsRow(sessions: _sessions),
                          ),
                        ),
                        // Liste bilans
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _BilanCard(
                                session: Map<String, dynamic>.from(_sessions[i]),
                                index: _sessions.length - i,
                                isTeacher: isTeacher,
                              ),
                              childCount: _sessions.length,
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 64, color: Colors.red),
    const SizedBox(height: 12),
    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
    const SizedBox(height: 12),
    ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
  ]));

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey.shade300),
    const SizedBox(height: 16),
    const Text('Aucun bilan disponible',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey)),
    const SizedBox(height: 8),
    Text('Les bilans apparaîtront ici après chaque séance validée',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        textAlign: TextAlign.center),
  ]));
}

// ── Graphique progression ──────────────────────────────────────────────────────
class _ProgressChart extends StatelessWidget {
  final List sessions;
  const _ProgressChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final stateValues = {'good': 3, 'average': 2, 'struggling': 1};
    final recent = sessions.take(10).toList().reversed.toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.trending_up, color: Color(0xFF1976D2), size: 20),
            SizedBox(width: 8),
            Text('Progression de l\'élève',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recent.map<Widget>((s) {
                final state = s['studentState'] as String? ?? 'average';
                final val = stateValues[state] ?? 2;
                final color = state == 'good'
                    ? Colors.green
                    : state == 'average' ? Colors.orange : Colors.red;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(_stateEmoji(state), style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        height: val * 18.0,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legend(Colors.green, 'Bien'),
            const SizedBox(width: 16),
            _legend(Colors.orange, 'Moyen'),
            const SizedBox(width: 16),
            _legend(Colors.red, 'Difficile'),
          ]),
        ]),
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
  ]);

  String _stateEmoji(String s) =>
      s == 'good' ? '😊' : s == 'average' ? '😐' : '😟';
}

// ── Statistiques résumées ─────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final List sessions;
  const _StatsRow({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final total = sessions.length;
    final good = sessions.where((s) => s['studentState'] == 'good').length;
    final withHomework = sessions.where((s) =>
        s['homeworkLeft'] != null && s['homeworkLeft'].toString().isNotEmpty).length;

    return Row(children: [
      Expanded(child: _StatCard(value: '$total', label: 'Séances', icon: Icons.event_available, color: Colors.blue)),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(
        value: total > 0 ? '${(good / total * 100).round()}%' : '—',
        label: 'Bien', icon: Icons.sentiment_satisfied_alt, color: Colors.green,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(value: '$withHomework', label: 'Devoirs', icon: Icons.book_outlined, color: Colors.orange)),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}

// ── Carte bilan d'une séance ──────────────────────────────────────────────────
class _BilanCard extends StatefulWidget {
  final Map<String, dynamic> session;
  final int index;
  final bool isTeacher;
  const _BilanCard({required this.session, required this.index, required this.isTeacher});

  @override
  State<_BilanCard> createState() => _BilanCardState();
}

class _BilanCardState extends State<_BilanCard> {
  bool _expanded = false;

  Color get _stateColor {
    switch (widget.session['studentState']) {
      case 'good':       return Colors.green;
      case 'average':    return Colors.orange;
      case 'struggling': return Colors.red;
      default:           return Colors.grey;
    }
  }

  String get _stateLabel {
    switch (widget.session['studentState']) {
      case 'good':       return '😊 Bien';
      case 'average':    return '😐 Moyen';
      case 'struggling': return '😟 Difficile';
      default:           return '—';
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return raw.toString(); }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final hasDetails = (s['homeworkLeft'] != null && s['homeworkLeft'].toString().isNotEmpty)
        || (s['suggestions'] != null && s['suggestions'].toString().isNotEmpty)
        || (widget.isTeacher && s['providerNotes'] != null && s['providerNotes'].toString().isNotEmpty);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _stateColor.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${widget.index}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1976D2))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Séance du ${_formatDate(s['sessionDate'])}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  '${s['startTime'] ?? ''} — ${s['endTime'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _stateColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _stateColor),
                ),
                child: Text(_stateLabel,
                    style: TextStyle(color: _stateColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),

            if (_expanded && hasDetails) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              if (s['homeworkLeft'] != null && s['homeworkLeft'].toString().isNotEmpty)
                _detailRow(Icons.assignment_outlined, 'Devoir laissé', s['homeworkLeft'], Colors.blue),

              if (s['suggestions'] != null && s['suggestions'].toString().isNotEmpty)
                _detailRow(Icons.lightbulb_outline, 'Suggestions', s['suggestions'], Colors.orange),

              if (widget.isTeacher && s['providerNotes'] != null && s['providerNotes'].toString().isNotEmpty)
                _detailRow(Icons.lock_outline, 'Notes privées', s['providerNotes'], Colors.grey),
            ],

            if (hasDetails) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: Colors.grey,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, dynamic value, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value.toString(), style: const TextStyle(fontSize: 13, color: Colors.black87)),
      ])),
    ]),
  );
}
