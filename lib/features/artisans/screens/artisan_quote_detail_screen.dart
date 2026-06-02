import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';

class ArtisanQuoteDetailScreen extends ConsumerStatefulWidget {
  final String quoteId;
  final String requestId;
  const ArtisanQuoteDetailScreen({super.key, required this.quoteId, required this.requestId});

  @override
  ConsumerState<ArtisanQuoteDetailScreen> createState() => _ArtisanQuoteDetailScreenState();
}

class _ArtisanQuoteDetailScreenState extends ConsumerState<ArtisanQuoteDetailScreen> {
  Map<String, dynamic>? _quote;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/artisans/requests/${widget.requestId}/quotes');
      final quotes = res.data as List;
      final q = quotes.firstWhere((q) => q['id'] == widget.quoteId, orElse: () => null);
      setState(() { _quote = q != null ? Map<String, dynamic>.from(q) : null; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  bool get _isProvider =>
      ref.read(authStateProvider).value?.user?['activeMode'] == 'provider';

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditQuoteSheet(
        quote: _quote!,
        quoteId: widget.quoteId,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _quote?['status'] as String? ?? '';
    final canEdit = _isProvider && status == 'pending';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Détail du devis'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier le devis',
              onPressed: _openEditSheet,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _quote == null
              ? const Center(child: Text('Devis introuvable'))
              : _buildContent(),
      // FAB "Discuter" pour l'artisan côté provider
      floatingActionButton: (!_loading && _quote != null && _isProvider && status == 'pending')
          ? FloatingActionButton.extended(
              onPressed: () {
                final clientId = _quote!['clientId'] as String?;
                if (clientId != null) context.go('/messages/chat/$clientId');
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Discuter'),
              backgroundColor: const Color(0xFF1976D2),
            )
          : null,
    );
  }

  Widget _buildContent() {
    final q = _quote!;
    final status = q['status'] as String? ?? 'pending';
    final progressPhotos = q['progressPhotos'] as List? ?? [];
    final dispute = q['disputeStatus'] as String? ?? 'none';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Résumé devis ─────────────────────────────────────────────────
        _DevisSummaryCard(quote: q),
        const SizedBox(height: 10),

        // ── Bouton contrat PDF (si accepté) ──────────────────────────────
        if (['accepted', 'work_done', 'released'].contains(status))
          _ContractButton(quoteId: widget.quoteId),
        const SizedBox(height: 10),

        // ── Détail travaux ───────────────────────────────────────────────
        if ((q['workItems'] as List? ?? []).isNotEmpty) ...[
          _WorkItemsCard(items: q['workItems'] as List),
          const SizedBox(height: 16),
        ],

        // ── Suivi chantier ───────────────────────────────────────────────
        _ProgressTimelineCard(
          photos: progressPhotos,
          quoteId: widget.quoteId,
          isProvider: _isProvider,
          status: status,
          onAdded: _load,
        ),
        const SizedBox(height: 16),

        // ── Litige ───────────────────────────────────────────────────────
        if (status == 'work_done' && !_isProvider && dispute == 'none') ...[
          _DisputeCard(quoteId: widget.quoteId, onOpened: _load),
          const SizedBox(height: 16),
        ],
        if (dispute != 'none')
          _DisputeStatusCard(disputeStatus: dispute, reason: q['disputeReason']),
      ]),
    );
  }
}

