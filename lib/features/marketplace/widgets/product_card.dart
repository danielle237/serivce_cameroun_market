import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    final outOfStock = product.totalStock == 0;
    final discount = product.oldPrice != null
        ? ((product.oldPrice! - product.retailPrice) / product.oldPrice! * 100).round()
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isHighlighted
                  ? const Color(0xFF1976D2).withOpacity(0.2)
                  : Colors.black.withOpacity(0.06),
              blurRadius: isHighlighted ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: isHighlighted
              ? Border.all(color: const Color(0xFF1976D2), width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo ────────────────────────────────────────────────────
            Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: product.photos.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.photos.first,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _Shimmer(),
                          errorWidget: (_, __, ___) => _Placeholder(product: product),
                        )
                      : _Placeholder(product: product),
                ),
              ),

              // Overlay stock épuisé
              if (outOfStock)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Text('ÉPUISÉ',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 14)),
                      ),
                    ),
                  ),
                ),

              // Badge en haut à gauche
              if (product.badge != ProductBadge.none && !outOfStock)
                Positioned(
                  top: 8, left: 8,
                  child: _Badge(label: product.badge.label, color: _badgeColor),
                ),

              // % réduction en haut à droite
              if (discount > 0 && !outOfStock)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('-$discount%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),

              // TikTok
              if (isHighlighted)
                Positioned(
                  bottom: 8, left: 8,
                  child: _Badge(label: '🎵 TikTok', color: Colors.black87),
                ),

              // Stock bas
              if (product.isLowStock && !outOfStock)
                Positioned(
                  bottom: 8, left: 8,
                  child: _Badge(label: '⚡ ${product.totalStock} restants',
                      color: Colors.orange),
                ),

              // Note
              if (product.rating > 0)
                Positioned(
                  bottom: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star, color: Colors.amber, size: 11),
                      const SizedBox(width: 2),
                      Text(product.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
            ]),

            // ── Infos ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13,
                          height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),

                  // Prix
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${_fmt(product.retailPrice)}',
                          style: const TextStyle(
                              color: Color(0xFF1976D2),
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      const Text(' FCFA',
                          style: TextStyle(
                              color: Color(0xFF1976D2),
                              fontWeight: FontWeight.w600,
                              fontSize: 10)),
                    ],
                  ),

                  if (product.oldPrice != null) ...[
                    Text('${_fmt(product.oldPrice!)} FCFA',
                        style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough)),
                  ],

                  // Prix gros dispo
                  if (product.priceTiers.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        '💼 Prix gros dispo',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _badgeColor {
    switch (product.badge) {
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

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 9,
                fontWeight: FontWeight.bold)),
      );
}

class _Placeholder extends StatelessWidget {
  final Product product;
  const _Placeholder({required this.product});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFEEF2FF),
        child: Center(
          child: Text(product.category.emoji,
              style: const TextStyle(fontSize: 52)),
        ),
      );
}

class _Shimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
}
