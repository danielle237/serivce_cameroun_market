import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../messages/screens/chat_screen.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;
  const PropertyDetailScreen({super.key, required this.propertyId});
  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailState();
}

class _PropertyDetailState extends ConsumerState<PropertyDetailScreen> {
  Map<String, dynamic>? _property;
  bool _loading = true;
  int _photoIndex = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final isOnline = ref.read(isOnlineProvider);
      final res = await api.get('/immobilier/${widget.propertyId}', forceRefresh: isOnline);
      setState(() { _property = Map<String, dynamic>.from(res.data); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  static const _periodLabels = {'jour': '/jour', 'mois': '/mois', 'an': '/an', 'total': ''};

  String _fmt(dynamic v) {
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_property == null) return Scaffold(
      appBar: AppBar(), body: const Center(child: Text('Annonce introuvable')));

    final p = _property!;
    final photos = <String>[];
    if (p['photoPrincipale'] != null) photos.add(p['photoPrincipale'] as String);
    if (p['photos'] is List) photos.addAll((p['photos'] as List).map((e) => e.toString()));
    final prix = _fmt(p['prix']);
    final periode = _periodLabels[p['prixPeriode'] ?? 'mois'] ?? '/mois';
    final equipements = p['equipements'] is List
        ? (p['equipements'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(slivers: [
        // ── Photo + AppBar ────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: photos.isEmpty
              ? Container(color: Colors.grey.shade300,
                  child: const Icon(Icons.home_outlined, size: 80, color: Colors.white54))
              : Stack(children: [
                  PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _photoIndex = i),
                    itemBuilder: (_, i) => CachedNetworkImage(
                      imageUrl: photos[i], fit: BoxFit.cover,
                      placeholder: (_, __) => Shimmer.fromColors(
                        baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
                        child: Container(color: Colors.white)),
                      errorWidget: (_, __, ___) => Container(color: Colors.grey.shade300),
                      memCacheHeight: 560,
                    ),
                  ),
                  if (photos.length > 1)
                    Positioned(bottom: 12, right: 0, left: 0,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(photos.length, (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: _photoIndex == i ? 18 : 6, height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: _photoIndex == i ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(4)),
                        )))),
                ]),
          ),
        ),

        // ── Contenu ───────────────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Titre + badges
            Row(children: [
              if (p['verified'] == true) ...[
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(6)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified_rounded, size: 11, color: Colors.white),
                    SizedBox(width: 3),
                    Text('Vérifié', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ])),
                const SizedBox(width: 6),
              ],
              if (p['featured'] == true)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.amber.shade700, borderRadius: BorderRadius.circular(6)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_rounded, size: 11, color: Colors.white),
                    SizedBox(width: 3),
                    Text('Vedette', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ])),
            ]),
            const SizedBox(height: 8),
            Text(p['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 15, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text('${p['quartier'] ?? ''}${(p['quartier'] ?? '').isNotEmpty && (p['ville'] ?? '').isNotEmpty ? ' · ' : ''}${p['ville'] ?? ''}',
                style: TextStyle(color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 16),

            // Prix
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.2))),
              child: Row(children: [
                Icon(Icons.payments_outlined, color: const Color(0xFF1B5E20), size: 28),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Prix', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  RichText(text: TextSpan(children: [
                    TextSpan(text: '$prix FCFA',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1B5E20))),
                    TextSpan(text: periode,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ])),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // Caractéristiques
            const Text('Caractéristiques', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              if (p['surface'] != null) _InfoChip(Icons.straighten_rounded, '${p['surface']} m²'),
              if (p['pieces'] != null) _InfoChip(Icons.meeting_room_outlined, '${p['pieces']} pièces'),
              if (p['chambres'] != null) _InfoChip(Icons.bed_outlined, '${p['chambres']} ch.'),
              if (p['sallesDeBain'] != null) _InfoChip(Icons.shower_outlined, '${p['sallesDeBain']} SDB'),
            ]),

            // Équipements
            if (equipements.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Équipements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: equipements.map((e) =>
                Chip(label: Text(e, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: Colors.grey.shade200)),
              ).toList()),
            ],

            // Description
            if (p['description'] != null && (p['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(p['description'] as String,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
            ],

            // Agence / propriétaire
            if (p['agencyName'] != null || p['publishedBy'] != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF1B5E20).withOpacity(0.15),
                  child: const Icon(Icons.person_outline, color: Color(0xFF1B5E20))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['agencyName'] ?? 'Propriétaire',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('Annonceur', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ]),
              ]),
            ],
            const SizedBox(height: 100),
          ]),
        )),
      ]),

      // ── Boutons bas ───────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            // Chat in-app
            Expanded(child: OutlinedButton.icon(
              onPressed: () {
                final ownerId = p['publishedBy'] as String?;
                if (ownerId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Annonceur non disponible')));
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                  contactId: ownerId,
                  marketplaceData: {
                    'type': 'immobilier',
                    'propertyId': p['id'],
                    'propertyTitle': p['title'] ?? '',
                    'propertyPhoto': p['photoPrincipale'] ?? '',
                  },
                )));
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Message'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1B5E20),
                side: const BorderSide(color: Color(0xFF1B5E20)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 12),
            // Réserver (meublé/jour) ou Visiter (autres)
            Expanded(child: ElevatedButton.icon(
              onPressed: () {
                if (p['categorySlug'] == 'meuble_journalier') {
                  _showBookingSheet(context, p);
                } else {
                  _showVisitSheet(context, p);
                }
              },
              icon: Icon(p['categorySlug'] == 'meuble_journalier'
                ? Icons.hotel_outlined
                : Icons.calendar_today_outlined),
              label: Text(p['categorySlug'] == 'meuble_journalier'
                ? 'Réserver' : 'Visiter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ]),
        ),
      ),
    );
  }

  void _showBookingSheet(BuildContext ctx, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MeubleBookingSheet(property: p),
    );
  }

  void _showVisitSheet(BuildContext ctx, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VisitSheet(property: p, onConfirmed: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rendez-vous envoyé ! L\'annonceur vous confirmera.'),
          backgroundColor: Color(0xFF1B5E20)));
      }),
    );
  }
}

