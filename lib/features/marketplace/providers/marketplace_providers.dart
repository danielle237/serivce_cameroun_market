import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/shop.dart';
import '../models/product.dart';
import '../models/banner.dart';
import '../models/order.dart';
import '../models/cart.dart';
import '../models/vendor.dart';

// ── ShopId actif ──────────────────────────────────────────────────────────────
// Mode mono  (MULTI_BOUTIQUE=false) → AppConfig.shopId constant
// Mode multi (MULTI_BOUTIQUE=true)  → shopId depuis le JWT du user connecté
final activeShopIdProvider = Provider<String>((ref) {
  if (!AppConfig.multiBoutique) return AppConfig.shopId;
  final user = ref.watch(authStateProvider).value?.user;
  return AppConfig.shopIdFor(user);
});

// ── Shop ──────────────────────────────────────────────────────────────────────
final shopProvider = FutureProvider.autoDispose.family<Shop, String>((ref, shopId) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/shops/$shopId');
  return Shop.fromJson(Map<String, dynamic>.from(res.data));
});

final shopsProvider = FutureProvider.autoDispose<List<Shop>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/shops');
  final data = res.data;
  final list = data is List ? data : (data['data'] ?? data['items'] ?? []);
  return (list as List).map((s) => Shop.fromJson(Map<String, dynamic>.from(s))).toList();
});

// Helper pour parser une liste de façon sécurisée
List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
  try {
    final list = data is List ? data : (data['data'] ?? data['items'] ?? []);
    return (list as List)
        .where((e) => e != null)
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (_) { return []; }
}

// ── Produits ──────────────────────────────────────────────────────────────────
final productsProvider = FutureProvider.autoDispose.family<List<Product>, String>((ref, shopId) async {
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/marketplace/shops/$shopId/products');
    return _parseList(res.data, Product.fromJson);
  } catch (_) { return []; }
});

final productDetailProvider = FutureProvider.autoDispose.family<Product, String>((ref, productId) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/products/$productId');
  return Product.fromJson(Map<String, dynamic>.from(res.data));
});

// Produits vedettes (IA + manuel)
final featuredProductsProvider = FutureProvider.autoDispose.family<List<Product>, String>((ref, shopId) async {
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/marketplace/shops/$shopId/products/featured');
    return _parseList(res.data, Product.fromJson);
  } catch (_) { return []; }
});

// ── Bannières ─────────────────────────────────────────────────────────────────
final bannersProvider = FutureProvider.autoDispose.family<List<MarketplaceBanner>, String>((ref, shopId) async {
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/marketplace/shops/$shopId/banners');
    final data = res.data;
    final list = data is List ? data : (data['data'] ?? []);
    return (list as List)
        .where((b) => b != null)
        .map((b) => MarketplaceBanner.fromJson(Map<String, dynamic>.from(b as Map)))
        .where((b) => b.isCurrentlyActive)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  } catch (_) { return []; }
});

// ── Commandes ─────────────────────────────────────────────────────────────────
final myOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/orders/mine');
  final data = res.data;
  final list = data is List ? data : (data['data'] ?? []);
  return (list as List).map((o) => Order.fromJson(Map<String, dynamic>.from(o))).toList();
});

final vendorOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/orders/vendor');
  final data = res.data;
  final list = data is List ? data : (data['data'] ?? []);
  return (list as List).map((o) => Order.fromJson(Map<String, dynamic>.from(o))).toList();
});

final orderDetailProvider = FutureProvider.autoDispose.family<Order, String>((ref, orderId) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/orders/$orderId');
  return Order.fromJson(Map<String, dynamic>.from(res.data));
});

// ── Stats Tokos Boss ──────────────────────────────────────────────────────────
final bossStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/marketplace/stats/boss');
    return Map<String, dynamic>.from(res.data);
  } catch (_) {
    return {};
  }
});

// ── Stats TikTok ──────────────────────────────────────────────────────────────
final tiktokStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/marketplace/stats/tiktok');
    return Map<String, dynamic>.from(res.data);
  } catch (_) {
    return {};
  }
});

