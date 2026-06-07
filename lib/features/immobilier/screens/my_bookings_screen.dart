import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/connectivity_provider.dart';

class MyImmobilierBookingsScreen extends ConsumerStatefulWidget {
  const MyImmobilierBookingsScreen({super.key});
  @override
  ConsumerState<MyImmobilierBookingsScreen> createState() => _MyBookingsState();
}

class _MyBookingsState extends ConsumerState<MyImmobilierBookingsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/immobilier/my/bookings',
          forceRefresh: ref.read(isOnlineProvider));
      setState(() {
        _bookings = (res.data is List)
            ? (res.data as List).map((b) => Map<String, dynamic>.from(b)).toList()
            : [];
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  static const _mois = [
    '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
    'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
  ];

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.day} ${_mois[d.month]} ${d.year}';
    } catch (_) { return iso; }
  }

  String _fmtMoney(dynamic v) {
    final n = int.tryParse(v?.toString() ?? '') ?? 0;
    final s = n.toString(); final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Mes séjours'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _bookings.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.hotel_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('Aucune réservation', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/immobilier'),
                child: const Text('Parcourir les logements'),
              ),
            ]))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _bookings.length,
                itemBuilder: (_, i) => _BookingCard(
                  booking: _bookings[i],
                  fmtDate: _fmtDate,
                  fmtMoney: _fmtMoney,
                  onTap: () => context.push('/immobilier/${_bookings[i]['propertyId']}'),
                ),
              ),
            ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String Function(String?) fmtDate;
  final String Function(dynamic) fmtMoney;
  final VoidCallback onTap;
  const _BookingCard({required this.booking, required this.fmtDate,
    required this.fmtMoney, required this.onTap});

  static const _statusConfig = {
    'pending':   {'label': 'En attente',  'color': 0xFFF59E0B, 'icon': Icons.hourglass_top_rounded},
    'paid':      {'label': 'Confirmé',    'color': 0xFF16A34A, 'icon': Icons.check_circle_rounded},
    'cancelled': {'label': 'Annulé',      'color': 0xFFDC2626, 'icon': Icons.cancel_rounded},
    'refunded':  {'label': 'Remboursé',   'color': 0xFF6366F1, 'icon': Icons.replay_rounded},
  };

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? 'pending';
    final cfg    = _statusConfig[status] ?? _statusConfig['pending']!;
    final color  = Color(cfg['color'] as int);
    final icon   = cfg['icon'] as IconData;
    final nights = booking['nbNights'] as int? ?? 0;
    final total  = fmtMoney(booking['totalAmount']);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, 3))]),
        child: Column(children: [
          // Header coloré selon statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.2)))),
            child: Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(cfg['label'] as String,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              const Spacer(),
              Text('Réf: ${(booking['paymentReference'] as String? ?? '').split('-').last}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Dates
              Row(children: [
                _DateBlock(label: 'Arrivée',  value: fmtDate(booking['dateIn'])),
                Expanded(child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (_) =>
                    Container(width: 4, height: 1, color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(horizontal: 1)))),
                  const SizedBox(height: 2),
                  Text('$nights nuit${nights > 1 ? "s" : ""}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ])),
                _DateBlock(label: 'Départ', value: fmtDate(booking['dateOut']), right: true),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Invité + total
              Row(children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Expanded(child: Text(booking['guestName'] as String? ?? '—',
                  style: const TextStyle(fontSize: 13))),
                Text('$total FCFA',
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF00695C))),
              ]),

              // Note
              if ((booking['guestNote'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.notes_rounded, size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Expanded(child: Text(booking['guestNote'] as String,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                  ]),
                ),
              ],

              // Bouton payer si pending
              if (status == 'pending' && (booking['authUrl'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO url_launcher → booking['authUrl']
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('URL: ${booking['authUrl']}')));
                    },
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Finaliser le paiement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  )),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  final String label, value;
  final bool right;
  const _DateBlock({required this.label, required this.value, this.right = false});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    ]);
}