// ── Bouton téléchargement contrat ─────────────────────────────────────────────
class _ContractButton extends ConsumerWidget {
  final String quoteId;
  const _ContractButton({required this.quoteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const baseUrl = 'http://51.83.40.138:3005/api/v1';
    final contractUrl = '$baseUrl/artisans/quotes/$quoteId/contract.pdf';

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final uri = Uri.parse(contractUrl);
          try {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              // Fallback : copier le lien
              await Clipboard.setData(ClipboardData(text: contractUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('📋 Lien copié — ouvrez dans votre navigateur'),
                  backgroundColor: Color(0xFF1976D2),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            }
          } catch (_) {
            await Clipboard.setData(ClipboardData(text: contractUrl));
          }
        },
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: const Text('Voir / Télécharger le contrat'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1976D2),
          side: const BorderSide(color: Color(0xFF1976D2)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

// ── Résumé devis ──────────────────────────────────────────────────────────────
class _DevisSummaryCard extends StatelessWidget {
  final Map<String, dynamic> quote;
  const _DevisSummaryCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    final status = quote['status'] as String? ?? 'pending';
    final statusColors = {
      'pending': Colors.orange, 'accepted': Colors.blue,
      'work_done': Colors.purple, 'released': Colors.green, 'rejected': Colors.grey,
    };
    final statusLabels = {
      'pending': '⏳ En attente', 'accepted': '✅ Accepté',
      'work_done': '🔨 Travaux terminés', 'released': '💰 Payé', 'rejected': '❌ Refusé',
    };
    final color = statusColors[status] ?? Colors.grey;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(quote['title'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color),
            ),
            child: Text(statusLabels[status] ?? status,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 12),
        _row(Icons.attach_money, 'Montant total', '${quote['amount']} FCFA'),
        if (quote['laborCost'] != null && (quote['laborCost'] as num) > 0)
          _row(Icons.handyman_outlined, 'Main d\'œuvre', '${quote['laborCost']} FCFA'),
        if (quote['materialsCost'] != null && (quote['materialsCost'] as num) > 0)
          _row(Icons.inventory_2_outlined, 'Matériaux', '${quote['materialsCost']} FCFA'),
        if (quote['estimatedDays'] != null)
          _row(Icons.schedule_outlined, 'Délai estimé', '${quote['estimatedDays']} jour(s)'),
        if (quote['warrantyDays'] != null && (quote['warrantyDays'] as num) > 0)
          _row(Icons.verified_outlined, 'Garantie', '${quote['warrantyDays']} jour(s)'),
        if (quote['materialsIncluded'] != null)
          _row(Icons.check_circle_outline,
              quote['materialsIncluded'] == true ? 'Matériaux inclus' : 'Matériaux non inclus',
              ''),
      ])),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.grey),
      const SizedBox(width: 8),
      Text('$label : ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Détail travaux ────────────────────────────────────────────────────────────
class _WorkItemsCard extends StatelessWidget {
  final List items;
  const _WorkItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.list_alt_outlined, color: Color(0xFF1976D2), size: 20),
          SizedBox(width: 8),
          Text('Détail des travaux', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 12),
        ...items.map((item) {
          final i = item as Map<String, dynamic>;
          final total = (i['unitPrice'] as num? ?? 0) * (i['quantity'] as num? ?? 1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(i['task'] as String? ?? '',
                  style: const TextStyle(fontSize: 13))),
              Text('×${i['quantity'] ?? 1}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              Text('${total.toInt()} FCFA',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1976D2))),
            ]),
          );
        }),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Text('Total : ', style: TextStyle(fontWeight: FontWeight.w700)),
          Text(
            '${items.fold<int>(0, (s, i) {
              final it = i as Map<String, dynamic>;
              return s + ((it['unitPrice'] as num? ?? 0) * (it['quantity'] as num? ?? 1)).toInt();
            })} FCFA',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1976D2)),
          ),
        ]),
      ])),
    );
  }
}

// ── Timeline suivi chantier ───────────────────────────────────────────────────
class _ProgressTimelineCard extends ConsumerStatefulWidget {
  final List photos;
  final String quoteId;
  final bool isProvider;
  final String status;
  final VoidCallback onAdded;
  const _ProgressTimelineCard({
    required this.photos, required this.quoteId,
    required this.isProvider, required this.status, required this.onAdded,
  });

  @override
  ConsumerState<_ProgressTimelineCard> createState() => _ProgressTimelineCardState();
}

