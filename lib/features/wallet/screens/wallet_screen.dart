import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

final walletProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/wallets');
  return Map<String, dynamic>.from(res.data);
});

final transactionsProvider = FutureProvider.autoDispose<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/wallets/transactions');
  return List.from(res.data);
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  String _formatAmount(dynamic amount) {
    final n = int.tryParse(amount.toString()) ?? 0;
    return '${(n / 1000).toStringAsFixed(0)} k XAF'.replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon Wallet'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () {
          ref.invalidate(walletProvider);
          ref.invalidate(transactionsProvider);
        }),
      ]),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (wallet) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Balance card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      '${wallet['balance'] ?? 0} XAF',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      _WalletStat(label: 'En escrow', value: '${wallet['escrowBalance'] ?? 0} XAF', icon: Icons.lock),
                      const SizedBox(width: 16),
                      _WalletStat(label: 'Total gagné', value: '${wallet['totalEarned'] ?? 0} XAF', icon: Icons.trending_up),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Actions
              Row(children: [
                Expanded(child: _WalletAction(icon: Icons.add, label: 'Recharger', color: AppColors.primary, onTap: () => _showTopUp(context))),
                const SizedBox(width: 12),
                Expanded(child: _WalletAction(icon: Icons.send, label: 'Retirer', color: AppColors.secondary, onTap: () => _showWithdraw(context))),
                const SizedBox(width: 12),
                Expanded(child: _WalletAction(icon: Icons.history, label: 'Historique', color: AppColors.info, onTap: () {})),
              ]),

              const SizedBox(height: 24),

              // Transactions
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Voir tout', style: TextStyle(color: AppColors.primary, fontSize: 14)),
              ]),

              const SizedBox(height: 12),

              txAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Erreur transactions: $e'),
                data: (txs) => Column(
                  children: txs.take(10).map<Widget>((tx) => _TransactionTile(tx: tx)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTopUp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _TopUpSheet(),
    );
  }

  void _showWithdraw(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _WithdrawSheet(),
    );
  }
}

class _WalletStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _WalletStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Colors.white60, size: 16),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ]);
  }
}

class _WalletAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _WalletAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final dynamic tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = ['deposit', 'escrow_release', 'advance'].contains(tx['type']);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isCredit ? AppColors.success : AppColors.error).withOpacity(0.1),
          child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? AppColors.success : AppColors.error),
        ),
        title: Text(tx['description'] ?? tx['type'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(tx['createdAt']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontSize: 11)),
        trailing: Text(
          '${isCredit ? '+' : '-'}${tx['netAmount']} XAF',
          style: TextStyle(color: isCredit ? AppColors.success : AppColors.error, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TopUpSheet extends ConsumerStatefulWidget {
  const _TopUpSheet();

  @override
  ConsumerState<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends ConsumerState<_TopUpSheet> {
  final _amountCtrl = TextEditingController();
  String _channel = 'om';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recharger le wallet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        TextFormField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Montant (XAF)', prefixIcon: Icon(Icons.money), suffixText: 'XAF'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _channel,
          decoration: const InputDecoration(labelText: 'Opérateur'),
          items: const [
            DropdownMenuItem(value: 'om', child: Text('Orange Money')),
            DropdownMenuItem(value: 'mtn', child: Text('MTN MoMo')),
            DropdownMenuItem(value: 'wave', child: Text('Wave')),
          ],
          onChanged: (v) => setState(() => _channel = v!),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loading ? null : _topUp,
          child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Procéder au paiement'),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  Future<void> _topUp() async {
    final amount = int.tryParse(_amountCtrl.text);
    if (amount == null || amount < 500) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Montant minimum: 500 XAF')));
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/payments/initiate', data: {
        'amount': amount, 'phone': '+237677100001', 'channel': _channel,
      });
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paiement initié: ${res.data['reference']}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _WithdrawSheet extends ConsumerStatefulWidget {
  const _WithdrawSheet();

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Retrait vers Mobile Money', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        TextFormField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Montant à retirer (XAF)'),
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _loading ? null : () {}, child: const Text('Retirer')),
        const SizedBox(height: 16),
      ]),
    );
  }
}
