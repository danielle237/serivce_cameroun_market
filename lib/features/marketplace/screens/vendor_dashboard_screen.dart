import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../models/order.dart';
import '../models/vendor.dart';
import '../providers/marketplace_providers.dart';

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(vendorOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('🏪 Espace Vendeur'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => context.push('/marketplace/vendor/products'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(vendorOrdersProvider),
        child: ordersAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (orders) => _VendorBody(orders: orders, ref: ref),
        ),
      ),
    );
  }
}

class _VendorBody extends StatelessWidget {
  final List<Order> orders;
  final WidgetRef ref;
  const _VendorBody({required this.orders, required this.ref});

  @override
  Widget build(BuildContext context) {
    final pending = orders.where((o) => o.status == OrderStatus.pending).toList();
    final active = orders.where((o) =>
        o.status == OrderStatus.confirmed ||
        o.status == OrderStatus.paid ||
        o.status == OrderStatus.preparing).toList();
    final ready = orders.where((o) => o.status == OrderStatus.ready).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Résumé rapide
          Row(
            children: [
              _CountChip(label: 'En attente', count: pending.length, color: Colors.orange),
              const SizedBox(width: 8),
              _CountChip(label: 'En cours', count: active.length, color: Colors.blue),
              const SizedBox(width: 8),
              _CountChip(label: 'Prêtes', count: ready.length, color: Colors.green),
            ],
          ),
          const SizedBox(height: 16),

          if (pending.isNotEmpty) ...[
            _SectionHeader(title: '🟡 En attente (${pending.length})'),
            const SizedBox(height: 8),
            ...pending.map((o) => _VendorOrderTile(order: o, ref: ref)),
            const SizedBox(height: 16),
          ],

          if (active.isNotEmpty) ...[
            _SectionHeader(title: '🔵 En cours (${active.length})'),
            const SizedBox(height: 8),
            ...active.map((o) => _VendorOrderTile(order: o, ref: ref)),
            const SizedBox(height: 16),
          ],

          if (ready.isNotEmpty) ...[
            _SectionHeader(title: '✅ Prêtes à récupérer (${ready.length})'),
            const SizedBox(height: 8),
            ...ready.map((o) => _VendorOrderTile(order: o, ref: ref)),
            const SizedBox(height: 16),
          ],

          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Aucune commande active',
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VendorOrderTile extends StatelessWidget {
  final Order order;
  final WidgetRef ref;
  const _VendorOrderTile({required this.order, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.clientName} · ${order.clientPhone}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  order.paymentMethod.label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...order.lines.map((l) => Text(
                  '• ${l.productName}${l.variant1 != null ? ' (${l.variant1})' : ''} × ${l.qty}',
                  style: const TextStyle(fontSize: 13),
                )),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_fmt(order.totalAmount)} FCFA',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                      fontSize: 15),
                ),
                _NextStatusButton(order: order, ref: ref),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ── Bouton avancer statut ─────────────────────────────────────────────────────
class _NextStatusButton extends StatefulWidget {
  final Order order;
  final WidgetRef ref;
  const _NextStatusButton({required this.order, required this.ref});

  @override
  State<_NextStatusButton> createState() => _NextStatusButtonState();
}

class _NextStatusButtonState extends State<_NextStatusButton> {
  bool _loading = false;

  OrderStatus? get _nextStatus {
    switch (widget.order.status) {
      case OrderStatus.pending:   return OrderStatus.confirmed;
      case OrderStatus.confirmed: return OrderStatus.preparing;
      case OrderStatus.paid:      return OrderStatus.preparing;
      case OrderStatus.preparing: return OrderStatus.ready;
      default:                    return null;
    }
  }

  String get _nextLabel {
    switch (_nextStatus) {
      case OrderStatus.confirmed: return 'Confirmer stock';
      case OrderStatus.preparing: return 'Mettre en prépa';
      case OrderStatus.ready:     return 'Marquer prête';
      default:                    return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_nextStatus == null) return const SizedBox.shrink();
    return ElevatedButton(
      onPressed: _loading ? null : _advance,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _loading
          ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Text(_nextLabel, style: const TextStyle(fontSize: 12)),
    );
  }

  Future<void> _advance() async {
    setState(() => _loading = true);
    try {
      final api = widget.ref.read(apiClientProvider);
      await api.patch(
        '/marketplace/orders/${widget.order.id}/status',
        data: {'status': _nextStatus!.name},
      );
      widget.ref.invalidate(vendorOrdersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text('$count',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: color)),
              Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));
}
