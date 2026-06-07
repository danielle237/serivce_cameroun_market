import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';

const _pink = Color(0xFFEC4899);

// ═══════════════════════════════════════════════════════════════════════════
class MenagereWorkerDashboard extends ConsumerStatefulWidget {
  const MenagereWorkerDashboard({super.key});
  @override
  ConsumerState<MenagereWorkerDashboard> createState() => _State();
}

class _State extends ConsumerState<MenagereWorkerDashboard> {
  Map<String, dynamic>? _profile;
  List<dynamic> _activeContracts = [];
  Map<String, dynamic>? _todayAttendance;
  bool _loading = true;
  bool _checkingIn = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final profRes = await api.get('/menagere/profiles/me', forceRefresh: true);
      final contRes = await api.get('/menagere/contracts', params: {'role': 'worker', 'status': 'active'});
      if (mounted) setState(() {
        _profile = profRes.data is Map ? Map<String, dynamic>.from(profRes.data) : null;
        final raw = contRes.data;
        _activeContracts = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) : []);
        _loading = false;
      });
      // Vérifier pointage du jour pour le premier contrat actif
      if (_activeContracts.isNotEmpty) {
        _loadTodayAttendance(_activeContracts[0]['id']);
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadTodayAttendance(String contractId) async {
    try {
      final today = _today();
      final res = await ref.read(apiClientProvider).get(
          '/menagere/attendance/today', params: {'contractId': contractId, 'date': today});
      if (mounted) setState(() {
        _todayAttendance = res.data is Map ? Map<String, dynamic>.from(res.data) : null;
      });
    } catch (_) {}
  }

  Future<void> _checkIn(String contractId) async {
    setState(() => _checkingIn = true);
    try {
      final res = await ref.read(apiClientProvider).post('/menagere/attendance/checkin', data: {'contractId': contractId});
      setState(() { _todayAttendance = res.data is Map ? Map<String, dynamic>.from(res.data) : null; _checkingIn = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Check-in enregistré !'), backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      setState(() => _checkingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _checkOut(String attendanceId) async {
    setState(() => _checkingIn = true);
    try {
      final res = await ref.read(apiClientProvider).patch('/menagere/attendance/$attendanceId/checkout', data: {});
      setState(() { _todayAttendance = res.data is Map ? Map<String, dynamic>.from(res.data) : null; _checkingIn = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Check-out enregistré !'), backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      setState(() => _checkingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F6),
      appBar: AppBar(
        title: const Text('Mon tableau de bord'),
        backgroundColor: _pink, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: _pink))
        : RefreshIndicator(
            color: _pink, onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Profil + statut ────────────────────────────────────
                _buildProfileHeader(),
                const SizedBox(height: 16),

                // ── Check-in/out du jour ───────────────────────────────
                if (_activeContracts.isNotEmpty) _buildCheckinCard(),
                if (_activeContracts.isEmpty) _buildNoContractCard(),
                const SizedBox(height: 16),

                // ── Stats rapides ──────────────────────────────────────
                _buildStats(),
                const SizedBox(height: 16),

                // ── Contrats actifs ────────────────────────────────────
                if (_activeContracts.isNotEmpty) ...[
                  _SectionTitle('Mes contrats actifs'),
                  ..._activeContracts.map((c) => _ContractMiniCard(
                    contract: Map<String, dynamic>.from(c),
                    onTap: () => context.push('/menagere/contracts/${c['id']}'),
                  )),
                  const SizedBox(height: 10),
                ],

                // ── Revenus du mois ────────────────────────────────────
                _buildEarnings(),
              ]),
            ),
          ),
    );
  }

  Widget _buildProfileHeader() {
    if (_profile == null) return const SizedBox.shrink();
    final p = _profile!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_pink, Color(0xFFF472B6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        CircleAvatar(radius: 32, backgroundColor: Colors.white.withOpacity(0.3),
          backgroundImage: p['photoUrl'] != null ? NetworkImage(p['photoUrl']) : null,
          child: p['photoUrl'] == null ? const Icon(Icons.person, size: 32, color: Colors.white) : null),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bonjour, ${(p['fullName'] as String? ?? '').split(' ').first} 👋',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('${_activeContracts.length} contrat(s) actif(s)',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade300),
            Text(' ${((p['avgRating'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} · ${p['totalReviews'] ?? 0} avis',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ])),
        // Disponibilité toggle
        Column(children: [
          Switch(
            value: p['isAvailable'] == true,
            activeColor: Colors.white, activeTrackColor: Colors.white.withOpacity(0.4),
            inactiveThumbColor: Colors.grey.shade300, inactiveTrackColor: Colors.black26,
            onChanged: (_) async {
              await ref.read(apiClientProvider).patch('/menagere/profiles/availability', data: {});
              _load();
            },
          ),
          Text(p['isAvailable'] == true ? 'Dispo' : 'Indispo',
            style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ]),
      ]),
    );
  }

  Widget _buildCheckinCard() {
    if (_activeContracts.isEmpty) return const SizedBox.shrink();
    final contract = _activeContracts[0];
    final att      = _todayAttendance;
    final hasCheckin  = att != null && att['checkIn'] != null;
    final hasCheckout = att != null && att['checkOut'] != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.today_outlined, color: _pink, size: 20),
          const SizedBox(width: 8),
          const Text("Aujourd'hui", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(_today(), style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ]),
        const SizedBox(height: 12),
        Text(contract['address'] ?? '',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _TimeBox(
            label: 'Arrivée',
            time: att?['checkIn'] as String?,
            icon: Icons.login_outlined,
            color: const Color(0xFF16A34A),
          )),
          const SizedBox(width: 10),
          Expanded(child: _TimeBox(
            label: 'Départ',
            time: att?['checkOut'] as String?,
            icon: Icons.logout_outlined,
            color: const Color(0xFF6366F1),
          )),
        ]),
        const SizedBox(height: 12),
        if (!hasCheckin) SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _checkingIn ? null : () => _checkIn(contract['id']),
          icon: _checkingIn
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.login_outlined),
          label: const Text('Pointer l\'arrivée'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
        if (hasCheckin && !hasCheckout) SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _checkingIn ? null : () => _checkOut(att!['id']),
          icon: _checkingIn
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.logout_outlined),
          label: Text('Pointer le départ (depuis ${att!['checkIn']})'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
        if (hasCheckout) Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
            const SizedBox(width: 6),
            Text('Journée terminée · ${att!['hoursWorked']}h travaillées',
              style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
          ])),
      ]),
    );
  }

  Widget _buildNoContractCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
    child: Column(children: [
      Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 10),
      Text('Aucun contrat actif', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
      const SizedBox(height: 6),
      Text('Attendez qu\'un client accepte votre profil', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
    ]));

  Widget _buildStats() {
    final p = _profile ?? {};
    return Row(children: [
      Expanded(child: _StatCard(icon: Icons.assignment_turned_in_outlined,
        label: 'Contrats', value: '${p['totalContracts'] ?? 0}')),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(icon: Icons.star_outline_rounded,
        label: 'Note moy.', value: ((p['avgRating'] as num?)?.toDouble() ?? 0).toStringAsFixed(1))),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(icon: Icons.rate_review_outlined,
        label: 'Avis', value: '${p['totalReviews'] ?? 0}')),
    ]);
  }

  Widget _buildEarnings() {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return FutureBuilder(
      future: ref.read(apiClientProvider).get('/menagere/payments/my', params: {'month': month}),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final raw = snap.data?.data;
        final items = raw is List ? raw : (raw is Map ? (raw['data'] ?? []) : []);
        if (items.isEmpty) return const SizedBox.shrink();

        int total = 0;
        for (final p in items) {
          total += (num.tryParse(p['netAmount']?.toString() ?? '') ?? 0).toInt();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet_outlined, color: _pink, size: 28),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Revenus $month', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              Text('${_fmt(total)} FCFA',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _pink)),
            ]),
          ]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS LOCAUX
// ═══════════════════════════════════════════════════════════════════════════

class _ContractMiniCard extends StatelessWidget {
  final Map<String, dynamic> contract;
  final VoidCallback onTap;
  const _ContractMiniCard({required this.contract, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contract['clientName'] as String? ?? 'Client',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('${contract['address'] ?? ''} · ${contract['startTime'] ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ])),
          Text('${_fmt(contract['salaireJournalier'])} FCFA/j',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _pink)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        ]),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final String? time;
  final IconData icon;
  final Color color;
  const _TimeBox({required this.label, required this.time, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(height: 4),
      Text(time ?? '--:--', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]));
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
    child: Column(children: [
      Icon(icon, size: 22, color: _pink),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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

String _today() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

String _fmt(dynamic v) {
  final n = num.tryParse(v?.toString() ?? '') ?? 0;
  return n.toInt().toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}
