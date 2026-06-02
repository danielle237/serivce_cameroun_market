import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

final productsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/products', params: {'limit': '20'});
  return Map<String, dynamic>.from(res.data);
});

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  String _selectedCategory = 'all';

  final _categories = [
    {'value': 'all', 'label': '🏪 Tout'},
    {'value': 'alimentaire', 'label': '🍎 Aliment'},
    {'value': 'beaute', 'label': '💄 Beauté'},
    {'value': 'electronique', 'label': '📱 Élec'},
    {'value': 'artisanat', 'label': '🎨 Artis.'},
  ];

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace'), actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        IconButton(icon: const Icon(Icons.shopping_cart_outlined), onPressed: () {}),
      ]),
      body: Column(children: [
        // Categories
        Container(
          height: 50,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final c = _categories[i];
              final sel = _selectedCategory == c['value'];
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = c['value']!),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(child: Text(c['label']!, style: TextStyle(color: sel ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (data) {
              final products = (data['data'] as List?) ?? [];
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => _ProductCard(product: products[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final dynamic product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final photos = (product['photoUrls'] as List?) ?? (product['photos'] as List?) ?? [];
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: photos.isNotEmpty
                ? Image.network(photos[0], height: 130, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 130, color: Colors.grey.shade200))
                : Container(height: 130, color: Colors.grey.shade100, child: const Icon(Icons.shopping_bag, size: 40, color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('${product['price']} XAF', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Row(children: [
                Text('Stock: ${product['stock'] ?? 0}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const Spacer(),
                Row(children: List.generate(
                  ((product['avgRating'] ?? 0.0) as num).round().clamp(0, 5),
                  (_) => const Icon(Icons.star, size: 10, color: AppColors.secondary),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