// ── Codes promo ───────────────────────────────────────────────────────────────
final promoCodesProvider = FutureProvider.autoDispose<List<PromoCode>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/promo-codes');
  final data = res.data;
  final list = data is List ? data : (data['data'] ?? []);
  return (list as List).map((p) => PromoCode.fromJson(Map<String, dynamic>.from(p))).toList();
});

// ── Panier (état local) ───────────────────────────────────────────────────────
class CartNotifier extends StateNotifier<Cart> {
  CartNotifier() : super(Cart(shopId: AppConfig.shopId));

  void addItem(Product product, {
    String? variant1,
    String? variant2,
    String? variantId,
    int qty = 1,
  }) {
    state.addItem(product,
      variant1: variant1,
      variant2: variant2,
      variantId: variantId,
      qty: qty,
    );
    state = Cart(
      shopId: state.shopId,
      items: List.from(state.items),
      promoCode: state.promoCode,
      discount: state.discount,
    );
  }

  void removeItem(CartItem item) {
    state.removeItem(item);
    state = Cart(
      shopId: state.shopId,
      items: List.from(state.items),
      promoCode: state.promoCode,
      discount: state.discount,
    );
  }

  void updateQty(CartItem item, int qty) {
    if (qty <= 0) {
      removeItem(item);
      return;
    }
    item.qty = qty;
    state = Cart(
      shopId: state.shopId,
      items: List.from(state.items),
      promoCode: state.promoCode,
      discount: state.discount,
    );
  }

  void applyPromo(String code, double discount) {
    state = Cart(
      shopId: state.shopId,
      items: List.from(state.items),
      promoCode: code,
      discount: discount,
    );
  }

  void clear() {
    state = Cart(shopId: state.shopId);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, Cart>(
  (_) => CartNotifier(),
);

// ── Vendeurs ──────────────────────────────────────────────────────────────────
final vendorsProvider = FutureProvider.autoDispose<List<Vendor>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/vendors');
  final data = res.data;
  final list = data is List ? data : (data['data'] ?? []);
  return (list as List).map((v) => Vendor.fromJson(Map<String, dynamic>.from(v))).toList();
});

// ── Recherche produits ────────────────────────────────────────────────────────
final searchQueryProvider = StateProvider<String>((_) => '');
final selectedCategoryProvider = StateProvider<String?>((_) => null);

// ── Filtres avancés ───────────────────────────────────────────────────────────
enum SortOption { newest, priceAsc, priceDesc, bestSeller, topRated }

extension SortOptionExt on SortOption {
  String get label {
    switch (this) {
      case SortOption.newest:     return '🆕 Nouveautés';
      case SortOption.priceAsc:   return '💰 Prix croissant';
      case SortOption.priceDesc:  return '💎 Prix décroissant';
      case SortOption.bestSeller: return '🔥 Meilleures ventes';
      case SortOption.topRated:   return '⭐ Mieux notés';
    }
  }
}

class FilterState {
  final SortOption sort;
  final double? minPrice;
  final double? maxPrice;
  final bool inStockOnly;
  final bool wholesaleOnly;

  const FilterState({
    this.sort = SortOption.newest,
    this.minPrice,
    this.maxPrice,
    this.inStockOnly = false,
    this.wholesaleOnly = false,
  });