class _ProgressTimelineCardState extends ConsumerState<_ProgressTimelineCard> {
  bool _adding = false;
  final _captionCtrl = TextEditingController();
  String _stage = 'during';
  final _picker = ImagePicker();

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file == null) return;
    setState(() => _adding = true);
    try {
      final api = ref.read(apiClientProvider);
      // Upload vers /media/image
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: 'photo.jpg'),
      });
      final uploadRes = await api.uploadFile('/media/image', formData);
      final imageUrl = uploadRes.data['url'] as String;
      // Envoyer au chantier
      await api.post('/artisans/quotes/${widget.quoteId}/progress', data: {
        'stage': _stage,
        'url': imageUrl,
        'caption': _captionCtrl.text.trim(),
      });
      _captionCtrl.clear();
      widget.onAdded();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _adding = false);
  }

  void _showPickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          const Text('Ajouter une photo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1976D2)),
            title: const Text('Prendre une photo'),
            onTap: () { Navigator.pop(context); _pickAndUpload(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF1976D2)),
            title: const Text('Choisir depuis la galerie'),
            onTap: () { Navigator.pop(context); _pickAndUpload(ImageSource.gallery); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stageColors = {'before': Colors.grey, 'during': Colors.orange, 'after': Colors.green};
    final stageLabels = {'before': 'Avant', 'during': 'En cours', 'after': 'Après'};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.photo_camera_outlined, color: Color(0xFF1976D2), size: 20),
          SizedBox(width: 8),
          Text('Suivi du chantier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 12),

        if (widget.photos.isEmpty)
          Center(child: Column(children: [
            Icon(Icons.construction_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 6),
            Text(widget.isProvider
                ? 'Ajoutez des photos pour montrer votre avancement'
                : 'Aucune photo d\'avancement pour l\'instant',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center),
          ]))
        else
          // Timeline photos
          Column(children: widget.photos.map((p) {
            final photo = p as Map<String, dynamic>;
            final stage = photo['stage'] as String? ?? 'during';
            final color = stageColors[stage] ?? Colors.grey;
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(width: 28, height: 28,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Center(child: Text(
                    stage == 'before' ? '1' : stage == 'during' ? '2' : '3',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  )),
                ),
                if (widget.photos.last != p)
                  Container(width: 2, height: 60, color: Colors.grey.shade200),
              ]),
              const SizedBox(width: 10),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(stageLabels[stage] ?? stage,
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photo['url'] as String? ?? '',
                      height: 140, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80, color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    ),
                  ),
                  if (photo['caption'] != null && photo['caption'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(photo['caption'].toString(),
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ]),
              )),
            ]);
          }).toList()),

        // Ajout photo via caméra/galerie (artisan uniquement)
        if (widget.isProvider && ['accepted', 'work_done'].contains(widget.status)) ...[
          const Divider(),
          const SizedBox(height: 10),
          const Text('Ajouter une photo de chantier',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          // Sélecteur étape
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'before', icon: Icon(Icons.looks_one_outlined), label: Text('Avant')),
              ButtonSegment(value: 'during', icon: Icon(Icons.looks_two_outlined), label: Text('En cours')),
              ButtonSegment(value: 'after',  icon: Icon(Icons.looks_3_outlined),  label: Text('Après')),
            ],
            selected: {_stage},
            onSelectionChanged: (v) => setState(() => _stage = v.first),
          ),
          const SizedBox(height: 10),
          // Description optionnelle
          TextField(
            controller: _captionCtrl,
            decoration: InputDecoration(
              labelText: 'Description (optionnel)',
              prefixIcon: const Icon(Icons.comment_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          // Boutons caméra + galerie
          _adding
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator()))
              : Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickAndUpload(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Caméra'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1976D2),
                        side: const BorderSide(color: Color(0xFF1976D2)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickAndUpload(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Galerie'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
        ],
      ])),
    );
  }
}

// ── Litige ────────────────────────────────────────────────────────────────────
class _DisputeCard extends ConsumerStatefulWidget {
  final String quoteId;
  final VoidCallback onOpened;
  const _DisputeCard({required this.quoteId, required this.onOpened});

  @override
  ConsumerState<_DisputeCard> createState() => _DisputeCardState();
}

class _DisputeCardState extends ConsumerState<_DisputeCard> {
  bool _loading = false;

  Future<void> _open() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Ouvrir un litige'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Expliquez le problème avec les travaux réalisés.',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 12),
        TextField(controller: reasonCtrl, maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Raison du litige *',
              border: OutlineInputBorder(),
            )),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
          child: const Text(
            'L\'escrow sera bloqué jusqu\'à arbitrage par l\'équipe W2D.',
            style: TextStyle(fontSize: 12, color: Colors.orange),
          )),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Ouvrir le litige')),
      ],
    ));

    if (ok != true || reasonCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).post('/artisans/quotes/${widget.quoteId}/dispute',
          data: {'reason': reasonCtrl.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Litige ouvert. L\'équipe W2D va examiner votre demande.'),
            backgroundColor: Colors.orange));
        widget.onOpened();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.red.shade200)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.report_problem_outlined, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Text('Problème avec les travaux ?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Si les travaux réalisés ne correspondent pas au devis accepté, '
          'vous pouvez ouvrir un litige. L\'équipe W2D arbitrera sur la base des photos avant/après.',
          style: TextStyle(fontSize: 12, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _open,
            icon: _loading
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                : const Icon(Icons.gavel_outlined, size: 16),
            label: const Text('Ouvrir un litige'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ])),
    );
  }
}

