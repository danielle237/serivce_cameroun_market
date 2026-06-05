import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';

class ArtisanQuotesScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String requestTitle;

  const ArtisanQuotesScreen({
    super.key,
    required this.requestId,
    required this.requestTitle,
  });

  @override
  ConsumerState<ArtisanQuotesScreen> createState() => _ArtisanQuotesScreenState();
}

class _ArtisanQuotesScreenState extends ConsumerState<ArtisanQuotesScreen> {
  List<dynamic> _quotes = [];
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
      final res = await api.get('/artisans/requests/${widget.requestId}/quotes');
      final data = res.data;
      setState(() {
        _quotes = data is List ? data : (data['data'] ?? []);
        // Trier par montant croissant
        _quotes.sort((a, b) =>
            (a['amount'] as num? ?? 0).compareTo(b['amount'] as num? ?? 0));
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Devis reçus', style: TextStyle(fontSize: 16)),
          Text(widget.requestTitle,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              overflow: TextOverflow.ellipsis),
        ]),
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
              : _quotes.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 64, color: Colors.red),
    const SizedBox(height: 12),
    Text(_error!, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.red)),
    const SizedBox(height: 12),
    ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
  ]));

  Widget _buildEmpty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.inbox_outlined, size: 72, color: Colors.grey.shade300),
    const SizedBox(height: 16),
    const Text('Aucun devis reçu pour l\'instant',
        style: TextStyle(fontSize: 16, color: Colors.grey)),
    const SizedBox(height: 8),
    const Text('Les artisans consultent votre demande et vous enverront leurs devis bientôt.',
        style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
  ]));

  Widget _buildList() {
    final best = _quotes.first; // Le moins cher

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bandeau info
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${_quotes.length} devis reçu${_quotes.length > 1 ? 's' : ''} · '
                'Consultez le portfolio de chaque artisan avant de choisir.',
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              )),
            ]),
          ),

          ...List.generate(_quotes.length, (i) {
            final q = Map<String, dynamic>.from(_quotes[i]);
            final isBest = i == 0 && _quotes.length > 1;
            return _QuoteCard(
              quote: q,
              requestId: widget.requestId,
              isBest: isBest,
              onAccepted: _load,
            );
          }),
        ],
      ),
    );
  }
}

