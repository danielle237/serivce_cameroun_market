import 'product.dart';

class CartItem {
  final Product product;
  final String? variant1;
  final String? variant2;
  final String? variantId;
  int qty;

  CartItem({
    required this.product,
    this.variant1,
    this.variant2,
    this.variantId,
    required this.qty,
  });

  double get unitPrice => product.priceForQty(qty);
  double get total => unitPrice * qty;

  String get variantLabel {
    final parts = [variant1, variant2].where((v) => v != null).toList();
    return parts.join(' — ');
  }

  Map<String, dynamic> toJson() => {
    'productId':   product.id,
    'productName': product.name,
    'productPhoto': product.photos.isNotEmpty ? product.photos.first : null,
    'variant1':    variant1,
    'variant2':    variant2,
    'variantId':   variantId,
    'qty':         qty,
    'unitPrice':   unitPrice,
  };
}

class Cart {
  final String shopId;
  final List<CartItem> items;
  String? promoCode;
  double? discount;

  Cart({
    required this.shopId,
    List<CartItem>? items,
    this.promoCode,
    this.discount,
  }) : items = items ?? [];

  double get subtotal => items.fold(0, (sum, i) => sum + i.total);
  double get total => subtotal - (discount ?? 0);
  int get itemCount => items.fold(0, (sum, i) => sum + i.qty);

  void addItem(Product product, {
    String? variant1,
    String? variant2,
    String? variantId,
    int qty = 1,
  }) {
    final existing = items.firstWhere(
      (i) => i.product.id == product.id &&
             i.variant1 == variant1 &&
             i.variant2 == variant2,
      orElse: () => CartItem(
        product: product,
        variant1: variant1,
        variant2: variant2,
        variantId: variantId,
        qty: 0,
      ),
    );
    if (items.contains(existing)) {
      existing.qty += qty;
    } else {
      existing.qty = qty;
      items.add(existing);
    }
  }

  void removeItem(CartItem item) => items.remove(item);

  void clear() {
    items.clear();
    promoCode = null;
    discount = null;
  }

  bool get isEmpty => items.isEmpty;
}
