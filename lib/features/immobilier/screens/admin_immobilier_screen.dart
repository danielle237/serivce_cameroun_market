import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';

class AdminImmobilierScreen extends ConsumerStatefulWidget {
  const AdminImmobilierScreen({super.key});
  @override
  ConsumerState<AdminImmobilierScreen> createState() => _AdminImmobilierState();
}

class _AdminImmobilierState extends ConsumerState<AdminImmobilierScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _pending  = [];
  List<Map<String, dynamic>> _all      = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/immobilier/admin/all', forceRefresh: true);
      final items = (res.data is List)
          ? (res.data as List).map((p) => Map<String, dynamic>.from(p as Map)).toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _all     = items;
        _pending = items.where((p) => p['status'] == 'pending').toList();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _validate(String id) async {
    try {
      await ref.read(apiClientProvider).patch('/immobilier/admin/$id/validate', data: {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonce validée ✓'), backgroundColor: Color(0xFF16A34A)));
      _load();
    } catch (_) {}
  }

  Future<void> _toggleFeatured(String id, bool current) async {
    try {
      await ref.read(apiClientProvider).patch(
        '/immobilier/admin/$id/featured', data: {'featured': !current});
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Admin — Immobilier'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'En attente (${_pending.length})'),
            Tab(text: 'Toutes (${_all.length})'),
          ],
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tabs, children: [
            _PropertyAdminList(
              items: _pending,
              onValidate: _validate,
              onFeatured: _toggleFeatured,
              onTap: (id) => context.push('/immobilier/$id'),
            ),
            _PropertyAdminList(
              items: _all,
              onValidate: _validate,
              onFeatured: _toggleFeatured,
              onTap: (id) => context.push('/immobilier/$id'),
            ),
          ]),
    );
  }
}

class _PropertyAdminList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Future<void> Function(String) onValidate;
  final Future<void> Function(String, bool) onFeatured;
  final void Function(String) onTap;

  const _PropertyAdminList({
    required this.items, required this.onValidate,
    required this.onFeatured, required this.onTap,
  });

  static const _statusColors = {
    'pending': Color(0xFFF59E0B),
    'active':  Color(0xFF16A34A),
    'loue':    Color(0xFF6366F1),
    'vendu':   Color(0xFF6366F1),
    'inactif': Color(0xFF9CA3AF),
  };

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Aucune annonce', style: TextStyle(color: Colors.grey.shade400)),
      ]));

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final p = items[i];
        final status  = p['status'] as String? ?? 'pending';
        final color   = _statusColors[status] ?? const Color(0xFF9CA3AF);
        final featured = p['featured'] == true;
        final verified = p['verified'] == true;
        final photo   = p['photoPrincipale'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(children: [
            // Header statut
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(bottom: BorderSide(color: color.withOpacity(0.2)))),
              child: Row(children: [
                Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                if (featured) const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                if (verified) const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                Text(p['categorySlug'] as String? ?? '',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ]),
            ),

            // Corps
            InkWell(
              onTap: () => onTap(p['id'] as String? ?? ''),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  // Photo miniature
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: photo != null
                      ? CachedNetworkImage(
                          imageUrl: photo, width: 72, height: 72, fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey.shade200),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.home_outlined)))
                      : Container(width: 72, height: 72, color: Colors.grey.shade200,
                          child: const Icon(Icons.home_outlined)),
                  ),
                  const SizedBox(width: 12),

                  // Infos
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['title'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('${p['ville'] ?? ''} · ${p['quartier'] ?? ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 3),
                    Text('${p['prix'] ?? 0} FCFA',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20))),
                  ])),

                  // Actions
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    if (status == 'pending')
                      ElevatedButton(
                        onPressed: () => onValidate(p['id'] as String? ?? ''),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white,
                          minimumSize: const Size(64, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        child: const Text('Valider')),
                    const SizedBox(height: 4),
                    OutlinedButton(
                      onPressed: () => onFeatured(p['id'] as String? ?? '', featured),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: featured ? Colors.amber.shade700 : Colors.grey.shade600,
                        side: BorderSide(color: featured ? Colors.amber.shade700 : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 10)),
                      child: Text(featured ? '★ Vedette' : '☆ Vedette')),
                  ]),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}
