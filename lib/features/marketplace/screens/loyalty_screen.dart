import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../providers/extras_providers.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loyaltyAsync = ref.watch(loyaltyProvider);
    final configAsync  = ref.watch(loyaltyConfigProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('⭐ Programme fidélité'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: loyaltyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (loyalty) => configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
          data: (config) => _LoyaltyBody(loyalty: loyalty, config: config, ref: ref),
        ),
      ),
    );
  }
}

class _LoyaltyBody extends StatelessWidget {
  final Map<String, dynamic> loyalty;
  final Map<String, dynamic> config;
  final WidgetRef ref;
  const _LoyaltyBody({required this.loyalty, required this.config, required this.ref});

  @override
  Widget build(BuildContext context) {
    final level         = loyalty['level'] as String? ?? 'bronze';
    final totalPoints   = loyalty['totalPoints'] as int? ?? 0;
    final available     = loyalty['availablePoints'] as int? ?? 0;
    final pointsValue   = loyalty['pointsValue'] as int? ?? 0;
    final totalOrders   = loyalty['totalOrders'] as int? ?? 0;
    final nextLevel     = loyalty['nextLevel'] as Map<String, dynamic>?;

    final levelColors = {
      'bronze': Colors.brown,
      'silver': Colors.grey,
      'gold':   Colors.amber,
      'vip':    Colors.purple,
    };
    final levelEmojis = {
      'bronze': '🥉', 'silver': '🥈', 'gold': '🥇', 'vip': '👑',
    };

    final color = levelColors[level] ?? Colors.brown;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Carte niveau ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.3),
                    blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Text('${levelEmojis[level]} ${level.toUpperCase()}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('$available points disponibles',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text('${_fmt(pointsValue.toDouble())} FCFA de réduction',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (nextLevel != null) ...[
                  LinearProgressIndicator(
                    value: _levelProgress(level, totalPoints, config),
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${nextLevel['pointsNeeded']} points pour ${nextLevel['level'].toString().toUpperCase()} ${levelEmojis[nextLevel['level']] ?? ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ] else
                  const Text('🏆 Niveau maximum atteint !',
                      style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats ─────────────────────────────────────────────────────────
          Row(children: [
            _StatCard(label: 'Total points', value: '$totalPoints',
                icon: Icons.star, color: Colors.amber),
            const SizedBox(width: 12),
            _StatCard(label: 'Commandes', value: '$totalOrders',
                icon: Icons.shopping_bag, color: Colors.blue),
            const SizedBox(width: 12),
            _StatCard(label: 'Points utilisés',
                value: '${(loyalty['usedPoints'] as int? ?? 0)}',
                icon: Icons.redeem, color: Colors.green),
          ]),
          const SizedBox(height: 16),

          // ── Utiliser ses points ───────────────────────────────────────────
          if (available > 0)
            _RedeemCard(
              available: available,
              pointValue: config['pointValue'] as int? ?? 10,
              ref: ref,
            ),
          const SizedBox(height: 16),

          // ── Comment gagner des points ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 Comment gagner des points ?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _HowRow(icon: '🛒', text:
                    'Chaque commande : ${config['pointsPer1000'] ?? 10} points pour 1 000 FCFA'),
                _HowRow(icon: '🥈', text:
                    'Niveau Silver : à partir de ${config['silverThreshold'] ?? 500} pts → -${config['silverDiscount'] ?? 5}%'),
                _HowRow(icon: '🥇', text:
                    'Niveau Gold : à partir de ${config['goldThreshold'] ?? 2000} pts → -${config['goldDiscount'] ?? 10}%'),
                _HowRow(icon: '👑', text:
                    'Niveau VIP : à partir de ${config['vipThreshold'] ?? 5000} pts → -${config['vipDiscount'] ?? 15}%'),
                _HowRow(icon: '💎', text:
                    '1 point = ${config['pointValue'] ?? 10} FCFA de réduction'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _levelProgress(String level, int points, Map config) {
    switch (level) {
      case 'bronze': return (points / (config['silverThreshold'] ?? 500)).clamp(0.0, 1.0);
      case 'silver': return ((points - (config['silverThreshold'] ?? 500)) /
          ((config['goldThreshold'] ?? 2000) - (config['silverThreshold'] ?? 500))).clamp(0.0, 1.0);
      case 'gold':   return ((points - (config['goldThreshold'] ?? 2000)) /
          ((config['vipThreshold'] ?? 5000) - (config['goldThreshold'] ?? 2000))).clamp(0.0, 1.0);
      default: return 1.0;
    }
  }

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _HowRow extends StatelessWidget {
  final String icon, text;
  const _HowRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ]),
      );
}

// ── Utiliser ses points ───────────────────────────────────────────────────────
class _RedeemCard extends ConsumerStatefulWidget {
  final int available, pointValue;
  final WidgetRef ref;
  const _RedeemCard({required this.available, required this.pointValue, required this.ref});

  @override
  ConsumerState<_RedeemCard> createState() => _RedeemCardState();
}

class _RedeemCardState extends ConsumerState<_RedeemCard> {
  double _pointsToUse = 0;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final discount = (_pointsToUse * widget.pointValue).toInt();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎁 Utiliser mes points',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Points : ${_pointsToUse.toInt()}'),
              Text('= $discount FCFA de réduction',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _pointsToUse,
            min: 0,
            max: widget.available.toDouble(),
            divisions: widget.available > 0 ? widget.available : 1,
            activeColor: Colors.green,
            onChanged: (v) => setState(() => _pointsToUse = v),
          ),
          ElevatedButton(
            onPressed: _pointsToUse > 0 && !_loading ? _redeem : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            child: _loading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Utiliser ${_pointsToUse.toInt()} points (-$discount FCFA)'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Les points seront déduits de votre prochaine commande.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _redeem() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/marketplace/loyalty/redeem',
          data: {'points': _pointsToUse.toInt()});
      ref.invalidate(loyaltyProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Points utilisés !'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
