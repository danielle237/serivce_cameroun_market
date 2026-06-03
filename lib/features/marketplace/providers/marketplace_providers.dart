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

// ── Produits ──────────────────────────────────────────────────────────────────
final productsProvider = FutureProvider.autoDispose.family<List<Product>, String>((ref, shopId) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/shops/$shopId/products');
  final data = res.data;
  final list = data is List ? data : (data['data'] ?? data['items'] ?? []);
  return (list as List).map((p) => Product.fromJson(Map<String, dynamic>.from(p))).toList();
});

final productDetailProvider = FutureProvider.autoDispose.family<Product, String>((ref, productId) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/products/$productId');
  return Product.fromJson(Map<String, dynamic>.from(res.data));
});

// Produits vedettes (IA + manuel)
final featuredProductsProvider = FutureProvider.autoDispose.family<List<Product>, String>((ref, shopId) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/shops/$shopId/products/featured');
  final data = res.data;
  final list = data is List ? data : (data['data'] ?? []);
  return (list as List).map((p) => Product.fromJson(Map<String, dynamic>.from(p))).toList();
});

// ── Bannières ─────────────────────────────────────────────────────────────────
final bannersProvider = FutureProvider.autoDispose.family<List<MarketplaceBanner>, String>((ref, shopId) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/shops/$shopId/banners');
  final data = res.data;
  final list = data is List ? data : (data['data'] ?? []);
  return (list as List)
      .map((b) => MarketplaceBanner.fromJson(Map<String, dynamic>.from(b)))
      .where((b) => b.isCurrentlyActive)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));
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
