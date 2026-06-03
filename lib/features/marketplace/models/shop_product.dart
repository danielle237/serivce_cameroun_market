import 'product.dart';

/// Représente un produit tel que retourné par /marketplace/shops/:id/products
/// Alias de Product avec les mêmes champs — on réutilise Product.fromJson
class ShopProduct extends Product {
  const ShopProduct({
    required super.id,
    required super.shopId,
    required super.name,
    super.description,
    required super.category,
    required super.photos,
    required super.retailPrice,
    super.wholesalePrice,
    super.priceTiers,
    super.variants,
    super.colors,
    super.isActive,
    super.isPinned,
    super.badge,
    super.viewCount,
    super.orderCount,
    super.rating,
    super.deepLink,
    super.qrCode,
    required super.createdAt,
    super.oldPrice,
  });

  factory ShopProduct.fromJson(Map<String, dynamic> j) {
    final p = Product.fromJson(j);
    return ShopProduct(
      id:             p.id,
      shopId:         p.shopId,
      name:           p.name,
      description:    p.description,
      category:       p.category,
      photos:         p.photos,
      retailPrice:    p.retailPrice,
      wholesalePrice: p.wholesalePrice,
      priceTiers:     p.priceTiers,
      variants:       p.variants,
      colors:         p.colors,
      isActive:       p.isActive,
      isPinned:       p.isPinned,
      badge:          p.badge,
      viewCount:      p.viewCount,
      orderCount:     p.orderCount,
      rating:         p.rating,
      deepLink:       p.deepLink,
      qrCode:         p.qrCode,
      createdAt:      p.createdAt,
      oldPrice:       p.oldPrice,
    );
  }
}
