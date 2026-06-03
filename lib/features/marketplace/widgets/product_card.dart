import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final bool isHighlighted;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isHighlighted
              ? Border.all(color: const Color(0xFF1976D2), width: 2)
              : Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo produit ──────────────────────────────────────────
            Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
                child: product.photos.isNotEmpty
                    ? Image.network(
                        product.photos.first,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PhotoPlaceholder(product: product),
                      )
                    : _PhotoPlaceholder(product: product),
              ),

              // Badge vedette
              if (product.badge != ProductBadge.none)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _badgeColor(product.badge),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      product.badge.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // Stock épuisé
              if (!product.isLowStock && product.totalStock == 0)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14)),
                    child: Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Text('ÉPUISÉ',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                    ),
                  ),
                ),

              // TikTok highlight
              if (isHighlighted)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('🎵 TikTok',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),

            // ── Infos produit ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Prix
                  Row(children: [
                    Text(
                      '${_fmt(product.retailPrice)} FCFA',
                      style: const TextStyle(
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.w800,
                          fontSize: 14),
                    ),
                    if (product.oldPrice != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${_fmt(product.oldPrice!)}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ]),

                  // Stock bas
                  if (product.isLowStock) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⚡ Plus que ${product.totalStock} en stock',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ],

                  // Catégorie
                  const SizedBox(height: 4),
                  Text(
                    '${product.category.emoji} ${product.category.label}',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _badgeColor(ProductBadge badge) {
    switch (badge) {
      case ProductBadge.featured:   return const Color(0xFFFFB300);
      case ProductBadge.trending:   return Colors.red;
      case ProductBadge.popular:    return Colors.blue;
      case ProductBadge.topRated:   return Colors.purple;
      case ProductBadge.newProduct: return Colors.green;
      case ProductBadge.lastItems:  return Colors.orange;
      case ProductBadge.seasonal:   return Colors.teal;
      default:                       return Colors.grey;
    }
  }

  String _fmt(double v) {
    return v.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final Product product;
  const _PhotoPlaceholder({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      color: const Color(0xFF1976D2).withOpacity(0.08),
      child: Center(
        child: Text(product.category.emoji,
            style: const TextStyle(fontSize: 48)),
      ),
    );
  }
}
