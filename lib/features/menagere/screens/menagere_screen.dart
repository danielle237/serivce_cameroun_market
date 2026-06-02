import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

final menagereContractsProvider = FutureProvider.autoDispose<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/contracts', params: {'module': 'menagere'});
  return List.from(res.data is List ? res.data : (res.data['data'] ?? []));
});

class MenagereScreen extends ConsumerWidget {
  const MenagereScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractsAsync = ref.watch(menagereContractsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Module Ménagère')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bannière info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Color(0xFFEC4899)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Trouvez une aide ménagère vérifiée par W2D. Paiement sécurisé par escrow, libéré chaque fin de mois.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFEC4899)),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // Services
            const Text('Nos services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
              children: const [
                _ServiceTile(icon: '🧹', label: 'Nettoyage quotidien'),
                _ServiceTile(icon: '👶', label: 'Garde d\'enfants'),
                _ServiceTile(icon: '🍳', label: 'Cuisine'),
                _ServiceTile(icon: '👔', label: 'Repassage & Lessive'),
              ],
            ),

            const SizedBox(height: 24),

            // CTA recruter
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.search),
              label: const Text('Trouver une ménagère'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899)),
            ),

            const SizedBox(height: 24),

            // Mes contrats
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Mes contrats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(onPressed: () => ref.invalidate(menagereContractsProvider), child: const Text('Actualiser')),
            ]),

            contractsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erreur: $e', style: const TextStyle(color: AppColors.error)),
              data: (contracts) => contracts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(children: [
                          Icon(Icons.home_work_outlined, size: 48, color: AppColors.textLight),
                          SizedBox(height: 8),
                          Text('Aucun contrat actif', style: TextStyle(color: AppColors.textSecondary)),
                        ]),
                      ),
                    )
                  : Column(
                      children: contracts.map<Widget>((c) => _ContractTile(contract: c)).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String icon, label;
  const _ServiceTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _ContractTile extends StatelessWidget {
  final dynamic contract;
  const _ContractTile({required this.contract});

  @override
  Widget build(BuildContext context) {
    final status = contract['status'] as String? ?? 'active';
    final statusColor = status == 'active' ? AppColors.success : AppColors.warning;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEC4899).withOpacity(0.1),
          child: const Text('🧹', style: TextStyle(fontSize: 18)),
        ),
        title: Text(contract['title'] ?? 'Contrat ménagère', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${contract['billingCycle'] ?? 'mensuel'} • ${contract['price'] ?? ''} XAF'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
