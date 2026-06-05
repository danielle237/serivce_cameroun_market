import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product.dart';
import '../providers/extras_providers.dart';
import '../widgets/product_card.dart';
import '../../../core/config/app_config.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: const Text('❤️ Ma Wishlist'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          favAsync.when(
            data: (items) => items.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => _shareWishlist(items),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: favAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Votre wishlist est vide',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Appuyez sur ❤️ sur un produit pour l\'ajouter',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.push('/marketplace'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Voir la boutique'),
                  ),
                ],
              ),
            );
          }

          final screenWidth = MediaQuery.of(context).size.width;
          final cols = screenWidth >= 600 ? 3 : 2;

          return Column(
            children: [
              // Bandeau partage
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.white,
                child: Row(children: [
                  Text('${items.length} produit(s) dans ta wishlist',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _shareWishlist(items),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Partager via WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final p = Product.fromJson(
                        Map<String, dynamic>.from(items[i] as Map));
                    return ProductCard(
                      product: p,
                      onTap: () =>
                          context.push('/marketplace/products/${p.id}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _shareWishlist(List items) {
    final lines = items.map((item) {
      final name = item['name'] ?? 'Produit';
      final price = item['retailPrice'] ?? item['retail_price'] ?? 0;
      final id = item['id'] ?? '';
      return '• $name — ${_fmt(double.tryParse('$price') ?? 0)} FCFA\n'
          '  ${AppConfig.shopLink(AppConfig.shopId, productSlug: id)}';
    }).join('\n\n');

    Share.share(
      '❤️ Ma Wishlist Tchokos\n\n$lines\n\n'
      '📱 Commandez sur W2D : ${AppConfig.shopLink(AppConfig.shopId)}',
      subject: 'Ma Wishlist Tchokos',
    );
  }

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}
