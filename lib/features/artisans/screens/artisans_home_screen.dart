import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_translations.dart';

final artisanRequestsProvider = FutureProvider.autoDispose<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/artisans/requests', params: {'mine': 'true'}, forceRefresh: true);
  return List.from(res.data);
});

class ArtisansHomeScreen extends ConsumerWidget {
  const ArtisansHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(artisanRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.of(context).t('artisans')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: AppTranslations.of(context).t('find_artisan'),
            onPressed: () => context.push('/artisans/search'),
          ),
          Consumer(builder: (_, ref, __) {
            final myId = ref.read(authStateProvider).value?.user?['id'];
            if (myId == null) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              tooltip: AppTranslations.of(context).t('my_portfolio'),
              onPressed: () => context.push('/artisans/portfolio/$myId'),
            );
          }),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer(builder: (_, ref, __) {
            final isProvider = ref.read(authStateProvider).value?.user?['activeMode'] == 'provider';
            if (!isProvider) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton.extended(
                heroTag: 'urgence',
                onPressed: () => _showUrgenceSheet(context, ref),
                icon: const Icon(Icons.flash_on_rounded),
                label: Text(AppTranslations.of(context).t('available_now')),
                backgroundColor: Colors.red,
              ),
            );
          }),
          FloatingActionButton.extended(
            heroTag: 'new',
            onPressed: () => context.push('/artisans/request'),
            icon: const Icon(Icons.add),
            label: Text(AppTranslations.of(context).t('new_request')),
          ),
        ],
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 12),
          Text('$e', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => ref.invalidate(artisanRequestsProvider), child: Text(AppTranslations.of(context).t('retry'))),
        ])),
        data: (requests) => requests.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.build_outlined, size: 80, color: AppColors.textLight),
                const SizedBox(height: 16),
                Text(AppTranslations.of(context).t('no_requests'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(AppTranslations.of(context).t('post_to_find_artisan'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push('/artisans/request'),
                  icon: const Icon(Icons.add),
                  label: Text(AppTranslations.of(context).t('publish_request')),
                ),
              ]))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(artisanRequestsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (_, i) => _RequestCard(
                    request: requests[i],
                    onRefresh: () => ref.invalidate(artisanRequestsProvider),
                  ),
                ),
              ),
      ),
    );
  }
}


void _showUrgenceSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(
            color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.flash_on_rounded, color: Colors.red, size: 24),
            SizedBox(width: 10),
            Expanded(child: Text(
              'En activant ce mode, vous indiquez que vous êtes disponible immédiatement.\n'
              'Tous les clients à proximité recevront une notification SMS.',
              style: TextStyle(fontSize: 13, color: Colors.red),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(apiClientProvider).patch('/artisans/availability',
                    data: {'available': true});
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('🔴 Disponibilité activée ! Les clients ont été notifiés.'),
                    backgroundColor: Colors.green));
              } catch (_) {}
            },
            icon: const Icon(Icons.flash_on_rounded),
            label: const Text('Activer la disponibilité immédiate', style: TextStyle(fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await ref.read(apiClientProvider).patch('/artisans/availability',
                data: {'available': false});
          },
          child: const Text('Désactiver', style: TextStyle(color: Colors.grey)),
        ),
      ]),
    ),
  );
}

class _RequestCard extends ConsumerStatefulWidget {
  final dynamic request;
  final VoidCallback onRefresh;
  const _RequestCard({required this.request, required this.onRefresh});
  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _actLoading = false;
  // État local — mis à jour immédiatement après cancel/delete
  late String _localStatus;

  @override
  void initState() {
    super.initState();
    _localStatus = widget.request['status'] as String? ?? 'pending';
  }

