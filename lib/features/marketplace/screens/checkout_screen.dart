import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../models/order.dart';
import '../providers/marketplace_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final _noteCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  final _momoRefCtrl = TextEditingController();
  final _momoTimeCtrl = TextEditingController();
  bool _loading = false;
  bool _promoApplied = false;
  String? _promoError;

  // ── Réservation stock (15 min) ───────────────────────────────────────────
  String? _reservationId;
  Timer? _reservationTimer;
  Duration _reservationRemaining = const Duration(minutes: 15);
  bool _reservationExpired = false;
  bool _reservationConflict = false; // stock pris par un autre client

  @override
  void initState() {
    super.initState();
    _reserveStock();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _promoCtrl.dispose();
    _momoRefCtrl.dispose();
    _momoTimeCtrl.dispose();
    _reservationTimer?.cancel();
    // Libérer la réservation si l'utilisateur quitte sans commander
    if (_reservationId != null) _releaseReservation();
    super.dispose();
  }

  Future<void> _reserveStock() async {
    final cart = ref.read(cartProvider);
    final api  = ref.read(apiClientProvider);
    try {
      final res = await api.post('/marketplace/orders/reserve', data: {
        'shopId': cart.shopId,
        'items': cart.items.map((item) => {
          'productId': item.product.id,
          'variantId': item.variantId,
          'qty':       item.qty,
        }).toList(),
      });
      final data = res.data as Map<String, dynamic>;
      final conflict = data['conflict'] as bool? ?? false;

      if (conflict) {
        // Stock insuffisant — un autre client a pris les dernières pièces
        final conflictItems = data['conflictItems'] as List? ?? [];
        if (mounted) {
          setState(() => _reservationConflict = true);
          _showConflictDialog(conflictItems);
        }
        return;
      }

      _reservationId = data['reservationId'] as String?;
      _startReservationTimer();
    } catch (_) {
      // En cas d'erreur réseau, on laisse passer (le backend revalide au POST /orders)
    }
  }

  void _startReservationTimer() {
    _reservationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_reservationRemaining.inSeconds > 0) {
          _reservationRemaining -= const Duration(seconds: 1);
        } else {
          _reservationExpired = true;
          _reservationTimer?.cancel();
        }
      });
    });
  }

  Future<void> _releaseReservation() async {
    final id = _reservationId;
    if (id == null) return;
    _reservationId = null;
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/marketplace/orders/reserve/$id');
    } catch (_) {}
  }

  void _showConflictDialog(List conflictItems) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Stock modifié'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Certains articles ont été achetés par quelqu\'un d\'autre avant vous :'),
            const SizedBox(height: 8),
            ...conflictItems.map((item) => Text(
              '• ${item['productName']} — demandé: ${item['requestedQty']}, disponible: ${item['availableQty']}',
              style: const TextStyle(fontSize: 13),
            )),
            const SizedBox(height: 8),
            const Text('Retournez au panier pour ajuster les quantités.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop(); // retour panier
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white),
            child: const Text('Modifier le panier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Confirmer la commande'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Bandeau hors ligne ──────────────────────────────────────────
          Consumer(builder: (ctx, ref, _) {
            final isOnline = ref.watch(isOnlineProvider);
            if (isOnline) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  '📵 Hors ligne — Impossible de passer commande sans connexion',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                )),
              ]),
            );
          }),

          // ── Bandeau réservation stock ────────────────────────────────────
          if (_reservationExpired)
            _ReservationBanner(
              label: '⏰ Réservation expirée — rechargez le panier',
              color: Colors.red.shade700,
              icon: Icons.timer_off_outlined,
            )
          else if (_reservationId != null)
            _ReservationBanner(
              label: '🔒 Stock réservé ${_fmtDuration(_reservationRemaining)}',
              color: Colors.green.shade700,
              icon: Icons.lock_clock_outlined,
            ),
          Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Récapitulatif articles
            _Section(
              title: 'Articles (${cart.itemCount})',
              child: Column(
                children: cart.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.name,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (item.variantLabel.isNotEmpty)
                              Text(item.variantLabel,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                            Text('x${item.qty}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Text('${_fmt(item.total)} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Code promo
            _Section(
              title: 'Code promo',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promoCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ex: TOKOS10',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        errorText: _promoError,
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _promoApplied ? null : _applyPromo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Appliquer'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Mode paiement
            _Section(
              title: 'Mode de paiement',
              child: Column(
                children: PaymentMethod.values.map((method) => RadioListTile<PaymentMethod>(
                  value: method,
                  groupValue: _paymentMethod,
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                  title: Text(method.label),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Preuve MoMo / Carte
            if (_paymentMethod.isMobile) ...[
              _Section(
                title: '📱 Preuve de paiement',
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Numéro de paiement :',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          _paymentMethod == PaymentMethod.mtnMomo
                              ? const Text('MTN MoMo : 6XX XXX XXX',
                                  style: TextStyle(
                                      fontSize: 16, color: Color(0xFFFF6F00)))
                              : const Text('Orange Money : 6XX XXX XXX',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.orange)),
                          const SizedBox(height: 4),
                          const Text(
                              'Envoyez le montant exact, puis renseignez la référence ci-dessous.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _momoRefCtrl,
                      decoration: InputDecoration(
                        labelText: 'Référence MoMo',
                        hintText: 'Ex: MP220601.1234.T12345',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _momoTimeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Heure du paiement',
                        hintText: 'Ex: 14:32',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Note
            _Section(
              title: 'Note (optionnel)',
              child: TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  hintText: 'Instructions spéciales, adresse, etc.',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 12),

            // Total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sous-total',
                          style: TextStyle(color: Colors.white70)),
                      Text('${_fmt(cart.subtotal)} FCFA',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  if (cart.discount != null && cart.discount! > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Promo ${cart.promoCode}',
                            style: const TextStyle(color: Colors.greenAccent)),
                        Text('- ${_fmt(cart.discount!)} FCFA',
                            style: const TextStyle(color: Colors.greenAccent)),
                      ],
                    ),
                  ],
                  const Divider(color: Colors.white30, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      Text('${_fmt(cart.total)} FCFA',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      )),  // Expanded + SingleChildScrollView
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.of(context).padding.bottom + 12),
        child: ElevatedButton(
          onPressed: (_loading || _reservationExpired || _reservationConflict) ? null : _placeOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('✅ Confirmer la commande',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Future<void> _applyPromo() async {
    final code = _promoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/marketplace/promo-codes/validate',
          data: {'code': code});
      final discount = (res.data['discount'] as num).toDouble();
      final cart = ref.read(cartProvider);
      final discountAmt =
          res.data['type'] == 'percent' ? cart.subtotal * discount / 100 : discount;
      ref.read(cartProvider.notifier).applyPromo(code, discountAmt);
      setState(() {
        _promoApplied = true;
        _promoError = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code $code appliqué ! -${_fmt(discountAmt)} FCFA'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      setState(() => _promoError = 'Code invalide ou expiré');
    }
  }

  Future<void> _placeOrder() async {
    // Bloquer si hors ligne
    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📵 Hors ligne — impossible de commander sans connexion'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    // Validation MoMo
    if (_paymentMethod.isMobile && _momoRefCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir la référence MoMo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = {
        'shopId': cart.shopId,
        'items': cart.items.map((i) => i.toJson()).toList(),
        'paymentMethod': _paymentMethod.name,
        'totalAmount': cart.total,
        if (cart.promoCode != null) 'promoCode': cart.promoCode,
        if (cart.discount != null) 'discount': cart.discount,
        if (_noteCtrl.text.isNotEmpty) 'note': _noteCtrl.text.trim(),
        if (_reservationId != null) 'reservationId': _reservationId,
        if (_momoRefCtrl.text.isNotEmpty)
          'paymentProof': {
            'reference': _momoRefCtrl.text.trim(),
            'time': _momoTimeCtrl.text.trim(),
          },
      };

      final res = await api.post('/marketplace/orders', data: body);
      final orderId = res.data['id'] as String;

      // La commande est passée — la réservation est confirmée côté backend,
      // on ne la libère plus manuellement.
      _reservationId = null;
      _reservationTimer?.cancel();

      ref.read(cartProvider.notifier).clear();

      if (mounted) {
        context.pushReplacement('/marketplace/orders/$orderId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Bandeau réservation stock ─────────────────────────────────────────────────
class _ReservationBanner extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _ReservationBanner({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: color,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(children: [
      Icon(icon, color: Colors.white, size: 16),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Colors.white,
          fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Section helper ────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          child,
        ],
      ),
    );
  }
}