  FilterState copyWith({
    SortOption? sort,
    double? minPrice,
    double? maxPrice,
    bool? inStockOnly,
    bool? wholesaleOnly,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) => FilterState(
    sort:          sort ?? this.sort,
    minPrice:      clearMinPrice ? null : (minPrice ?? this.minPrice),
    maxPrice:      clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
    inStockOnly:   inStockOnly ?? this.inStockOnly,
    wholesaleOnly: wholesaleOnly ?? this.wholesaleOnly,
  );

  bool get hasActiveFilters =>
      sort != SortOption.newest ||
      minPrice != null ||
      maxPrice != null ||
      inStockOnly ||
      wholesaleOnly;

  // Appliquer les filtres localement sur une liste de produits
  List<Product> apply(List<Product> products) {
    var result = products.where((p) {
      if (inStockOnly && p.totalStock == 0) return false;
      if (wholesaleOnly && p.priceTiers.isEmpty) return false;
      if (minPrice != null && p.retailPrice < minPrice!) return false;
      if (maxPrice != null && p.retailPrice > maxPrice!) return false;
      return true;
    }).toList();

    switch (sort) {
      case SortOption.priceAsc:
        result.sort((a, b) => a.retailPrice.compareTo(b.retailPrice));
        break;
      case SortOption.priceDesc:
        result.sort((a, b) => b.retailPrice.compareTo(a.retailPrice));
        break;
      case SortOption.bestSeller:
        result.sort((a, b) => b.orderCount.compareTo(a.orderCount));
        break;
      case SortOption.topRated:
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortOption.newest:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return result;
  }
}

final filterProvider = StateProvider<FilterState>((_) => const FilterState());

// ── Pagination ────────────────────────────────────────────────────────────────
const kPageSize = 20;

class PaginatedProducts {
  final List<Product> items;
  final bool hasMore;
  final int page;
  const PaginatedProducts({required this.items, required this.hasMore, required this.page});
}

class PaginatedProductsNotifier extends StateNotifier<AsyncValue<PaginatedProducts>> {
  final Ref _ref;
  final String shopId;
  bool _loading = false;

  PaginatedProductsNotifier(this._ref, this.shopId)
      : super(const AsyncValue.loading()) {
    loadFirst();
  }

  Future<void> loadFirst() async {
    state = const AsyncValue.loading();
    await _load(1);
  }

  Future<void> loadMore() async {
    if (_loading) return;
    final current = state.value;
    if (current == null || !current.hasMore) return;
    await _load(current.page + 1);
  }

  Future<void> _load(int page) async {
    _loading = true;
    try {
      final api = _ref.read(apiClientProvider);
      final filter = _ref.read(filterProvider);
      final query  = _ref.read(searchQueryProvider);
      final cat    = _ref.read(selectedCategoryProvider);

      final res = await api.get(
        '/marketplace/shops/$shopId/products',
        params: {
          'page': page,
          'limit': kPageSize,
          if (query.isNotEmpty) 'q': query,
          if (cat != null) 'category': cat,
        },
      );

      var fetched = _parseList(res.data, Product.fromJson);

      // Filtrage catégorie côté client (le backend ne supporte pas ce param)
      if (cat != null) {
        fetched = fetched.where((p) =>
            p.category.label == cat || p.category.name == cat).toList();
      }

      // Recherche texte côté client
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        fetched = fetched.where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.description?.toLowerCase().contains(q) ?? false)).toList();
      }

      final items = filter.apply(fetched);

      final current = state.value;
      final List<Product> all = page == 1
          ? items
          : [...(current?.items ?? <Product>[]), ...items];

      state = AsyncValue.data(PaginatedProducts(
        items:   all,
        hasMore: items.length >= kPageSize,
        page:    page,
      ));
    } catch (e, s) {
      if (page == 1) state = AsyncValue.error(e, s);
    } finally {
      _loading = false;
    }
  }

  void refresh() => loadFirst();
}

final AutoDisposeStateNotifierProviderFamily<PaginatedProductsNotifier,
        AsyncValue<PaginatedProducts>, String> paginatedProductsProvider =
    StateNotifierProvider.autoDispose
        .family<PaginatedProductsNotifier, AsyncValue<PaginatedProducts>, String>(
  (ref, shopId) {
    // Re-charger quand les filtres ou la recherche changent
    ref.listen(filterProvider, (_, __) =>
        ref.read(paginatedProductsProvider(shopId).notifier).loadFirst());
    ref.listen(searchQueryProvider, (_, __) =>
        ref.read(paginatedProductsProvider(shopId).notifier).loadFirst());
    ref.listen(selectedCategoryProvider, (_, __) =>
        ref.read(paginatedProductsProvider(shopId).notifier).loadFirst());
    return PaginatedProductsNotifier(ref, shopId);
  },
);
