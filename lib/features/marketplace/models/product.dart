// ── Catégories ────────────────────────────────────────────────────────────────
enum ProductCategory {
  textile,
  chaussures,
  electronique,
  lit,
  marmite,
  autre,
}

extension ProductCategoryExt on ProductCategory {
  String get label {
    switch (this) {
      case ProductCategory.textile:      return 'Textile';
      case ProductCategory.chaussures:   return 'Chaussures';
      case ProductCategory.electronique: return 'Électronique';
      case ProductCategory.lit:          return 'Lit';
      case ProductCategory.marmite:      return 'Marmite';
      case ProductCategory.autre:        return 'Autre';
    }
  }

  String get emoji {
    switch (this) {
      case ProductCategory.textile:      return '👗';
      case ProductCategory.chaussures:   return '👟';
      case ProductCategory.electronique: return '📱';
      case ProductCategory.lit:          return '🛏️';
      case ProductCategory.marmite:      return '🥘';
      case ProductCategory.autre:        return '🏠';
    }
  }

  // Variante 1 par catégorie
  List<String> get variant1Options {
    switch (this) {
      case ProductCategory.textile:
        return ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
      case ProductCategory.chaussures:
        return ['36','37','38','39','40','41','42','43','44','45'];
      case ProductCategory.electronique:
        return ['64Go', '128Go', '256Go', '512Go', '1To'];
      case ProductCategory.lit:
        return ['90x190', '140x190', '160x200', '180x200', '200x200'];
      case ProductCategory.marmite:
        return ['5L', '10L', '15L', '20L', '25L'];
      case ProductCategory.autre:
        return [];
    }
  }

  String get variant1Label {
    switch (this) {
      case ProductCategory.textile:      return 'Taille';
      case ProductCategory.chaussures:   return 'Pointure';
      case ProductCategory.electronique: return 'Capacité';
      case ProductCategory.lit:          return 'Dimensions';
      case ProductCategory.marmite:      return 'Contenance';
      case ProductCategory.autre:        return 'Variante';
    }
  }
}

// ── Palier prix gros ──────────────────────────────────────────────────────────
class PriceTier {
  final int minQty;
  final int? maxQty; // null = illimité
  final double price;

  const PriceTier({
    required this.minQty,
    this.maxQty,
    required this.price,
  });

  factory PriceTier.fromJson(Map<String, dynamic> j) => PriceTier(
    minQty: j['minQty'] is int ? j['minQty'] : int.tryParse('${j['minQty']}') ?? 0,
    maxQty: j['maxQty'] == null ? null : (j['maxQty'] is int ? j['maxQty'] : int.tryParse('${j['maxQty']}')),
    price:  j['price'] is num ? (j['price'] as num).toDouble() : double.tryParse('${j['price']}') ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'minQty': minQty,
    'maxQty': maxQty,
    'price':  price,
  };

  String get label {
    if (maxQty == null) return '$minQty+ pièces';
    return '$minQty-$maxQty pièces';
  }
}

// ── Variante produit ──────────────────────────────────────────────────────────
class ProductVariant {
  final String id;
  final String? variant1; // taille / pointure / capacité
  final String? variant2; // couleur
  final int stock;
  final String? sku;