// ── Bottom sheet modification devis (artisan) ─────────────────────────────────
class _EditQuoteSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> quote;
  final String quoteId;
  final VoidCallback onSaved;

  const _EditQuoteSheet({
    required this.quote,
    required this.quoteId,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditQuoteSheet> createState() => _EditQuoteSheetState();
}

class _EditQuoteSheetState extends ConsumerState<_EditQuoteSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _daysCtrl;
  late final TextEditingController _warrantyCtrl;
  late final TextEditingController _laborCtrl;
  late final TextEditingController _materialsCtrl;
  late bool _materialsIncluded;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl   = TextEditingController(text: '${widget.quote['amount'] ?? ''}');
    _descCtrl     = TextEditingController(text: widget.quote['description'] as String? ?? '');
    _daysCtrl     = TextEditingController(text: '${widget.quote['estimatedDays'] ?? ''}');
    _warrantyCtrl = TextEditingController(text: '${widget.quote['warrantyDays'] ?? 0}');
    _laborCtrl    = TextEditingController(text: '${widget.quote['laborCost'] ?? 0}');
    _materialsCtrl= TextEditingController(text: '${widget.quote['materialsCost'] ?? 0}');
    _materialsIncluded = widget.quote['materialsIncluded'] != false;
  }

  @override
  void dispose() {
    _amountCtrl.dispose(); _descCtrl.dispose(); _daysCtrl.dispose();
    _warrantyCtrl.dispose(); _laborCtrl.dispose(); _materialsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).patch('/artisans/quotes/${widget.quoteId}', data: {
        'amount': int.tryParse(_amountCtrl.text.trim()) ?? 0,
        'description': _descCtrl.text.trim(),
        'estimatedDays': int.tryParse(_daysCtrl.text.trim()),
        'warrantyDays': int.tryParse(_warrantyCtrl.text.trim()) ?? 0,
        'laborCost': int.tryParse(_laborCtrl.text.trim()) ?? 0,
        'materialsCost': int.tryParse(_materialsCtrl.text.trim()) ?? 0,
        'materialsIncluded': _materialsIncluded,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Devis mis à jour — le client sera notifié'),
          ]),
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20, right: 20, top: 8,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            )),

            // Titre
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_outlined, color: Color(0xFF1976D2), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Modifier le devis',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Le client verra les modifications immédiatement',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),

            // Montant total
            _field(
              controller: _amountCtrl,
              label: 'Montant total (FCFA) *',
              icon: Icons.attach_money,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null)
                  ? 'Montant invalide' : null,
            ),
            const SizedBox(height: 12),

            // Détail coûts
            Row(children: [
              Expanded(child: _field(
                controller: _laborCtrl,
                label: 'Main d\'œuvre',
                icon: Icons.handyman_outlined,
                keyboardType: TextInputType.number,
              )),
              const SizedBox(width: 10),
              Expanded(child: _field(
                controller: _materialsCtrl,
                label: 'Matériaux',
                icon: Icons.inventory_2_outlined,
                keyboardType: TextInputType.number,
              )),
            ]),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description des travaux',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Délai et garantie
            Row(children: [
              Expanded(child: _field(
                controller: _daysCtrl,
                label: 'Délai (jours)',
                icon: Icons.schedule_outlined,
                keyboardType: TextInputType.number,
              )),
              const SizedBox(width: 10),
              Expanded(child: _field(
                controller: _warrantyCtrl,
                label: 'Garantie (jours)',
                icon: Icons.verified_outlined,
                keyboardType: TextInputType.number,
              )),
            ]),
            const SizedBox(height: 10),

            // Matériaux inclus
            SwitchListTile(
              value: _materialsIncluded,
              onChanged: (v) => setState(() => _materialsIncluded = v),
              title: const Text('Matériaux inclus dans le prix',
                  style: TextStyle(fontSize: 14)),
              secondary: const Icon(Icons.inventory_2_outlined, color: Color(0xFF1976D2)),
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF1976D2),
            ),
            const SizedBox(height: 16),

            // Bouton enregistrer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_saving ? 'Enregistrement...' : 'Enregistrer les modifications'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _DisputeStatusCard extends StatelessWidget {
  final String disputeStatus;
  final String? reason;
  const _DisputeStatusCard({required this.disputeStatus, this.reason});

  @override
  Widget build(BuildContext context) {
    final isResolved = disputeStatus.startsWith('resolved');
    return Card(
      color: isResolved ? Colors.green.shade50 : Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isResolved ? Colors.green.shade200 : Colors.orange.shade200),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isResolved ? Icons.gavel : Icons.hourglass_empty_rounded,
              color: isResolved ? Colors.green : Colors.orange, size: 20),
          const SizedBox(width: 8),
          Text(
            isResolved
                ? disputeStatus == 'resolved_client' ? 'Litige résolu — remboursement' : 'Litige résolu — paiement libéré'
                : '⚖️ Litige en cours d\'examen',
            style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14,
              color: isResolved ? Colors.green : Colors.orange,
            ),
          ),
        ]),
        if (reason != null) ...[
          const SizedBox(height: 6),
          Text('Raison : $reason', style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ])),
    );
  }
}
