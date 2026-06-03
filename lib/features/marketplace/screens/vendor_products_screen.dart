import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../models/product.dart';
import '../models/shop_product.dart';
import '../providers/marketplace_providers.dart';

class VendorProductsScreen extends ConsumerWidget {
  const VendorProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider(AppConfig.shopId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('📦 Catalogue Tchokos'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(productsProvider(AppConfig.shopId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/marketplace/vendor/products/new'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau produit'),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Aucun produit',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Ajoutez votre premier produit',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/marketplace/vendor/products/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un produit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          // Grouper par catégorie
          final grouped = <String, List<Product>>{};
          for (final p in products) {
            grouped.putIfAbsent(p.category.label, () => []).add(p);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            children: [
              // Résumé
              _SummaryBar(products: products),
              const SizedBox(height: 12),
              // Par catégorie
              ...grouped.entries.map((e) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${e.key} (${e.value.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      ...e.value.map((p) => _ProductTile(
                            product: p,
                            ref: ref,
                          )),
                    ],
                  )),
            ],
          );
        },
      ),
    );
  }
}

// ── Barre résumé ──────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<Product> products;
  const _SummaryBar({required this.products});

  @override
  Widget build(BuildContext context) {
    final actifs = products.where((p) => p.isActive).length;
    final stock = products.fold(0, (s, p) => s + p.totalStock);
    final epingles = products.where((p) => p.isPinned).length;

    return Row(children: [
      _Chip(label: 'Actifs', value: '$actifs', color: Colors.green),
      const SizedBox(width: 8),
      _Chip(label: 'Stock total', value: '$stock', color: Colors.blue),
      const SizedBox(width: 8),
      _Chip(label: 'Épinglés', value: '$epingles', color: Colors.orange),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color)),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      );
}

// ── Tile produit ──────────────────────────────────────────────────────────────
class _ProductTile extends StatelessWidget {
  final Product product;
  final WidgetRef ref;
  const _ProductTile({required this.product, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: product.photos.isNotEmpty
                  ? Image.network(
                      product.photos.first,
                      width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(product.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (product.isPinned)
                      const Icon(Icons.push_pin,
                          size: 14, color: Colors.orange),
                    if (!product.isActive)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Inactif',
                            style: TextStyle(
                                color: Colors.red, fontSize: 10)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '${_fmt(product.retailPrice)} FCFA · Stock: ${product.totalStock}',
                    style: const TextStyle(
                        color: Color(0xFF1A237E),
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                  Text(
                    '${product.orderCount} commandes · ${product.viewCount} vues',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) =>
                  _handleAction(context, action),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ])),
                PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(
                          product.isActive
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 16),
                      const SizedBox(width: 8),
                      Text(product.isActive
                          ? 'Désactiver'
                          : 'Activer'),
                    ])),
                PopupMenuItem(
                    value: 'pin',
                    child: Row(children: [
                      Icon(
                          product.isPinned
                              ? Icons.push_pin_outlined
                              : Icons.push_pin,
                          size: 16),
                      const SizedBox(width: 8),
                      Text(product.isPinned
                          ? 'Désépingler'
                          : 'Épingler'),
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Supprimer',
                          style: TextStyle(color: Colors.red)),
                    ])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image, color: Colors.grey[400]),
      );

  Future<void> _handleAction(BuildContext context, String action) async {
    final api = ref.read(apiClientProvider);
    switch (action) {
      case 'edit':
        context.push('/marketplace/vendor/products/edit/${product.id}');
        break;

      case 'toggle':
        await api.patch('/marketplace/products/${product.id}',
            data: {'isActive': !product.isActive});
        ref.invalidate(productsProvider(AppConfig.shopId));
        break;

      case 'pin':
        await api.patch('/marketplace/products/${product.id}',
            data: {'isPinned': !product.isPinned});
        ref.invalidate(productsProvider(AppConfig.shopId));
        ref.invalidate(featuredProductsProvider(AppConfig.shopId));
        break;

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Supprimer ce produit ?'),
            content:
                Text('${product.name} sera supprimé définitivement.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Supprimer',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirmed == true) {
          await api.patch('/marketplace/products/${product.id}',
              data: {'isActive': false});
          ref.invalidate(productsProvider(AppConfig.shopId));
        }
        break;
    }
  }

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}