  const ProductVariant({
    required this.id,
    this.variant1,
    this.variant2,
    required this.stock,
    this.sku,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> j) => ProductVariant(
    id:       j['id'] as String,
    variant1: j['variant1'] as String?,
    variant2: j['variant2'] as String?,
    stock:    j['stock'] as int,
    sku:      j['sku'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id':       id,
    'variant1': variant1,
    'variant2': variant2,
    'stock':    stock,
    'sku':      sku,
  };

  String get label {
    final parts = [variant1, variant2].where((v) => v != null).toList();
    return parts.join(' — ');
  }

  bool get isAvailable => stock > 0;
}

// ── Badge produit vedette ─────────────────────────────────────────────────────
enum ProductBadge {
  none,
  featured,    // ⭐ Coup de cœur Tokos
  trending,    // 🔥 Tendance
  popular,     // 👁️ Populaire
  topRated,    // ⭐ Top qualité
  newProduct,  // 🆕 Nouveau
  lastItems,   // ⚡ Dernières pièces
  seasonal,    // 📅 Saison
}

extension ProductBadgeExt on ProductBadge {
  String get label {
    switch (this) {
      case ProductBadge.none:       return '';
      case ProductBadge.featured:   return '⭐ Coup de cœur';
      case ProductBadge.trending:   return '🔥 Tendance';
      case ProductBadge.popular:    return '👁️ Populaire';
      case ProductBadge.topRated:   return '⭐ Top qualité';
      case ProductBadge.newProduct: return '🆕 Nouveau';
      case ProductBadge.lastItems:  return '⚡ Dernières pièces';
      case ProductBadge.seasonal:   return '📅 Saison';
    }
  }
}

// ── Produit ───────────────────────────────────────────────────────────────────
class Product {
  final String id;
  final String shopId;
  final String name;
  final String? description;
  final ProductCategory category;
  final List<String> photos;
  final double retailPrice;       // Prix détail
  final double? wholesalePrice;   // Prix gros de base
  final List<PriceTier> priceTiers; // Paliers dégressifs
  final List<ProductVariant> variants;
  final List<String> colors;
  final bool isActive;
  final bool isPinned;            // Épinglé manuellement par Tokos
  final bool isSponsored;         // Vendeur a payé pour apparaître en premier
  final ProductBadge badge;
  final int viewCount;
  final int orderCount;
  final double rating;
  final String? deepLink;         // Lien TikTok
  final String? qrCode;
  final DateTime createdAt;
  final double? oldPrice;         // Ancien prix barré

  const Product({
    required this.id,
    required this.shopId,
    required this.name,
    this.description,
    required this.category,
    required this.photos,
    required this.retailPrice,
    this.wholesalePrice,
    this.priceTiers = const [],
    this.variants = const [],
    this.colors = const [],
    this.isActive = true,
    this.isPinned = false,
    this.isSponsored = false,
    this.badge = ProductBadge.none,
    this.viewCount = 0,
    this.orderCount = 0,
    this.rating = 0,
    this.deepLink,
    this.qrCode,
    required this.createdAt,
    this.oldPrice,
  });

  // PostgreSQL DECIMAL/NUMERIC revient parfois en String — on gère les deux
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static double? _toDoubleNullable(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id:             j['id'] as String,
    shopId:         (j['shopId'] ?? j['shop_id'] ?? '') as String,
    name:           j['name'] as String,
    description:    j['description'] as String?,
    category:       ProductCategory.values.firstWhere(
      (c) => c.name == j['category'],
      orElse: () => ProductCategory.autre,
    ),
    photos:         List<String>.from(j['photos'] ?? []),
    retailPrice:    _toDouble(j['retailPrice'] ?? j['retail_price']),
    wholesalePrice: _toDoubleNullable(j['wholesalePrice'] ?? j['wholesale_price']),
    priceTiers:     ((j['priceTiers'] ?? j['price_tiers']) as List? ?? [])
        .map((t) => PriceTier.fromJson(Map<String, dynamic>.from(t))).toList(),
    variants:       ((j['variants']) as List? ?? [])
        .map((v) => ProductVariant.fromJson(Map<String, dynamic>.from(v))).toList(),
    colors:         List<String>.from(j['colors'] ?? []),
    isActive:       j['isActive'] ?? j['is_active'] as bool? ?? true,
    isPinned:       j['isPinned'] ?? j['is_pinned'] as bool? ?? false,
    isSponsored:    j['isSponsored'] ?? j['is_sponsored'] as bool? ?? false,
    badge:          ProductBadge.values.firstWhere(
      (b) => b.name == (j['badge'] ?? 'none'),
      orElse: () => ProductBadge.none,
    ),
    viewCount:      _toInt(j['viewCount'] ?? j['view_count']),
    orderCount:     _toInt(j['orderCount'] ?? j['order_count']),
    rating:         _toDouble(j['rating']),
    deepLink:       j['deepLink'] ?? j['deep_link'] as String?,
    qrCode:         j['qrCode'] ?? j['qr_code'] as String?,
    createdAt:      DateTime.tryParse(j['createdAt'] ?? j['created_at'] ?? '') ?? DateTime.now(),
    oldPrice:       _toDoubleNullable(j['oldPrice'] ?? j['old_price']),
  );

  // Prix selon profil
  double priceForQty(int qty) {
    if (priceTiers.isEmpty) return retailPrice;
    for (final tier in priceTiers.reversed) {
      if (qty >= tier.minQty) return tier.price;
    }
    return retailPrice;
  }

  // Stock total
  int get totalStock =>
      variants.fold(0, (sum, v) => sum + v.stock);

  bool get isNew =>
      DateTime.now().difference(createdAt).inDays < 7;

  bool get isLowStock => totalStock > 0 && totalStock <= 5;
}
