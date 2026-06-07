import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

const _pink = Color(0xFFEC4899);

const _servicesMeta = {
  'nettoyage':    {'emoji': '🧹', 'label': 'Nettoyage'},
  'cuisine':      {'emoji': '🍳', 'label': 'Cuisine'},
  'garde_enfants':{'emoji': '👶', 'label': 'Garde enfants'},
  'repassage':    {'emoji': '👔', 'label': 'Repassage'},
  'lessive':      {'emoji': '🫧', 'label': 'Lessive'},
  'courses':      {'emoji': '🛒', 'label': 'Courses'},
};

const _statusColors = {
  'pending':   Color(0xFFF59E0B),
  'active':    Color(0xFF16A34A),
  'paused':    Color(0xFF6366F1),
  'completed': Color(0xFF64748B),
  'cancelled': Color(0xFFEF4444),
};

// ═══════════════════════════════════════════════════════════════════════════
class MenagereContractScreen extends ConsumerStatefulWidget {
  final String contractId;
  const MenagereContractScreen({super.key, required this.contractId});
  @override
  ConsumerState<MenagereContractScreen> createState() => _State();
}

class _State extends ConsumerState<MenagereContractScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, dynamic>? _contract;
  List<dynamic> _attendance = [];
  List<dynamic> _payments   = [];
  bool _loading = true;
  String _currentMonth = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res  = await api.get('/menagere/contracts/${widget.contractId}', forceRefresh: true);
      final att  = await api.get('/menagere/contracts/${widget.contractId}/attendance',
          params: {'month': _currentMonth});
      final pay  = await api.get('/menagere/contracts/${widget.contractId}/payments');
      if (mounted) setState(() {
        _contract   = res.data is Map ? Map<String, dynamic>.from(res.data) : null;
        final attRaw = att.data;
        _attendance  = attRaw is List ? attRaw : (attRaw is Map ? (attRaw['data'] ?? []) : []);
        final payRaw = pay.data;
        _payments    = payRaw is List ? payRaw : (payRaw is Map ? (payRaw['data'] ?? []) : []);
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _respondContract(String action) async {
    try {
      await ref.read(apiClientProvider).patch(
          '/menagere/contracts/${widget.contractId}/respond', data: {'action': action});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'accept' ? '✅ Contrat accepté' : '❌ Contrat refusé'),
          backgroundColor: action == 'accept' ? const Color(0xFF16A34A) : const Color(0xFFEF4444)));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _generatePayment() async {
    try {
      await ref.read(apiClientProvider).post(
          '/menagere/contracts/${widget.contractId}/payments/generate', data: {'month': _currentMonth});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Fiche de paie générée'), backgroundColor: Color(0xFF16A34A)));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(
      appBar: AppBar(backgroundColor: _pink, foregroundColor: Colors.white, title: const Text('Contrat')),
      body: const Center(child: CircularProgressIndicator(color: _pink)));

    if (_contract == null) return Scaffold(
      appBar: AppBar(backgroundColor: _pink, foregroundColor: Colors.white, title: const Text('Contrat')),
      body: const Center(child: Text('Contrat introuvable')));

    final c      = _contract!;
    final status = c['status'] as String? ?? 'pending';
    final color  = _statusColors[status] ?? Colors.grey;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F6),
      appBar: AppBar(
        title: Text('Contrat · ${status.toUpperCase()}'),
        backgroundColor: _pink, foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text(status.toUpperCase(),
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Détails'), Tab(text: 'Pointages'), Tab(text: 'Paiements')],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _buildDetails(c, status),
        _buildAttendance(c, status),
        _buildPayments(c, status),
      ]),
    );
  }

  // ── Onglet Détails ───────────────────────────────────────────────────────
  Widget _buildDetails(Map<String, dynamic> c, String status) {
    final services  = _parseArray(c['services']);
    final workDays  = _parseArray(c['workDays']);
    final profile   = c['profile'] is Map ? Map<String, dynamic>.from(c['profile']) : null;

    return RefreshIndicator(
      color: _pink, onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Carte profil
          if (profile != null) _ProfileSummaryCard(profile: profile),
          const SizedBox(height: 12),

          // Infos contrat
          _InfoCard(children: [
            _Row(icon: Icons.calendar_today_outlined, label: 'Début', value: c['startDate'] ?? '-'),
            if (c['endDate'] != null) _Row(icon: Icons.event_available_outlined, label: 'Fin', value: c['endDate']),
            _Row(icon: Icons.access_time_outlined, label: 'Horaire', value: c['startTime'] ?? '-'),
            _Row(icon: Icons.view_week_outlined, label: 'Jours/sem.',
              value: '${c['daysPerWeek'] ?? 5} jours (${workDays.join(', ')})'),
            _Row(icon: Icons.schedule_outlined, label: 'Heures/jour', value: '${c['hoursPerDay'] ?? 8}h'),
            _Row(icon: Icons.location_on_outlined, label: 'Adresse', value: '${c['address'] ?? ''} ${c['city'] ?? ''}'),
          ]),
          const SizedBox(height: 12),

          // Services
          _SectionTitle('Services'),
          Wrap(spacing: 8, runSpacing: 8, children: services.map((s) {
            final meta = _servicesMeta[s] ?? {'emoji': '📦', 'label': s};
            return Chip(label: Text('${meta['emoji']}  ${meta['label']}'),
              padding: EdgeInsets.zero, backgroundColor: _pink.withOpacity(0.08));
          }).toList()),
          const SizedBox(height: 12),

          // Rémunération
          _InfoCard(children: [
            _Row(icon: Icons.payments_outlined, label: 'Mensuel',
              value: '${_fmt(c['salaireMensuel'])} FCFA'),
            _Row(icon: Icons.today_outlined, label: 'Journalier',
              value: '${_fmt(c['salaireJournalier'])} FCFA'),
          ]),

          if (c['clientNote'] != null && (c['clientNote'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.notes_outlined, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(c['clientNote'], style: const TextStyle(fontSize: 13, height: 1.4))),
              ]),
            ),
          ],

          // Actions selon statut
          const SizedBox(height: 20),
          if (status == 'pending') Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: () => _respondContract('accept'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Accepter'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(
              onPressed: () => _respondContract('decline'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Refuser'))),
          ]),
        ]),
      ),
    );
  }

  // ── Onglet Pointages ─────────────────────────────────────────────────────
  Widget _buildAttendance(Map<String, dynamic> c, String status) {
    return Column(children: [
      // Sélecteur de mois
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.white,
        child: Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1)),
          Expanded(child: Text(_currentMonth, textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          IconButton(icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1)),
        ]),
      ),
      Expanded(child: _attendance.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.event_note_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text('Aucun pointage ce mois', style: TextStyle(color: Colors.grey.shade400)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _attendance.length,
            itemBuilder: (_, i) => _AttendanceCard(
              att: Map<String, dynamic>.from(_attendance[i]),
              contractId: widget.contractId,
              onValidated: _load,
            ),
          )),
    ]);
  }

  void _changeMonth(int delta) async {
    final parts = _currentMonth.split('-');
    var y = int.parse(parts[0]), m = int.parse(parts[1]);
    m += delta;
    if (m > 12) { y++; m = 1; }
    if (m < 1)  { y--; m = 12; }
    setState(() => _currentMonth = '$y-${m.toString().padLeft(2, '0')}');
    final api = ref.read(apiClientProvider);
    final att = await api.get('/menagere/contracts/${widget.contractId}/attendance',
        params: {'month': _currentMonth});
    final raw = att.data;
    setState(() => _attendance = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) : []));
  }

  // ── Onglet Paiements ─────────────────────────────────────────────────────
  Widget _buildPayments(Map<String, dynamic> c, String status) {
    return Column(children: [
      if (status == 'active') Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: _generatePayment,
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text('Générer fiche $_currentMonth'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _pink, foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      ),
      Expanded(child: _payments.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.payment_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text('Aucune fiche de paie', style: TextStyle(color: Colors.grey.shade400)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _payments.length,
            itemBuilder: (_, i) => _PaymentCard(
              payment: Map<String, dynamic>.from(_payments[i]),
              contractId: widget.contractId,
              onReleased: _load,
            ),
          )),
    ]);
  }
}

