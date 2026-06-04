import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

// Provider vente flash active
final flashSaleProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/marketplace/flash-sale/active');
    if (res.data == null || res.data['id'] == null) return null;
    return Map<String, dynamic>.from(res.data);
  } catch (_) { return null; }
});

class FlashSaleBanner extends ConsumerWidget {
  const FlashSaleBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(flashSaleProvider);
    return saleAsync.when(
      data: (sale) => sale == null ? const SizedBox.shrink() : _Banner(sale: sale),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Banner extends StatefulWidget {
  final Map<String, dynamic> sale;
  const _Banner({required this.sale});

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final endsAt = DateTime.tryParse(widget.sale['endsAt'] as String? ?? '');
    _remaining = endsAt != null ? endsAt.difference(DateTime.now()) : Duration.zero;
    if (_remaining.isNegative) _remaining = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 0) {
          _remaining -= const Duration(seconds: 1);
        }
      });
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_remaining.inSeconds <= 0) return const SizedBox.shrink();

    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFFF6F00)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 8, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(children: [
        const Text('⚡', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.sale['title'] as String? ?? '🔥 Vente Flash !',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              Text(
                '-${widget.sale['discountPercent']}% sur ${widget.sale['categoryLabel'] ?? 'tous les produits'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        // Compte à rebours
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _TimeUnit(value: h, label: 'h'),
            const Text(' : ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            _TimeUnit(value: m, label: 'm'),
            const Text(' : ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            _TimeUnit(value: s, label: 's'),
          ]),
        ),
      ]),
    );
  }
}

class _TimeUnit extends StatelessWidget {
  final String value, label;
  const _TimeUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold,
                  fontSize: 16, height: 1)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 9)),
        ],
      );
}