  static const _statusColors = {
    'pending': AppColors.warning,
    'quoted': AppColors.info,
    'completed': AppColors.success,
    'cancelled': AppColors.textSecondary,
  };
  static const _statusLabels = {
    'pending': '⏳ En attente',
    'quoted': '📋 Devis reçu',
    'completed': '✅ Terminé',
    'cancelled': '❌ Annulée',
  };

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la demande ?'),
        content: const Text('La demande sera marquée comme annulée. Les artisans ne pourront plus envoyer de devis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Annuler la demande'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _actLoading = true);
    try {
      await ref.read(apiClientProvider).patch('/artisans/requests/${widget.request['id']}/cancel');
      if (mounted) {
        setState(() => _localStatus = 'cancelled'); // mise à jour immédiate
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _actLoading = false);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer définitivement ?'),
        content: const Text('Cette action est irréversible. La demande et tous les devis associés seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _actLoading = true);
    try {
      await ref.read(apiClientProvider).delete('/artisans/requests/${widget.request['id']}');
      if (mounted) {
        setState(() => _localStatus = 'deleted'); // masquer la card immédiatement
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _actLoading = false);
  }

  void _edit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditRequestSheet(
        request: Map<String, dynamic>.from(widget.request),
        onSaved: widget.onRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Masquer la card si supprimée
    if (_localStatus == 'deleted') return const SizedBox.shrink();

    final status = _localStatus; // état local → mis à jour immédiatement
    final color = _statusColors[status] ?? AppColors.textSecondary;
    final canEdit = status == 'pending';
    final canCancel = ['pending', 'quoted'].contains(status);
    final canDelete = ['pending', 'cancelled'].contains(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(Icons.build, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.request['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (widget.request['location_address'] != null)
                Text(widget.request['location_address'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(_statusLabels[status] ?? status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          if (widget.request['specialty'] != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.handyman_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(widget.request['specialty'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (widget.request['urgency'] == 'urgent') ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Text('URGENT', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
          ],
          // Bouton évaluer le client (côté artisan, après paiement libéré)
          Consumer(builder: (_, ref, __) {
            final isProvider = ref.read(authStateProvider).value?.user?['activeMode'] == 'provider';
            final isReleased = status == 'released';
            final alreadyRated = widget.request['clientRating'] != null;
            if (!isProvider || !isReleased || alreadyRated) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/artisans/rate-client/${widget.request['id']}',
                    extra: {'clientName': widget.request['clientName'] ?? 'Client'},
                  ),
                  icon: const Icon(Icons.star_outline_rounded, size: 16),
                  label: const Text('Évaluer le client'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber.shade700,
                    side: BorderSide(color: Colors.amber.shade700),
                  ),
                ),
              ),
            );
          }),

          // Bouton évaluer (travaux terminés — côté client)
          if (status == 'completed' && widget.request['providerRating'] == null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(
                  '/artisans/rate/${widget.request['id']}',
                  extra: {'artisanName': widget.request['selectedProviderName'] ?? 'Artisan'},
                ),
                icon: const Icon(Icons.star_outline_rounded, size: 16),
                label: const Text('Évaluer l\'artisan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
              ),
            ),
          ],
          // Bouton voir les devis reçus (statut quoted)
          if (status == 'quoted') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(
                  '/artisans/quotes/${widget.request['id']}?title=${Uri.encodeComponent(widget.request['title'] ?? 'Ma demande')}',
                ),
                icon: const Icon(Icons.request_quote_outlined, size: 16),
                label: Text(
                  widget.request['quoteCount'] != null
                      ? 'Voir les ${widget.request['quoteCount']} devis reçus'
                      : 'Voir les devis reçus',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
          // Bouton voir portfolio artisan
          if (widget.request['selectedProviderId'] != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => context.push(
                  '/artisans/portfolio/${widget.request['selectedProviderId']}'),
              icon: const Icon(Icons.photo_library_outlined, size: 16),
              label: const Text('Voir le portfolio de l\'artisan'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
          if (canEdit || canCancel || canDelete) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(children: [
              if (canEdit)
                _actionBtn(Icons.edit_outlined, 'Modifier', Colors.blue, _actLoading ? null : _edit),
              if (canEdit) const SizedBox(width: 8),
              if (canCancel)
                _actionBtn(Icons.cancel_outlined, 'Annuler', Colors.orange, _actLoading ? null : _cancel),
              if (canCancel) const SizedBox(width: 8),
              if (canDelete)
                _actionBtn(Icons.delete_outline, 'Supprimer', Colors.red, _actLoading ? null : _delete),
              if (_actLoading) ...[
                const Spacer(),
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

// ── Sheet de modification ──────────────────────────────────────────────────────
class _EditRequestSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onSaved;
  const _EditRequestSheet({required this.request, required this.onSaved});
  @override
  ConsumerState<_EditRequestSheet> createState() => _EditRequestSheetState();
}

class _EditRequestSheetState extends ConsumerState<_EditRequestSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _budgetMinCtrl;
  late TextEditingController _budgetMaxCtrl;
  late String _urgency;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _titleCtrl     = TextEditingController(text: r['title'] ?? '');
    _descCtrl      = TextEditingController(text: r['description'] ?? '');
    _addressCtrl   = TextEditingController(text: r['location_address'] ?? r['locationAddress'] ?? '');
    _budgetMinCtrl = TextEditingController(text: r['budget_min']?.toString() ?? r['budgetMin']?.toString() ?? '');
    _budgetMaxCtrl = TextEditingController(text: r['budget_max']?.toString() ?? r['budgetMax']?.toString() ?? '');
    _urgency       = r['urgency'] ?? 'normal';
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _addressCtrl.dispose();
    _budgetMinCtrl.dispose(); _budgetMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).patch('/artisans/requests/${widget.request['id']}', data: {
        'title':           _titleCtrl.text.trim(),
        'description':     _descCtrl.text.trim(),
        'locationAddress': _addressCtrl.text.trim(),
        'budgetMin':       int.tryParse(_budgetMinCtrl.text.trim()),
        'budgetMax':       int.tryParse(_budgetMaxCtrl.text.trim()),
        'urgency':         _urgency,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande modifiée ✅'), backgroundColor: Colors.green));
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9, maxChildSize: 0.97, minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const Text('Modifier la demande', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.all(16), children: [
            _tf('Titre *', _titleCtrl),
            const SizedBox(height: 12),
            _tf('Description', _descCtrl, lines: 3),
            const SizedBox(height: 12),
            _tf('Adresse', _addressCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _tf('Budget min (XAF)', _budgetMinCtrl, type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf('Budget max (XAF)', _budgetMaxCtrl, type: TextInputType.number)),
            ]),
            const SizedBox(height: 14),
            const Text('Urgence', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'normal', label: Text('Normal'), icon: Icon(Icons.schedule)),
                ButtonSegment(value: 'urgent', label: Text('Urgent'), icon: Icon(Icons.priority_high)),
              ],
              selected: {_urgency},
              onSelectionChanged: (v) => setState(() => _urgency = v.first),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('Enregistrer', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget _tf(String label, TextEditingController ctrl, {int lines = 1, TextInputType? type}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, maxLines: lines, keyboardType: type,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ]);
}
