import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class MonthlyBillingScreen extends ConsumerStatefulWidget {
  const MonthlyBillingScreen({super.key});

  @override
  ConsumerState<MonthlyBillingScreen> createState() => _MonthlyBillingScreenState();
}

class _MonthlyBillingScreenState extends ConsumerState<MonthlyBillingScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  int _month = DateTime.now().month;
  int _year  = DateTime.now().year;

  static const _months = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/education/billing/monthly',
          params: {'month': '$_month', 'year': '$_year'});
      setState(() { _data = Map<String, dynamic>.from(res.data); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) { _month = 12; _year--; } else _month--;
    });
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_year == now.year && _month == now.month) return;
    setState(() {
      if (_month == 12) { _month = 1; _year++; } else _month++;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = _year == now.year && _month == now.month;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Récapitulatif mensuel'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        // ── Navigation mois ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
            Expanded(
              child: Text('${_months[_month]} $_year',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: isCurrentMonth ? null : _nextMonth,
              color: isCurrentMonth ? Colors.grey.shade300 : null,
            ),
          ]),
        ),
        const Divider(height: 1),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _data == null
                  ? const Center(child: Text('Erreur de chargement'))
                  : _buildContent(),
        ),
      ]),
    );
  }

  Widget _buildContent() {
    final total = _data!['totalAmount'] as num? ?? 0;
    final totalSessions = _data!['totalSessions'] as num? ?? 0;
    final byChild = _data!['byChild'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Résumé global ──────────────────────────────────────────────
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Text('Total ${_months[_month]}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                '${_fmt(total)} FCFA',
                style: const TextStyle(color: Colors.white, fontSize: 32,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text('$totalSessions séance${totalSessions != 1 ? 's' : ''} validée${totalSessions != 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (byChild.length > 1) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: byChild.map<Widget>((c) => Column(children: [
                    Text(c['childName'] as String? ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text('${_fmt(c['amount'])} FCFA',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ])).toList(),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 16),

        if (byChild.isEmpty)
          Center(child: Column(children: [
            const SizedBox(height: 40),
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Aucune séance ce mois',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
          ]))
        else ...[
          // ── Détail par enfant ────────────────────────────────────────
          ...byChild.map((child) => _ChildBillingCard(
            child: Map<String, dynamic>.from(child),
            months: _months,
            month: _month,
          )),
        ],
      ],
    );
  }

  String _fmt(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }
}

class _ChildBillingCard extends StatefulWidget {
  final Map<String, dynamic> child;
  final List<String> months;
  final int month;
  const _ChildBillingCard({required this.child, required this.months, required this.month});

  @override
  State<_ChildBillingCard> createState() => _ChildBillingCardState();
}

class _ChildBillingCardState extends State<_ChildBillingCard> {
  bool _expanded = false;

  String _fmt(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.child;
    final sessions = (c['sessions'] as num?)?.toInt() ?? 0;
    final amount = (c['amount'] as num?)?.toInt() ?? 0;
    final details = c['details'] as List? ?? [];
    final perSession = sessions > 0 ? amount ~/ sessions : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        // En-tête
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: Color(0xFF1976D2), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['childName'] as String? ?? 'Élève',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('$sessions séance${sessions != 1 ? 's' : ''} × ${_fmt(perSession)} FCFA',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${_fmt(amount)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
                        color: Color(0xFF1976D2))),
                const Text('ce mois', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
            ]),
          ),
        ),

        // Détail séances
        if (_expanded && details.isNotEmpty) ...[
          const Divider(height: 1),
          ...details.map((s) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(children: [
              const Icon(Icons.event_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(_fmtDate(s['sessionDate']),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Text('${s['startTime'] ?? ''} — ${s['endTime'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Spacer(),
              Text('${_fmt(s['sessionAmount'])} FCFA',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.green)),
            ]),
          )),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }
}
