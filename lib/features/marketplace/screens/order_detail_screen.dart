import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../models/order.dart';
import '../providers/marketplace_providers.dart';

import '../../../core/config/app_config.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Détail commande'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (order) => _OrderDetail(order: order, ref: ref),
      ),
    );
  }
}

class _OrderDetail extends StatelessWidget {
  final Order order;
  final WidgetRef ref;
  const _OrderDetail({required this.order, required this.ref});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statut
          _StatusBanner(order: order),
          const SizedBox(height: 16),

          // Articles
          _Card(
            title: 'Articles',
            child: Column(
              children: order.lines.map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    if (line.productPhoto != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          line.productPhoto!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _imgPlaceholder(),
                        ),
                      )
                    else
                      _imgPlaceholder(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.productName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          if (line.variant1 != null || line.variant2 != null)
                            Text(
                              [line.variant1, line.variant2]
                                  .where((v) => v != null)
                                  .join(' — '),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          Text('x${line.qty}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Text('${_fmt(line.total)} FCFA',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Paiement
          _Card(
            title: 'Paiement',
            child: Column(
              children: [
                _Row('Mode', order.paymentMethod.label),
                _Row('Statut', _paymentStatusLabel(order.paymentStatus)),
                _Row('Total', '${_fmt(order.totalAmount)} FCFA',
                    bold: true),
                if (order.promoCode != null)
                  _Row('Code promo', order.promoCode!),
                if (order.discount != null && order.discount! > 0)
                  _Row('Réduction', '- ${_fmt(order.discount!)} FCFA',
                      color: Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Preuve MoMo
          if (order.paymentProof != null) ...[
            _Card(
              title: '📱 Preuve MoMo',
              child: Column(
                children: [
                  _Row('Référence', order.paymentProof!.reference),
                  _Row('Heure', order.paymentProof!.time),
                  _Row('Statut',
                      _paymentStatusLabel(order.paymentProof!.status)),
                  if (order.paymentProof!.rejectReason != null)
                    _Row('Motif rejet', order.paymentProof!.rejectReason!,
                        color: Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Historique
          _Card(
            title: '📋 Historique',
            child: Column(
              children: order.history.isEmpty
                  ? [const Text('Aucun historique',
                      style: TextStyle(color: Colors.grey))]
                  : order.history.map((h) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A237E),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(h.status.label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                    '${h.actorName} · ${_formatDate(h.timestamp)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600]),
                                  ),
                                  if (h.comment != null)
                                    Text(h.comment!,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Contacter Tchokos
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openChat(context),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('💬 Contacter Tchokos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Annuler
          if (order.status.canCancel)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelOrder(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('❌ Annuler la commande'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.image, color: Colors.grey),
      );

  Future<void> _openChat(BuildContext context) async {
    final shopAsync = ref.read(shopProvider(AppConfig.shopId));
    String ownerId;
    if (shopAsync.value != null) {
      ownerId = shopAsync.value!.ownerId;
    } else {
      final shop = await ref.read(shopProvider(AppConfig.shopId).future);
      ownerId = shop.ownerId;
    }
    if (context.mounted) {
      context.push(
        '/messages/chat/$ownerId',
        extra: {
          'marketplaceData': {
            'type': 'order',
            'orderId': order.id,
            'orderRef': '#${order.id.substring(0, 8).toUpperCase()}',
            'orderTotal': order.totalAmount,
            'orderStatus': order.status.label,
          },
        },
      );
    }
  }

  void _cancelOrder(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Annuler la commande'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
                hintText: 'Raison de l\'annulation'),
            maxLines: 2,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Retour')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final api = ref.read(apiClientProvider);
                  await api.patch(
                    '/marketplace/orders/${order.id}/cancel',
                    data: {'reason': ctrl.text.trim()},
                  );
                  ref.invalidate(orderDetailProvider(order.id));
                  ref.invalidate(myOrdersProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur : $e')));
                  }
                }
              },
              child: const Text('Confirmer',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  String _paymentStatusLabel(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.pending:   return '⏳ En attente';
      case PaymentStatus.validated: return '✅ Validé';
      case PaymentStatus.rejected:  return '❌ Rejeté';
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}h'
      '${dt.minute.toString().padLeft(2, '0')}';

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ── Bannière statut ───────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final Order order;
  const _StatusBanner({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(order.status.label,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _color)),
          const SizedBox(height: 4),
          Text(
            'Commande #${order.id.substring(0, 8).toUpperCase()}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Color get _color {
    switch (order.status) {
      case OrderStatus.pending:   return Colors.orange;
      case OrderStatus.confirmed: return Colors.blue;
      case OrderStatus.paid:      return Colors.purple;
      case OrderStatus.preparing: return Colors.deepOrange;
      case OrderStatus.ready:     return Colors.green;
      case OrderStatus.received:  return Colors.teal;
      case OrderStatus.cancelled: return Colors.red;
    }
  }
}

// ── Helpers UI ────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
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
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _Row(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600])),
            Text(value,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
                    color: color)),
          ],
        ),
      );
}
