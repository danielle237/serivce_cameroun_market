import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

/// Écran permettant à un vendeur de sponsoriser son produit.
/// Accessible via le dashboard vendeur → liste produits → "Sponsoriser".
class PromoteListingScreen extends ConsumerStatefulWidget {
  final String productId;
  final String productName;

  const PromoteListingScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  ConsumerState<PromoteListingScreen> createState() => _PromoteListingScreenState();
}

class _PromoteListingScreenState extends ConsumerState<PromoteListingScreen> {
  int _selectedDays = 30;
  bool _loading = false;

  static const _packages = [
    _Package(days: 7,  price: 2000,  label: '7 jours',  popular: false),
    _Package(days: 15, price: 3500,  label: '15 jours', popular: false),
    _Package(days: 30, price: 5000,  label: '30 jours', popular: true),
    _Package(days: 60, price: 8000,  label: '60 jours', popular: false),
  ];

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).patch(
        '/marketplace/products/${widget.productId}/sponsor',
        data: {'durationDays': _selectedDays},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Votre produit est maintenant sponsorisé !'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        // Paiement Flutterwave à intégrer quand l'API sera disponible
        _showPaymentPlaceholder();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPaymentPlaceholder() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💳 Paiement sponsoring',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Paiement via Flutterwave disponible prochainement.\n'
              'Pour sponsoriser votre produit maintenant, contactez-nous :',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _ContactTile(icon: Icons.phone, label: 'MTN MoMo', value: '+237 6XX XXX XXX'),
            _ContactTile(icon: Icons.phone_android, label: 'Orange Money', value: '+237 6XX XXX XXX'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Fermer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _packages.firstWhere((p) => p.days == _selectedDays);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FF),
      appBar: AppBar(
        title: const Text('Sponsoriser mon produit'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info produit
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7C3AED).withAlpha(80)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.campaign, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📢 Sponsorisé',
                            style: TextStyle(
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        Text(widget.productName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Avantages
            const Text('Avantages du sponsoring',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...[
              '🔝 Apparaît en premier dans les résultats',
              '📢 Badge "Sponsorisé" visible par tous',
              '👁️ 3x plus de visibilité estimée',
              '📊 Statistiques de vues incluses',
            ].map((text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Expanded(child: Text(text)),
                ],
              ),
            )),
            const SizedBox(height: 24),

            // Choix durée
            const Text('Choisir une durée',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ..._packages.map((pkg) => _PackageCard(
              pkg: pkg,
              selected: _selectedDays == pkg.days,
              onTap: () => setState(() => _selectedDays = pkg.days),
            )),
            const SizedBox(height: 32),

            // Résumé + bouton
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total'),
                      Text(
                        '${selected.price} FCFA',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Durée', style: TextStyle(color: Colors.grey)),
                      Text('${selected.days} jours',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Sponsoriser maintenant',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '💳 Paiement Flutterwave disponible prochainement',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Package {
  final int days;
  final int price;
  final String label;
  final bool popular;
  const _Package({
    required this.days,
    required this.price,
    required this.label,
    required this.popular,
  });
}

class _PackageCard extends StatelessWidget {
  final _Package pkg;
  final bool selected;
  final VoidCallback onTap;
  const _PackageCard({required this.pkg, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED).withAlpha(20) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF7C3AED) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<int>(
              value: pkg.days,
              groupValue: selected ? pkg.days : -1,
              onChanged: (_) => onTap(),
              activeColor: const Color(0xFF7C3AED),
            ),
            Text(pkg.label,
                style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            if (pkg.popular) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('Populaire',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
            const Spacer(),
            Text(
              '${pkg.price} FCFA',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? const Color(0xFF7C3AED) : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ContactTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
