import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/product.dart';
import '../models/banner.dart';
import '../providers/marketplace_providers.dart';
// activeShopIdProvider est dans marketplace_providers.dart
import '../widgets/banner_carousel.dart';
import '../widgets/product_card.dart';
import '../widgets/category_filter.dart';

import '../../../core/config/app_config.dart';

// Nombre de colonnes selon la largeur de l'écran
int _gridCols(double width) {
  if (width >= 1200) return 5;
  if (width >= 900)  return 4;
  if (width >= 600)  return 3;
  return 2;
}

class MarketplaceHomeScreen extends ConsumerStatefulWidget {
  final String? source;
  final String? highlightProductId;

  const MarketplaceHomeScreen({
    super.key,
    this.source,
    this.highlightProductId,
  });

  @override
  ConsumerState<MarketplaceHomeScreen> createState() =>
      _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState
    extends ConsumerState<MarketplaceHomeScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value?.user;
    final role = user?['marketplaceRole'] as String?;
    final cartCount = ref.watch(cartProvider).itemCount;
    final shopId = ref.watch(activeShopIdProvider);
    final bannersAsync = ref.watch(bannersProvider(shopId));
    final featuredAsync = ref.watch(featuredProductsProvider(shopId));
    final productsAsync = ref.watch(productsProvider(shopId));
    final query = ref.watch(searchQueryProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        title: Row(children: [
          const Text('🛒 ', style: TextStyle(fontSize: 20)),
          const Text('Tchokos',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        actions: [
          // Messagerie
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/messages'),
          ),
          // Panier — push pour que le retour fonctionne
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => context.push('/marketplace/cart'),
            ),
            if (cartCount > 0)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('$cartCount',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ]),
          // Dashboard selon rôle
          if (role == 'marketplace_boss')
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              onPressed: () => context.push('/marketplace/boss'),
            )
          else if (role == 'marketplace_vendor')
            IconButton(
              icon: const Icon(Icons.store_outlined),
              onPressed: () => context.push('/marketplace/vendor'),
            ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          final sid = ref.read(activeShopIdProvider);
          ref.invalidate(bannersProvider(sid));
          ref.invalidate(featuredProductsProvider(sid));
          ref.invalidate(productsProvider(sid));
        },
        child: CustomScrollView(
          slivers: [

            // ── Message bienvenue TikTok ──────────────────────────────────
            if (widget.source == 'tiktok')
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF010101), Color(0xFF69C9D0)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Text('🎵', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bienvenue depuis TikTok ! 🎉',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text('Découvrez nos produits disponibles',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    )),
                  ]),
                ),
              ),

            // ── Barre de recherche ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      ref.read(searchQueryProvider.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            // ── Bannières défilantes ──────────────────────────────────────
            SliverToBoxAdapter(
              child: bannersAsync.when(
                loading: () => const SizedBox(height: 120,
                    child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
                data: (banners) => banners.isEmpty
                    ? const SizedBox.shrink()
                    : BannerCarousel(banners: banners),
              ),
            ),

            // ── Filtres catégories ────────────────────────────────────────
            SliverToBoxAdapter(
              child: CategoryFilter(
                selected: selectedCat,
                onSelected: (cat) =>
                    ref.read(selectedCategoryProvider.notifier).state = cat,
              ),
            ),

            // ── Produits vedettes ─────────────────────────────────────────
            if (query.isEmpty && selectedCat == null) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Text('⭐ Sélection Tchokos',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              SliverToBoxAdapter(
                child: featuredAsync.when(
                  loading: () => const SizedBox(height: 200,
                      child: Center(child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (products) =>
                      _HorizontalProductList(products: products),
                ),
              ),
            ],

            // ── Tous les produits ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Text(
                  query.isNotEmpty
                      ? 'Résultats pour "$query"'
                      : selectedCat != null
                          ? selectedCat!
                          : '🛍️ Tous les produits',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),

            productsAsync.when(
              loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Erreur: $e'))),
              data: (products) {
                var filtered = products.where((p) {
                  if (!p.isActive) return false;
                  if (query.isNotEmpty &&
                      !p.name.toLowerCase().contains(query.toLowerCase())) {
                    return false;
                  }
                  if (selectedCat != null &&
                      p.category.label != selectedCat) return false;
                  return true;
                }).toList();

                if (widget.highlightProductId != null) {
                  filtered.sort((a, b) =>
                      a.id == widget.highlightProductId ? -1 : 1);
                }

                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(children: [
                          const Icon(Icons.search_off,
                              size: 60, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text('Aucun produit trouvé',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 15)),
                        ]),
                      ),
                    ),
                  );
                }

                // Grille responsive : 2 col mobile → 5 col large desktop
                final cols = _gridCols(screenWidth);

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => ProductCard(
                        product: filtered[i],
                        isHighlighted:
                            filtered[i].id == widget.highlightProductId,
                        onTap: () => context.push(
                            '/marketplace/products/${filtered[i].id}'),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ── Liste horizontale produits vedettes ───────────────────────────────────────
class _HorizontalProductList extends ConsumerWidget {
  final List<Product> products;
  const _HorizontalProductList({required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 220,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (ctx, i) => SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ProductCard(
              product: products[i],
              onTap: () => context.push(
                  '/marketplace/products/${products[i].id}'),
            ),
          ),
        ),
      ),
    );
  }
}