// ── Carte devis avec lien portfolio ──────────────────────────────────────────
class _QuoteCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> quote;
  final String requestId;
  final bool isBest;
  final VoidCallback onAccepted;

  const _QuoteCard({
    required this.quote,
    required this.requestId,
    required this.isBest,
    required this.onAccepted,
  });

  @override
  ConsumerState<_QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends ConsumerState<_QuoteCard> {
  bool _accepting = false;
  bool _expanded = false;

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _fmt(dynamic v) {
    final n = _toInt(v);
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  Future<void> _accept() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accepter ce devis ?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Vous allez accepter le devis de ${_fmt(widget.quote['amount'])} FCFA.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.account_balance_wallet_outlined, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Ce montant sera immédiatement placé en séquestre et libéré uniquement après validation des travaux.',
                style: TextStyle(fontSize: 12, color: Colors.amber),
              )),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Accepter et payer'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    setState(() => _accepting = true);
    try {
      await ref.read(apiClientProvider).patch('/artisans/quotes/${widget.quote['id']}/accept');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Devis accepté ! Fonds mis en séquestre.'),
          backgroundColor: Colors.green,
        ));
        widget.onAccepted();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _accepting = false);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    final status = q['status'] as String? ?? 'pending';
    final providerId = q['providerId'] as String? ?? q['provider_id'] as String?;
    final providerName = q['providerName'] as String? ?? 'Artisan';
    final providerCity = q['providerCity'] as String?;
    final trustScore = _toInt(q['trustScore'] ?? q['providerTrustScore']);
    final workItems = q['workItems'] as List? ?? [];
    final isPending = status == 'pending';
    final isAccepted = status == 'accepted';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: widget.isBest ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: widget.isBest
            ? const BorderSide(color: Colors.green, width: 2)
            : isAccepted
                ? const BorderSide(color: Color(0xFF1976D2), width: 2)
                : BorderSide.none,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Badge meilleur prix ──────────────────────────────────────────
        if (widget.isBest)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.thumb_up_outlined, color: Colors.white, size: 14),
              SizedBox(width: 6),
              Text('Meilleur prix', style: TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Profil artisan ──────────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundImage: q['providerPhotoUrl'] != null
                    ? NetworkImage(q['providerPhotoUrl']) : null,
                backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
                child: q['providerPhotoUrl'] == null
                    ? const Icon(Icons.handyman, color: Color(0xFF1976D2), size: 24) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(providerName, style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
                if (providerCity != null)
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(providerCity, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                if (trustScore > 0) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.shield_outlined, size: 13,
                        color: trustScore >= 80 ? Colors.green : Colors.orange),
                    const SizedBox(width: 3),
                    Text('$trustScore% confiance',
                        style: TextStyle(
                          fontSize: 12,
                          color: trustScore >= 80 ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w500,
                        )),
                  ]),
                ],
              ])),

              // Montant
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${_fmt(q['amount'])} FCFA',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18,
                        color: Color(0xFF1976D2))),
                if (status == 'accepted')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('✅ Accepté',
                        style: TextStyle(color: Color(0xFF1976D2),
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ]),
            ]),
            const SizedBox(height: 12),

            // ── Détails du devis ────────────────────────────────────────
            if (q['description'] != null && q['description'].toString().isNotEmpty) ...[
              Text(q['description'].toString(),
                  style: const TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 10),
            ],

            // Infos clés
            Wrap(spacing: 12, runSpacing: 6, children: [
              if (q['estimatedDays'] != null)
                _infoBadge(Icons.schedule_outlined,
                    '${q['estimatedDays']} jour${_toInt(q['estimatedDays']) > 1 ? 's' : ''}',
                    Colors.blue),
              if (q['warrantyDays'] != null && _toInt(q['warrantyDays']) > 0)
                _infoBadge(Icons.verified_outlined,
                    'Garantie ${q['warrantyDays']}j', Colors.green),
              if (q['materialsIncluded'] == true)
                _infoBadge(Icons.inventory_2_outlined, 'Matériaux inclus', Colors.orange),
            ]),

            // Détail travaux (pliable)
            if (workItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(children: [
                  const Icon(Icons.list_alt_outlined, size: 16, color: Color(0xFF1976D2)),
                  const SizedBox(width: 6),
                  Text('${workItems.length} poste${workItems.length > 1 ? 's' : ''} de travaux',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1976D2),
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: Colors.grey),
                ]),
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                ...workItems.map((item) {
                  final it = item as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(it['task'] as String? ?? '',
                          style: const TextStyle(fontSize: 12))),
                      Text('${_fmt(it['unitPrice'])} FCFA',
                          style: const TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600, color: Color(0xFF1976D2))),
                    ]),
                  );
                }),
              ],
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Actions ─────────────────────────────────────────────────
            Row(children: [
              // Voir portfolio
              if (providerId != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/artisans/portfolio/$providerId'),
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Voir portfolio', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                      side: const BorderSide(color: Color(0xFF1976D2)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              if (providerId != null) const SizedBox(width: 10),

              // Accepter (seulement si pending)
              if (isPending)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _accepting ? null : _accept,
                    icon: _accepting
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Accepter', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ]),

            // Message artisan
            if (providerId != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => context.push(
                    '/messages/chat/$providerId',
                    extra: {
                      'quoteData': {
                        'quoteId': q['id'],
                        'requestId': widget.requestId,
                        'providerName': providerName,
                        'amount': q['amount'],
                        'description': q['description'],
                        'estimatedDays': q['estimatedDays'],
                        'status': status,
                      },
                    },
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 15),
                  label: const Text('Discuter avec l\'artisan',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _infoBadge(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ]),
  );
}
