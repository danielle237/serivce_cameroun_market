import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/order.dart';
import '../providers/marketplace_providers.dart';

class BossDashboardScreen extends ConsumerWidget {
  const BossDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(bossStatsProvider);
    final ordersAsync = ref.watch(vendorOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('👑 Dashboard Tokos Boss'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.video_camera_back_outlined),
            tooltip: 'TikTok',
            onPressed: () => context.push('/marketplace/tiktok'),
          ),
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Vendeurs',
            onPressed: () => context.push('/marketplace/vendors'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bossStatsProvider);
          ref.invalidate(vendorOrdersProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats KPI
              statsAsync.when(
                loading: () => const _StatsShimmer(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => _KpiGrid(stats: stats),
              ),
              const SizedBox(height: 20),

              // Commandes en attente de validation
              const Text('📦 Commandes récentes',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Erreur : $e')),
                data: (orders) {
                  final pending = orders
                      .where((o) =>
                          o.status == OrderStatus.pending ||
                          o.status == OrderStatus.confirmed)
                      .toList();
                  if (pending.isEmpty) {
                    return const _EmptyState(
                        msg: 'Aucune commande en attente');
                  }
                  return Column(
                    children: pending
                        .take(10)
                        .map((o) => _BossOrderTile(order: o, ref: ref))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Raccourcis
              const Text('⚡ Raccourcis',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ShortcutTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Catalogue',
                    color: Colors.indigo,
                    onTap: () => context.push('/marketplace/vendor/products'),

                  ),
                  _ShortcutTile(
                    icon: Icons.local_offer_outlined,
                    label: 'Codes promo',
                    color: Colors.green,
                    onTap: () => context.push('/marketplace/tiktok'),
                  ),
                  _ShortcutTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Toutes les commandes',
                    color: Colors.orange,
                    onTap: () => context.push('/marketplace/orders/all'),
                  ),
                  _ShortcutTile(
                    icon: Icons.bar_chart,
                    label: 'Statistiques',
                    color: Colors.purple,
                    onTap: () => context.push('/marketplace/tiktok'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grille KPI ────────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _KpiGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiData(
        label: 'Ventes aujourd\'hui',
        value: '${_fmt((stats['todaySales'] as num?)?.toDouble() ?? 0)} FCFA',
        icon: Icons.trending_up,
        color: Colors.green,
      ),
      _KpiData(
        label: 'Commandes actives',
        value: '${stats['activeOrders'] ?? 0}',
        icon: Icons.shopping_bag_outlined,
        color: Colors.blue,
      ),
      _KpiData(
        label: 'Ventes ce mois',
        value: '${_fmt((stats['monthSales'] as num?)?.toDouble() ?? 0)} FCFA',
        icon: Icons.calendar_month,
        color: Colors.purple,
      ),
      _KpiData(
        label: 'Clients TikTok',
        value: '${stats['tiktokClients'] ?? 0}',
        icon: Icons.video_camera_back,
        color: Colors.pink,
      ),
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (_, i) => _KpiCard(data: items[i]),
    );
  }

  static String _fmt(double v) => v >= 1000000
      ? '${(v / 1000000).toStringAsFixed(1)}M'
      : v >= 1000
          ? '${(v / 1000).toStringAsFixed(0)}K'
          : v.toStringAsFixed(0);
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiData(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(data.icon, color: data.color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.value,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: data.color)),
                Text(data.label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      );
}

// ── Tile commande boss ────────────────────────────────────────────────────────
class _BossOrderTile extends StatelessWidget {
  final Order order;
  final WidgetRef ref;
  const _BossOrderTile({required this.order, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: () => context.push('/marketplace/orders/${order.id}'),
        leading: CircleAvatar(
          backgroundColor: _statusColor.withOpacity(0.15),
          child: Text(
            order.status.label.split(' ').first,
            style: TextStyle(fontSize: 16),
          ),
        ),
        title: Text(
          '${order.clientName} — ${_fmt(order.totalAmount)} FCFA',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          order.lines
              .map((l) => '${l.productName} x${l.qty}')
              .join(', '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: order.needsBossValidation
            ? const Chip(
                label: Text('⚠️ Validation',
                    style: TextStyle(fontSize: 10)),
                backgroundColor: Color(0xFFFFF3E0),
                padding: EdgeInsets.zero,
              )
            : null,
      ),
    );
  }

  Color get _statusColor {
    switch (order.status) {
      case OrderStatus.pending:   return Colors.orange;
      case OrderStatus.confirmed: return Colors.blue;
      default:                    return Colors.grey;
    }
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ── Raccourci tile ────────────────────────────────────────────────────────────
class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ShortcutTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04), blurRadius: 4)
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12),
                    maxLines: 2),
              ),
            ],
          ),
        ),
      );
}

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
            4,
            (_) => Container(
                  decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12)),
                )),
      );
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState({required this.msg});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(msg,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ),
      );
}
