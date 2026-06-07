import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/i18n/app_translations.dart';
import '../models/product.dart';
import '../models/banner.dart';
import '../providers/marketplace_providers.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/product_card.dart';
import '../widgets/category_filter.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/flash_sale_banner.dart';
import '../../../core/config/app_config.dart';

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
  final _searchCtrl   = TextEditingController();
  final _scrollCtrl   = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Charger plus quand on approche du bas (pagination infinie)
  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      final shopId = ref.read(activeShopIdProvider);
      ref.read(paginatedProductsProvider(shopId).notifier).loadMore();
    }
  }

  // Debounce 400ms avant de filtrer
  void _onSearch(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).state = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(authStateProvider).value?.user;
    final role      = user?['marketplaceRole'] as String?;
    final cartCount = ref.watch(cartProvider).itemCount;
    final shopId    = ref.watch(activeShopIdProvider);
    final bannersAsync  = ref.watch(bannersProvider(shopId));
    final featuredAsync = ref.watch(featuredProductsProvider(shopId));
    final paginatedAsync= ref.watch(paginatedProductsProvider(shopId));
    final query     = ref.watch(searchQueryProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);
    final filters   = ref.watch(filterProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        leading: const SizedBox.shrink(),
        title: const Row(children: [
          Text('🛒 ', style: TextStyle(fontSize: 20)),
          Text('Tchokos',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        actions: [
          // Messagerie
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/messages'),
          ),
          // Panier
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
                      color: Colors.red, shape: BoxShape.circle),
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
          ref.invalidate(bannersProvider(shopId));
          ref.invalidate(featuredProductsProvider(shopId));
          ref.read(paginatedProductsProvider(shopId).notifier).refresh();
        },
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [

            // ── Bienvenue TikTok ──────────────────────────────────────────
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
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Découvrez nos produits disponibles',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    )),
                  ]),
                ),
              ),

            // ── Barre recherche + filtre ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(children: [
                  // Champ recherche avec debounce
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                      decoration: InputDecoration(
                        hintText: '${AppTranslations.of(context).t('search')}...',
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
                  const SizedBox(width: 8),
                  // Bouton filtre avec badge si actif
                  Stack(children: [
                    Container(
                      decoration: BoxDecoration(
                        color: filters.hasActiveFilters
                            ? const Color(0xFF1A237E)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 6,
                        )],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.tune,
                          color: filters.hasActiveFilters
                              ? Colors.white
                              : Colors.grey[700],
                        ),
                        onPressed: () => FilterSheet.show(context),
                      ),
                    ),
                    if (filters.hasActiveFilters)
                      Positioned(
                        top: 4, right: 4,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                        ),
                      ),
                  ]),
                ]),
              ),
            ),

            // ── Filtre actif affiché ──────────────────────────────────────
            if (filters.hasActiveFilters)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          if (filters.sort != SortOption.newest)
                            _ActiveChip(label: filters.sort.label,
                                onRemove: () => ref.read(filterProvider.notifier)
                                    .state = ref.read(filterProvider).copyWith(
                                    sort: SortOption.newest)),
                          if (filters.inStockOnly)
                            _ActiveChip(label: '✅ En stock',
                                onRemove: () => ref.read(filterProvider.notifier)
                                    .state = ref.read(filterProvider).copyWith(
                                    inStockOnly: false)),
                          if (filters.wholesaleOnly)
                            _ActiveChip(label: '💼 Prix gros',
                                onRemove: () => ref.read(filterProvider.notifier)
                                    .state = ref.read(filterProvider).copyWith(
                                    wholesaleOnly: false)),
                          if (filters.minPrice != null || filters.maxPrice != null)
                            _ActiveChip(
                              label: 'Prix : ${filters.minPrice?.toStringAsFixed(0) ?? '0'}'
                                  '–${filters.maxPrice?.toStringAsFixed(0) ?? '∞'} FCFA',
                              onRemove: () => ref.read(filterProvider.notifier)
                                  .state = ref.read(filterProvider).copyWith(
                                  clearMinPrice: true, clearMaxPrice: true)),
                        ]),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(filterProvider.notifier)
                          .state = const FilterState(),
                      child: const Text('Tout effacer',
                          style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ]),
                ),
              ),

            // ── Vente flash ───────────────────────────────────────────────
            const SliverToBoxAdapter(child: FlashSaleBanner()),

            // ── Bannières ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: bannersAsync.when(
                loading: () => const SizedBox.shrink(),
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
            if (query.isEmpty && selectedCat == null && !filters.hasActiveFilters) ...[
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

            // ── Label section ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Row(children: [
                  Expanded(child: Text(
                    query.isNotEmpty
                        ? 'Résultats pour "$query"'
                        : selectedCat != null
                            ? selectedCat!
                            : '🛍️ Tous les produits',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  )),
                  // Compteur résultats
                  paginatedAsync.when(
                    data: (p) => Text('${p.items.length} articles',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ]),
              ),
            ),

            // ── Grille produits paginée ───────────────────────────────────
            paginatedAsync.when(
              loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ))),
              error: (err, _) => SliverToBoxAdapter(child: _ErrorState(error: err.toString())),
              data: (paginated) {
                var products = paginated.items;

                // Highlight TikTok en premier
                if (widget.highlightProductId != null) {
                  products = [...products]..sort((a, b) =>
                      a.id == widget.highlightProductId ? -1 : 1);
                }

                if (products.isEmpty) {
                  return const SliverToBoxAdapter(child: _EmptyState());
                }

                final cols = _gridCols(screenWidth);

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => ProductCard(
                        product: products[i],
                        isHighlighted:
                            products[i].id == widget.highlightProductId,
                        onTap: () => context.push(
                            '/marketplace/products/${products[i].id}'),
                      ),
                      childCount: products.length,
                    ),
                  ),
                );
              },
            ),

            // ── Loader pagination ────────────────────────────────────────
            SliverToBoxAdapter(
              child: paginatedAsync.when(
                data: (p) => p.hasMore
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox(height: 24),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip filtre actif ─────────────────────────────────────────────────────────
class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 6),
        child: Chip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          deleteIcon: const Icon(Icons.close, size: 14),
          onDeleted: onRemove,
          backgroundColor: const Color(0xFF1A237E).withOpacity(0.08),
          side: BorderSide(color: const Color(0xFF1A237E).withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
}

// ── État erreur ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          const Text('Impossible de charger les produits',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(error,
                style: const TextStyle(fontSize: 11, color: Colors.red),
                textAlign: TextAlign.center),
          ),
        ]),
      );
}

// ── État vide ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(48),
        child: Column(children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: const Icon(Icons.storefront_outlined,
                size: 40, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text('Aucun produit disponible',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Revenez plus tard ou tirez vers le bas pour actualiser',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ]),
      );
}

// ── Liste horizontale vedettes ────────────────────────────────────────────────
class _HorizontalProductList extends ConsumerWidget {
  final List<Product> products;
  const _HorizontalProductList({required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 240,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (ctx, i) => SizedBox(
          width: 160,
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
