import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';

class WeeklyScheduleScreen extends ConsumerStatefulWidget {
  final bool readOnly; // true = parent (lecture seule, pas de FAB)
  const WeeklyScheduleScreen({super.key, this.readOnly = false});

  @override
  ConsumerState<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends ConsumerState<WeeklyScheduleScreen> {
  List<dynamic> _sessions = [];
  bool _loading = true;
  DateTime _weekStart = _getMonday(DateTime.now());

  static DateTime _getMonday(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  // Couleurs par famille (index client)
  final Map<String, Color> _familyColors = {};
  final _palette = [
    const Color(0xFF1976D2),
    Colors.purple,
    Colors.teal,
    Colors.orange,
    Colors.pink,
    Colors.indigo,
    Colors.green,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Color _colorForClient(String clientId) {
    if (!_familyColors.containsKey(clientId)) {
      _familyColors[clientId] = _palette[_familyColors.length % _palette.length];
    }
    return _familyColors[clientId]!;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/education/sessions');
      final data = res.data;
      setState(() {
        _sessions = data is List ? data : (data['data'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<dynamic> _sessionsForDay(DateTime day) {
    return _sessions.where((s) {
      try {
        final d = DateTime.parse(s['sessionDate'].toString());
        return d.year == day.year && d.month == day.month && d.day == day.day;
      } catch (_) { return false; }
    }).toList()
      ..sort((a, b) => (a['startTime'] ?? '').compareTo(b['startTime'] ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.readOnly ? 'Planning des cours' : 'Planning de la semaine'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // ── Navigation semaine ─────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() =>
                        _weekStart = _weekStart.subtract(const Duration(days: 7))),
                  ),
                  Expanded(
                    child: Text(
                      '${DateFormat('dd MMM', 'fr').format(_weekStart)} — '
                      '${DateFormat('dd MMM yyyy', 'fr').format(weekEnd)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() =>
                        _weekStart = _weekStart.add(const Duration(days: 7))),
                  ),
                ]),
              ),
              const Divider(height: 1),

              // ── Grille 7 jours ─────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: 7,
                  itemBuilder: (_, i) {
                    final day = _weekStart.add(Duration(days: i));
                    final sessions = _sessionsForDay(day);
                    final isToday = DateUtils.isSameDay(day, DateTime.now());

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isToday
                            ? Border.all(color: const Color(0xFF1976D2), width: 2)
                            : Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                        )],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // En-tête du jour
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF1976D2).withOpacity(0.08)
                                : Colors.grey.shade50,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(children: [
                            Text(
                              _days[i],
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isToday ? const Color(0xFF1976D2) : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('dd/MM').format(day),
                              style: TextStyle(
                                fontSize: 13,
                                color: isToday ? const Color(0xFF1976D2) : Colors.grey,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1976D2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text("Aujourd'hui",
                                    style: TextStyle(color: Colors.white, fontSize: 10)),
                              ),
                            ],
                            const Spacer(),
                            if (sessions.isNotEmpty)
                              Text('${sessions.length} séance${sessions.length > 1 ? 's' : ''}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ]),
                        ),

                        // Séances du jour
                        if (sessions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Text('Aucune séance',
                                style: TextStyle(fontSize: 13, color: Colors.grey,
                                    fontStyle: FontStyle.italic)),
                          )
                        else
                          ...sessions.map((s) => _SessionSlot(
                            session: Map<String, dynamic>.from(s),
                            color: _colorForClient(
                                s['clientId'] as String? ?? 'default'),
                          )),
                      ]),
                    );
                  },
                ),
              ),

              // ── Légende familles ───────────────────────────────────────
              if (_familyColors.isNotEmpty)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Familles', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10, runSpacing: 6,
                      children: _familyColors.entries.map((e) {
                        final s = _sessions.firstWhere(
                          (s) => s['clientId'] == e.key,
                          orElse: () => {},
                        );
                        return Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 12, height: 12,
                              decoration: BoxDecoration(color: e.value, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(
                            s['clientName'] as String? ?? 'Famille',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ]),
                ),
            ]),
    );
  }
}

class _SessionSlot extends StatelessWidget {
  final Map<String, dynamic> session;
  final Color color;

  const _SessionSlot({required this.session, required this.color});

  @override
  Widget build(BuildContext context) {
    final status = session['status'] as String? ?? 'scheduled';
    final statusColors = {
      'in_progress': Colors.orange,
      'validated': Colors.green,
      'cancelled': Colors.grey,
      'missed': Colors.red,
    };
    final slotColor = statusColors[status] ?? color;
    final childName = session['childName'] as String?;

    return InkWell(
      onTap: () => context.push('/education/session/${session['id']}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: slotColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: slotColor, width: 4)),
        ),
        child: Row(children: [
          // Heure
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              session['startTime'] as String? ?? '--:--',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: slotColor),
            ),
            Text(
              session['endTime'] as String? ?? '--:--',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ]),
          const SizedBox(width: 12),
          // Infos
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (childName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(childName,
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
              ],
              if (session['childSubject'] != null)
                Text(session['childSubject'],
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            if (session['locationAddress'] != null) ...[
              const SizedBox(height: 2),
              Text(session['locationAddress'],
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis),
            ],
          ])),
          // Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: slotColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(status),
              style: TextStyle(fontSize: 10, color: slotColor, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
      ),
    );
  }

  String _statusLabel(String s) => {
    'scheduled': '📅',
    'in_progress': '🔴 En cours',
    'validated': '✅',
    'cancelled': '❌',
    'missed': '⚠️',
  }[s] ?? s;
}