// ─── Carte pointage ──────────────────────────────────────────────────────────
class _AttendanceCard extends ConsumerWidget {
  final Map<String, dynamic> att;
  final String contractId;
  final VoidCallback onValidated;
  const _AttendanceCard({required this.att, required this.contractId, required this.onValidated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absent   = att['absent'] == true;
    final validated = att['validatedByClient'] == true;
    final color    = absent ? const Color(0xFFEF4444) : const Color(0xFF16A34A);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: ListTile(
        leading: Container(width: 40, height: 40, decoration: BoxDecoration(
          color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(absent ? Icons.event_busy_outlined : Icons.event_available_outlined, color: color, size: 20)),
        title: Text(att['date'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(absent
          ? 'Absent · ${att['absenceReason'] ?? ''}'
          : '${att['checkIn'] ?? '--:--'} → ${att['checkOut'] ?? '--:--'} · ${att['hoursWorked']}h',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        trailing: validated
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20)
          : TextButton(
              onPressed: () async {
                await ref.read(apiClientProvider).patch(
                    '/menagere/attendance/${att['id']}/validate', data: {});
                onValidated();
              },
              style: TextButton.styleFrom(foregroundColor: _pink, padding: EdgeInsets.zero),
              child: const Text('Valider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
      ),
    );
  }
}

// ─── Carte paiement ──────────────────────────────────────────────────────────
class _PaymentCard extends ConsumerWidget {
  final Map<String, dynamic> payment;
  final String contractId;
  final VoidCallback onReleased;
  const _PaymentCard({required this.payment, required this.contractId, required this.onReleased});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = payment['status'] as String? ?? 'pending';
    final color  = status == 'released' ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.2)))),
          child: Row(children: [
            Text(payment['month'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Text(status.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
          ])),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Jours travaillés', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              Text('${payment['daysWorked']} / ${payment['daysTotal']}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Absences', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              Text('${payment['daysAbsent']} j', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Déductions', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              Text('- ${_fmt(payment['deductions'])} FCFA',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
            ]),
            Divider(color: Colors.grey.shade200, height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Net à payer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text('${_fmt(payment['netAmount'])} FCFA',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _pink)),
            ]),
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(apiClientProvider).post(
                      '/menagere/payments/${payment['id']}/release', data: {});
                  onReleased();
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Valider le paiement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
            ],
          ]),
        ),
      ]));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS PARTAGÉS
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileSummaryCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ProfileSummaryCard({required this.profile});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
    child: Row(children: [
      CircleAvatar(radius: 28, backgroundColor: _pink.withOpacity(0.1),
        backgroundImage: profile['photoUrl'] != null ? NetworkImage(profile['photoUrl']) : null,
        child: profile['photoUrl'] == null ? const Icon(Icons.person, color: _pink) : null),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(profile['fullName'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        Text('📍 ${profile['city'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        Row(children: [
          Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade600),
          Text(' ${((profile['avgRating'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ])),
    ]));
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
    child: Column(children: children));
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 17, color: _pink),
      const SizedBox(width: 10),
      Text('$label: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
    ]));
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)));
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
