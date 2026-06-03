import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../models/vendor.dart';
import '../providers/marketplace_providers.dart';

class TikTokScreen extends ConsumerStatefulWidget {
  const TikTokScreen({super.key});

  @override
  ConsumerState<TikTokScreen> createState() => _TikTokScreenState();
}

class _TikTokScreenState extends ConsumerState<TikTokScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('📱 TikTok'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.pinkAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: '📊 Statistiques'),
            Tab(text: '🎟️ Codes promo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _TikTokStats(),
          _PromoCodesTab(),
        ],
      ),
    );
  }
}

// ── Statistiques TikTok ───────────────────────────────────────────────────────
class _TikTokStats extends ConsumerWidget {
  const _TikTokStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(tiktokStatsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tiktokStatsProvider),
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats semaine
            _StatCard(
              title: '📅 Cette semaine',
              rows: [
                _StatRow('Clics sur les liens',
                    '${stats['weekClicks'] ?? 0}', Icons.touch_app, Colors.blue),
                _StatRow('Nouveaux inscrits',
                    '${stats['weekSignups'] ?? 0}', Icons.person_add, Colors.green),
                _StatRow('Commandes TikTok',
                    '${stats['weekOrders'] ?? 0}', Icons.shopping_bag, Colors.purple),
                _StatRow('Ventes TikTok',
                    '${_fmt((stats['weekSales'] as num?)?.toDouble() ?? 0)} FCFA',
                    Icons.trending_up, Colors.orange),
              ],
            ),
            const SizedBox(height: 12),

            // Top produits
            _StatCard(
              title: '🥇 Top produits TikTok',
              child: Column(
                children: [
                  ...(stats['topProducts'] as List? ?? [])
                      .take(5)
                      .toList()
                      .asMap()
                      .entries
                      .map((e) {
                    final p = e.value as Map;
                    final medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Text(medals[e.key],
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(p['name'] as String? ?? '—')),
                          Text('${p['clicks'] ?? 0} clics',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    );
                  }),
                  if ((stats['topProducts'] as List? ?? []).isEmpty)
                    const Text('Aucune donnée disponible',
                        style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Codes promo utilisés
            _StatCard(
              title: '🎟️ Codes promo utilisés',
              child: Column(
                children: [
                  ...(stats['promoStats'] as List? ?? []).map((p) {
                    final promo = p as Map;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.pink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(promo['code'] as String? ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.pink,
                                    fontSize: 12)),
                          ),
                          const Spacer(),
                          Text('${promo['uses'] ?? 0} utilisations',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    );
                  }),
                  if ((stats['promoStats'] as List? ?? []).isEmpty)
                    const Text('Aucun code utilisé',
                        style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

            const SizedBox(height: 20),
            // Bouton copier lien boutique
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(
                    text: 'https://w2d.cm/shop/tchokos'));
                ScaffoldMessenger.of(context as BuildContext).showSnackBar(
                  const SnackBar(content: Text('Lien copié !')),
                );
              },
              icon: const Icon(Icons.link),
              label: const Text('Copier le lien boutique'),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) => v >= 1000000
      ? '${(v / 1000000).toStringAsFixed(1)}M'
      : v >= 1000
          ? '${(v / 1000).toStringAsFixed(0)}K'
          : v.toStringAsFixed(0);
}

// ── Onglet codes promo ────────────────────────────────────────────────────────
class _PromoCodesTab extends ConsumerStatefulWidget {
  const _PromoCodesTab();

  @override
  ConsumerState<_PromoCodesTab> createState() => _PromoCodesTabState();
}

class _PromoCodesTabState extends ConsumerState<_PromoCodesTab> {
  @override
  Widget build(BuildContext context) {
    final promosAsync = ref.watch(promoCodesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau code'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(promoCodesProvider),
        child: promosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (promos) {
            if (promos.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_offer_outlined,
                        size: 60, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Aucun code promo',
                        style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Créez des codes pour vos vidéos TikTok',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: promos.length,
              itemBuilder: (ctx, i) =>
                  _PromoTile(promo: promos[i], ref: ref),
            );
          },
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final pctCtrl = TextEditingController();
    final maxCtrl = TextEditingController();
    bool isTikTok = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Nouveau code promo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    hintText: 'Ex: TOKOS10',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pctCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Réduction (%)',
                    hintText: 'Ex: 10',
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Utilisations max (optionnel)',
                    hintText: 'Ex: 100',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Source TikTok'),
                  value: isTikTok,
                  onChanged: (v) => setDlgState(() => isTikTok = v!),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (codeCtrl.text.trim().isEmpty ||
                    pctCtrl.text.trim().isEmpty) return;
                try {
                  final api = ref.read(apiClientProvider);
                  await api.post('/marketplace/promo-codes', data: {
                    'code': codeCtrl.text.trim().toUpperCase(),
                    'discountPercent':
                        double.tryParse(pctCtrl.text) ?? 0,
                    if (maxCtrl.text.isNotEmpty)
                      'maxUses': int.tryParse(maxCtrl.text),
                    'source': isTikTok ? 'tiktok' : 'general',
                    'shopId': AppConfig.shopId,
                  });
                  ref.invalidate(promoCodesProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Erreur : $e')));
                  }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoTile extends StatelessWidget {
  final PromoCode promo;
  final WidgetRef ref;
  const _PromoTile({required this.promo, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: promo.isValid ? Colors.pink : Colors.grey[300],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(promo.code,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(
          '-${promo.discountPercent.toStringAsFixed(0)}%'
          '${promo.source == 'tiktok' ? ' · TikTok 📱' : ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${promo.usedCount}/${promo.maxUses ?? '∞'} utilisations'
          '${promo.isValid ? '' : ' · Expiré'}',
          style: TextStyle(
              color: promo.isValid ? Colors.grey : Colors.red),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: promo.code));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Code ${promo.code} copié !')),
            );
          },
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final List<_StatRow>? rows;
  final Widget? child;
  const _StatCard({required this.title, this.rows, this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            if (rows != null) ...rows!,
            if (child != null) child!,
          ],
        ),
      );
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatRow(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );
}