// ── Feuille de réservation meublé journalier ──────────────────────────────────
class _MeubleBookingSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> property;
  const _MeubleBookingSheet({required this.property});
  @override
  ConsumerState<_MeubleBookingSheet> createState() => _MeubleBookingSheetState();
}

class _MeubleBookingSheetState extends ConsumerState<_MeubleBookingSheet> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _dateIn;
  DateTime? _dateOut;
  bool _selectingOut = false;
  Set<String> _occupied = {};

  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingDates = true;
  bool _loadDateError = false;

  static const _mois = [
    '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];
  static const _jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  void initState() { super.initState(); _loadOccupied(); }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _loadOccupied() async {
    setState(() { _loadingDates = true; _loadDateError = false; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/immobilier/${widget.property['id']}/occupied-dates')
          .timeout(const Duration(seconds: 10));
      setState(() {
        _occupied = (res.data is List)
            ? Set<String>.from((res.data as List).map((e) => e.toString()))
            : {};
        _loadingDates = false;
      });
    } catch (_) {
      setState(() { _loadingDates = false; _loadDateError = true; });
    }
  }

  bool _isOccupied(DateTime d) => _occupied.contains(_fmt(d));
  bool _isPast(DateTime d) {
    // Minimum check-in = demain
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return d.isBefore(DateTime(tomorrow.year, tomorrow.month, tomorrow.day));
  }
  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  bool _isInRange(DateTime d) {
    if (_dateIn == null || _dateOut == null) return false;
    return d.isAfter(_dateIn!) && d.isBefore(_dateOut!);
  }

  int get _nbNuits {
    if (_dateIn == null || _dateOut == null) return 0;
    return _dateOut!.difference(_dateIn!).inDays;
  }

  int get _prixParNuit => int.tryParse(widget.property['prix']?.toString() ?? '') ?? 0;
  int get _total => _nbNuits * _prixParNuit;

  String _fmtMoney(int v) {
    final s = v.toString(); final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  List<DateTime?> _daysInGrid() {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startPad = (first.weekday - 1) % 7;
    final last = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final cells = <DateTime?>[];
    for (int i = 0; i < startPad; i++) cells.add(null);
    for (int d = 1; d <= last.day; d++) {
      cells.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
    }
    while (cells.length % 7 != 0) cells.add(null);
    return cells;
  }

  void _onDayTap(DateTime day) {
    if (_isPast(day) || _isOccupied(day)) return;
    setState(() {
      if (!_selectingOut) {
        _dateIn = day; _dateOut = null; _selectingOut = true;
      } else {
        if (day.isBefore(_dateIn!)) {
          _dateIn = day; _dateOut = null; _selectingOut = true;
        } else {
          // Vérifier qu'aucun jour occupé dans la plage
          bool conflict = false;
          DateTime c = _dateIn!.add(const Duration(days: 1));
          while (c.isBefore(day)) {
            if (_isOccupied(c)) { conflict = true; break; }
            c = c.add(const Duration(days: 1));
          }
          if (conflict) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Il y a des nuits indisponibles dans cette plage')));
          } else {
            _dateOut = day; _selectingOut = false;
          }
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner votre nom et téléphone')));
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/immobilier/${widget.property['id']}/book', data: {
        'dateIn':     _fmt(_dateIn!),
        'dateOut':    _fmt(_dateOut!),
        'guestName':  _nameCtrl.text.trim(),
        'guestPhone': _phoneCtrl.text.trim(),
      });

      final authUrl = res.data['authUrl'] as String? ?? '';
      if (mounted) Navigator.pop(context);

      if (authUrl.isNotEmpty) {
        // Ouvrir l'URL de paiement NotchPay
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Réservation créée ! Redirection paiement…'),
          backgroundColor: const Color(0xFF1B5E20),
          action: SnackBarAction(
            label: 'Payer',
            textColor: Colors.white,
            onPressed: () {
              // TODO: url_launcher → authUrl
            }),
        ));
      } else {
        // Dev mode : pas de paiement
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Réservation enregistrée avec succès !'),
          backgroundColor: Color(0xFF1B5E20)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : ${e.toString()}'),
        backgroundColor: Colors.red.shade700));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final days  = _daysInGrid();
    final ready = _dateIn != null && _dateOut != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Handle
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),

        // Titre + prix
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Location journalière',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(widget.property['title'] ?? '',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00695C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: RichText(text: TextSpan(children: [
              TextSpan(text: '${_fmtMoney(_prixParNuit)} FCFA',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF00695C))),
              const TextSpan(text: '/nuit',
                style: TextStyle(fontSize: 11, color: Color(0xFF00695C))),
            ])),
          ),
        ]),
        const SizedBox(height: 16),

        // Sélection type
        Row(children: [
          _StepChip(label: 'Arrivée', active: !_selectingOut || _dateIn == null,
            value: _dateIn != null ? '${_dateIn!.day} ${_mois[_dateIn!.month]}' : '—'),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          _StepChip(label: 'Départ', active: _selectingOut,
            value: _dateOut != null ? '${_dateOut!.day} ${_mois[_dateOut!.month]}' : '—'),
        ]),
        const SizedBox(height: 12),

        // ── Calendrier ──────────────────────────────────────────────────
        Row(children: [
          GestureDetector(
            onTap: () => setState(() =>
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.chevron_left_rounded, size: 18))),
          Expanded(child: Center(child: Text(
            '${_mois[_focusedMonth.month]} ${_focusedMonth.year}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)))),
          GestureDetector(
            onTap: () => setState(() =>
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.chevron_right_rounded, size: 18))),
        ]),
        const SizedBox(height: 8),

        Row(children: _jours.map((j) => Expanded(child: Center(
          child: Text(j, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: Colors.grey.shade500))))).toList()),
        const SizedBox(height: 4),

        if (_loadDateError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Icon(Icons.wifi_off_rounded, size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Expanded(child: Text('Impossible de charger les disponibilités. Toutes les dates semblent libres.',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade700))),
              TextButton(onPressed: _loadOccupied,
                child: const Text('Réessayer', style: TextStyle(fontSize: 11))),
            ]),
          ),
        _loadingDates
          ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 1.1),
              itemCount: days.length,
              itemBuilder: (_, i) {
                final day = days[i];
                if (day == null) return const SizedBox();
                final past     = _isPast(day);
                final occupied = _isOccupied(day);
                final disabled = past || occupied;
                final isIn     = _dateIn != null && _fmt(day) == _fmt(_dateIn!);
                final isOut    = _dateOut != null && _fmt(day) == _fmt(_dateOut!);
                final inRange  = _isInRange(day);
                final isToday  = _fmt(day) == _fmt(DateTime.now());

                Color bg = Colors.transparent;
                Color textColor = Colors.black87;
                if (disabled) textColor = Colors.grey.shade300;
                if (isIn || isOut) { bg = const Color(0xFF00695C); textColor = Colors.white; }
                else if (inRange) { bg = const Color(0xFF00695C).withOpacity(0.12); textColor = const Color(0xFF00695C); }
                if (occupied && !past) textColor = Colors.red.shade300;

                return GestureDetector(
                  onTap: disabled ? null : () => _onDayTap(day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(6),
                      border: isToday && !isIn && !isOut
                        ? Border.all(color: const Color(0xFF00695C), width: 1.5) : null),
                    child: Stack(alignment: Alignment.center, children: [
                      Text('${day.day}',
                        style: TextStyle(fontSize: 12,
                          fontWeight: isIn || isOut ? FontWeight.bold : FontWeight.normal,
                          color: textColor)),
                      if (occupied && !past)
                        Positioned(bottom: 2, child: Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(color: Colors.red.shade300, shape: BoxShape.circle))),
                    ]),
                  ),
                );
              },
            ),

        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 8, height: 8,
            decoration: BoxDecoration(color: Colors.red.shade300, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('Indisponible', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(width: 16),
          Container(width: 8, height: 8,
            decoration: const BoxDecoration(color: Color(0xFF00695C), shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('Sélectionné', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),

        // ── Résumé + infos client ─────────────────────────────────────────
        if (ready) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF00695C).withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00695C).withOpacity(0.2))),
            child: Column(children: [
              _SummaryRow('Arrivée', '${_dateIn!.day} ${_mois[_dateIn!.month]} ${_dateIn!.year}'),
              _SummaryRow('Départ',  '${_dateOut!.day} ${_mois[_dateOut!.month]} ${_dateOut!.year}'),
              _SummaryRow('Durée',   '$_nbNuits nuit${_nbNuits > 1 ? "s" : ""}'),
              const Divider(height: 16),
              _SummaryRow('${_fmtMoney(_prixParNuit)} × $_nbNuits', '${_fmtMoney(_total)} FCFA',
                bold: true, color: const Color(0xFF00695C)),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(controller: _nameCtrl,
            decoration: _inputDeco('Votre nom complet', Icons.person_outline)),
          const SizedBox(height: 10),
          TextField(controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: _inputDeco('Téléphone', Icons.phone_outlined)),
        ],

        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: ready && !_loading ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00695C),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  ready ? 'Réserver · ${_fmtMoney(_total)} FCFA' : 'Sélectionnez vos dates',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          )),
      ])),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    hintText: label, prefixIcon: Icon(icon, size: 18),
    filled: true, fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF00695C))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

class _StepChip extends StatelessWidget {
  final String label;
  final String value;
  final bool active;
  const _StepChip({required this.label, required this.value, required this.active});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: active ? const Color(0xFF00695C) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: active ? const Color(0xFF00695C) : Colors.grey.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10,
        color: active ? Colors.white70 : Colors.grey.shade500)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
        color: active ? Colors.white : Colors.black87)),
    ]),
  ));
}

class _SummaryRow extends StatelessWidget {
  final String left, right;
  final bool bold;
  final Color? color;
  const _SummaryRow(this.left, this.right, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(left, style: TextStyle(fontSize: 13,
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        color: color ?? Colors.grey.shade700)),
      Text(right, style: TextStyle(fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        color: color ?? Colors.black87)),
    ]),
  );
}

// ── Feuille de prise de rendez-vous avec calendrier ──────────────────────────
class _VisitSheet extends StatefulWidget {
  final Map<String, dynamic> property;
  final VoidCallback onConfirmed;
  const _VisitSheet({required this.property, required this.onConfirmed});
  @override
  State<_VisitSheet> createState() => _VisitSheetState();
}

class _VisitSheetState extends State<_VisitSheet> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  int? _selectedHour;          // index dans _slots
  final _noteCtrl = TextEditingController();

  static const _slots = [8, 9, 10, 11, 14, 15, 16, 17];
  static const _jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  static const _mois  = [
    '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  bool _isPast(DateTime d) {
    final today = DateTime.now();
    return d.isBefore(DateTime(today.year, today.month, today.day));
  }

  bool _isWeekend(DateTime d) => d.weekday == 7; // Dim uniquement

  List<DateTime?> _daysInGrid() {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    // Lundi = 1, on pad à gauche
    final startPad = (first.weekday - 1) % 7;
    final last = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final cells = <DateTime?>[];
    for (int i = 0; i < startPad; i++) cells.add(null);
    for (int d = 1; d <= last.day; d++) {
      cells.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
    }
    // compléter à 42 cases (6 semaines)
    while (cells.length % 7 != 0) cells.add(null);
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInGrid();
    final canConfirm = _selectedDate != null && _selectedHour != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Drag handle
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // Titre
          const Text('Prendre rendez-vous', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(widget.property['title'] ?? '',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),

          // ── Calendrier ──────────────────────────────────────────────────
          // En-tête mois
          Row(children: [
            GestureDetector(
              onTap: () => setState(() =>
                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.chevron_left_rounded, size: 20))),
            Expanded(child: Center(
              child: Text(
                '${_mois[_focusedMonth.month]} ${_focusedMonth.year}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)))),
            GestureDetector(
              onTap: () => setState(() =>
                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.chevron_right_rounded, size: 20))),
          ]),
          const SizedBox(height: 12),

          // Jours de la semaine
          Row(children: _jours.map((j) => Expanded(
            child: Center(child: Text(j,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: j == 'Dim' ? Colors.red.shade300 : Colors.grey.shade500))))).toList()),
          const SizedBox(height: 6),

          // Grille jours
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4,
              childAspectRatio: 1.1),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final day = days[i];
              if (day == null) return const SizedBox();

              final isPast    = _isPast(day);
              final isWeekend = _isWeekend(day);
              final disabled  = isPast || isWeekend;
              final isToday   = day.day == DateTime.now().day &&
                                day.month == DateTime.now().month &&
                                day.year == DateTime.now().year;
              final isSel     = _selectedDate != null &&
                                day.day == _selectedDate!.day &&
                                day.month == _selectedDate!.month &&
                                day.year == _selectedDate!.year;

              return GestureDetector(
                onTap: disabled ? null : () => setState(() {
                  _selectedDate = day;
                  _selectedHour = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF1B5E20) : isToday ? const Color(0xFF1B5E20).withOpacity(0.08) : null,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSel ? Border.all(color: const Color(0xFF1B5E20), width: 1.5) : null,
                  ),
                  child: Center(child: Text('${day.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSel || isToday ? FontWeight.bold : FontWeight.normal,
                      color: isSel ? Colors.white
                           : disabled ? Colors.grey.shade300
                           : isWeekend ? Colors.red.shade300
                           : Colors.black87,
                    ))),
                ),
              );
            },
          ),

          // ── Créneaux horaires ───────────────────────────────────────────
          if (_selectedDate != null) ...[
            const SizedBox(height: 20),
            Text('Créneau — ${_selectedDate!.day} ${_mois[_selectedDate!.month]}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: _slots.map((h) {
              final isSel = _selectedHour == h;
              return GestureDetector(
                onTap: () => setState(() => _selectedHour = h),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF1B5E20) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? const Color(0xFF1B5E20) : Colors.grey.shade200)),
                  child: Text('${h.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isSel ? Colors.white : Colors.black87)),
                ),
              );
            }).toList()),
          ],

          // ── Note optionnelle ────────────────────────────────────────────
          if (_selectedDate != null && _selectedHour != null) ...[
            const SizedBox(height: 20),
            const Text('Note (optionnel)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ex : Je serai en voiture, garez-vous devant…',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                filled: true, fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1B5E20))),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Résumé + bouton ─────────────────────────────────────────────
          if (canConfirm)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.event_available_rounded, color: Color(0xFF1B5E20), size: 20),
                const SizedBox(width: 10),
                Text(
                  '${_selectedDate!.day} ${_mois[_selectedDate!.month]} ${_selectedDate!.year}'
                  '  ·  ${_selectedHour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),

          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: canConfirm ? () {
                Navigator.pop(context);
                widget.onConfirmed();
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(
                canConfirm ? 'Confirmer le rendez-vous' : 'Choisissez une date et un créneau',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            )),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: const Color(0xFF1B5E20)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]));
}
