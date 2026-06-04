import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/product.dart';
import '../providers/marketplace_providers.dart';
import '../providers/extras_providers.dart';
import '../widgets/product_card.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState
    extends ConsumerState<ProductDetailScreen> {
  String? _selectedVariant1;
  String? _selectedVariant2;
  int _qty = 1;
  int _currentPhoto = 0;

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final cartCount = ref.watch(cartProvider).itemCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Partager
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final p = productAsync.value;
              if (p == null) return;
              Share.share(
                '🛒 Regarde ce produit sur Tchokos !\n'
                '${p.name} — ${_fmt2(p.retailPrice)} FCFA\n'
                '${AppConfig.shopLink(AppConfig.shopId, productSlug: p.id)}\n'
                'Télécharge W2D pour commander 👇',
                subject: p.name,
              );
            },
          ),
          // Favori
          _FavoriteButton(productId: widget.productId, shopId: AppConfig.shopId),
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
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ]),
        ],
      ),
      body: productAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (product) => _buildBody(product),
      ),
    );
  }

  Widget _buildBody(Product product) {
    // Variante sélectionnée
    final selectedVariant = product.variants.firstWhere(
      (v) =>
          v.variant1 == _selectedVariant1 &&
          v.variant2 == _selectedVariant2,
      orElse: () => product.variants.isNotEmpty
          ? product.variants.first
          : ProductVariant(id: '', stock: 0),
    );

    final unitPrice = product.priceForQty(_qty);
    final total = unitPrice * _qty;

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photos ──────────────────────────────────────────────
              Stack(children: [
                SizedBox(
                  height: 300,
                  child: product.photos.isNotEmpty
                      ? PageView.builder(
                          itemCount: product.photos.length,
                          onPageChanged: (i) =>
                              setState(() => _currentPhoto = i),
                          itemBuilder: (ctx, i) => GestureDetector(
                            // Tap → zoom plein écran
                            onTap: () => _showPhotoZoom(ctx, product.photos, i),
                            child: Image.network(
                              product.photos[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF1976D2).withOpacity(0.08),
                                child: Center(child: Text(product.category.emoji,
                                    style: const TextStyle(fontSize: 80))),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF1976D2).withOpacity(0.08),
                          child: Center(child: Text(product.category.emoji,
                              style: const TextStyle(fontSize: 80))),
                        ),
                ),
                // Hint zoom
                if (product.photos.isNotEmpty)
                  Positioned(
                    bottom: 48, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Zoomer', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ]),
                    ),
                  ),
                // Indicateurs photos
                if (product.photos.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        product.photos.length,
                        (i) => Container(
                          width: i == _currentPhoto ? 16 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _currentPhoto
                                ? Colors.white
                                : Colors.white54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Badge
                if (product.badge != ProductBadge.none)
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(product.badge.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ]),

              // ── Infos ────────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),

                    // Prix
                    Row(children: [
                      Text(
                        '${_fmt(unitPrice)} FCFA',
                        style: const TextStyle(
                            color: Color(0xFF1976D2),
                            fontSize: 22,
                            fontWeight: FontWeight.w800),
                      ),
                      if (product.oldPrice != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          '${_fmt(product.oldPrice!)} FCFA',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough),
                        ),
                      ],
                    ]),

                    // Paliers prix gros
                    if (product.priceTiers.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💰 Prix gros disponibles',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Color(0xFF1976D2))),
                            const SizedBox(height: 6),
                            ...product.priceTiers.map((tier) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(children: [
                                Expanded(child: Text(tier.label,
                                    style: const TextStyle(fontSize: 12))),
                                Text('${_fmt(tier.price)} FCFA/pièce',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: Color(0xFF1976D2))),
                              ]),
                            )),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Variante 1 (taille/pointure) ─────────────────────────
              if (product.category.variant1Options.isNotEmpty)
                _VariantSection(
                  title: product.category.variant1Label,
                  options: product.category.variant1Options,
                  selected: _selectedVariant1,
                  onSelect: (v) => setState(() => _selectedVariant1 = v),
                  stockByVariant: {
                    for (final v in product.variants)
                      if (v.variant1 != null) v.variant1!: v.stock,
                  },
                ),

              // ── Variante 2 (couleur) ──────────────────────────────────
              if (product.colors.isNotEmpty)
                _ColorSection(
                  colors: product.colors,
                  selected: _selectedVariant2,
                  onSelect: (v) => setState(() => _selectedVariant2 = v),
                ),

              const SizedBox(height: 8),

              // ── Quantité ──────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quantité',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 10),
                    Row(children: [
                      // Bouton -
                      _QtyButton(
                        icon: Icons.remove,
                        onTap: () {
                          if (_qty > 1) setState(() => _qty--);
                        },
                      ),
                      const SizedBox(width: 8),
                      // Champ saisie directe — tap pour entrer un nombre custom
                      GestureDetector(
                        onTap: () => _showQtyDialog(product.totalStock),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 56),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFF1976D2), width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_qty',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800,
                                color: Color(0xFF1976D2)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Bouton +
                      _QtyButton(
                        icon: Icons.add,
                        onTap: () => setState(() => _qty++),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_fmt(unitPrice)} FCFA/pièce',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                          Text(
                            'Total: ${_fmt(total)} FCFA',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1976D2)),
                          ),
                        ],
                      ),
                    ]),

                    // Paliers : affiche quel palier est actif
                    if (product.priceTiers.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: product.priceTiers.map((tier) {
                          final isActive = _qty >= tier.minQty &&
                              (tier.maxQty == null || _qty <= tier.maxQty!);
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _qty = tier.minQty),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF1976D2)
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF1976D2),
                                  width: isActive ? 0 : 1,
                                ),
                              ),
                              child: Text(
                                '${tier.label} → ${_fmt(tier.price)} FCFA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isActive
                                      ? Colors.white
                                      : const Color(0xFF1976D2),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // Suggestion : "Ajoutez X pièces pour le prix gros"
                    _buildPriceSuggestion(product, unitPrice),
                  ],
                ),
              ),

              // ── Description ───────────────────────────────────────────
              if (product.description != null) ...[
                const SizedBox(height: 8),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Description',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 8),
                      Text(product.description!,
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13)),
                    ],
                  ),
                ),
              ],

              // ── Produits similaires ────────────────────────────────────
              _SimilarProductsSection(
                category: product.category.name,
                excludeId: product.id,
              ),

              // ── Historique prix ────────────────────────────────────────
              _PriceHistorySection(productId: widget.productId),

              // ── Avis & notes ───────────────────────────────────────────
              _ReviewsSection(
                productId: widget.productId,
                rating: product.rating,
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),

      // ── Bouton Ajouter au panier ──────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10, offset: const Offset(0, -3),
          )],
        ),
        child: Row(children: [
          // Bouton contacter Tchokos
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Contacter Tchokos',
              onPressed: () => _openChat(productAsync.value!),
            ),
          ),
          const SizedBox(width: 12),
          // Bouton ajouter
          Expanded(
            child: ElevatedButton.icon(
              onPressed: selectedVariant.stock > 0
                  ? () {
                      ref.read(cartProvider.notifier).addItem(
                        productAsync.value!,
                        variant1: _selectedVariant1,
                        variant2: _selectedVariant2,
                        variantId: selectedVariant.id,
                        qty: _qty,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '✅ ${product.name} ajouté au panier'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'Voir panier',
                            textColor: Colors.white,
                            onPressed: () {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              context.push('/marketplace/cart');
                            },
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text(
                selectedVariant.stock > 0
                    ? 'Ajouter au panier'
                    : 'Stock épuisé',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  // Dialog saisie quantité custom (pour les grossistes)
  // Suggestion prix gros
  Widget _buildPriceSuggestion(Product product, double currentUnitPrice) {
    if (product.priceTiers.isEmpty) return const SizedBox.shrink();

    // Prix gros actif → afficher l'économie
    if (currentUnitPrice < product.retailPrice) {
      final saving = (product.retailPrice - currentUnitPrice) * _qty;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Prix gros appliqué — vous économisez ${_fmt(saving)} FCFA',
                style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      );
    }

    // Cherche le prochain palier accessible
    final nextTier = product.priceTiers
        .where((t) => t.minQty > _qty)
        .fold<PriceTier?>(null, (best, t) =>
            best == null || t.minQty < best.minQty ? t : best);

    if (nextTier == null) return const SizedBox.shrink();

    final missing = nextTier.minQty - _qty;
    final savingPerPiece = product.retailPrice - nextTier.price;
    final totalSaving = nextTier.price * nextTier.minQty;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () => setState(() => _qty = nextTier.minQty),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.lightbulb_outline,
                color: Colors.orange, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: 'Ajoutez $missing pièce${missing > 1 ? 's' : ''} ',
                    ),
                    TextSpan(
                      text: '(${nextTier.minQty} au total)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' pour passer à '),
                    TextSpan(
                      text: '${_fmt(nextTier.price)} FCFA/pièce',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text:
                          ' — économie de ${_fmt(savingPerPiece)} FCFA/pièce',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+$missing',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showQtyDialog(int maxStock) {
    final ctrl = TextEditingController(text: '$_qty');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quantité'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ex: 50, 100, 200...',
                suffixText: 'pièces',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (_) => _applyQty(ctrl.text, ctx),
            ),
            const SizedBox(height: 8),
            Text('Stock disponible : $maxStock pièces',
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => _applyQty(ctrl.text, ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _applyQty(String value, BuildContext ctx) {
    final qty = int.tryParse(value.trim());
    if (qty != null && qty >= 1) {
      setState(() => _qty = qty);
    }
    Navigator.pop(ctx);
  }

  // Getter pour productAsync dans le build
  AsyncValue<Product> get productAsync =>
      ref.watch(productDetailProvider(widget.productId));

  // Zoom plein écran avec InteractiveViewer (pinch to zoom)
  void _showPhotoZoom(BuildContext ctx, List<String> photos, int initial) {
    showDialog(
      context: ctx,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          PageView.builder(
            controller: PageController(initialPage: initial),
            itemCount: photos.length,
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: Image.network(photos[i], fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40, right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // Ouvre le chat avec Tokos en passant le contexte produit
  Future<void> _openChat(Product product) async {
    final shopAsync = ref.read(shopProvider(AppConfig.shopId));
    final shop = shopAsync.value;
    if (shop == null) {
      // Charger la boutique si pas encore en cache
      final loaded = await ref.read(shopProvider(AppConfig.shopId).future);
      if (mounted) {
        context.push(
          '/messages/chat/${loaded.ownerId}',
          extra: {
            'marketplaceData': {
              'type': 'product',
              'productId': product.id,
              'productName': product.name,
              'productPhoto': product.photos.isNotEmpty ? product.photos.first : null,
              'productPrice': product.retailPrice,
            },
          },
        );
      }
      return;
    }
    if (mounted) {
      context.push(
        '/messages/chat/${shop.ownerId}',
        extra: {
          'marketplaceData': {
            'type': 'product',
            'productId': product.id,
            'productName': product.name,
            'productPhoto': product.photos.isNotEmpty ? product.photos.first : null,
            'productPrice': product.retailPrice,
          },
        },
      );
    }
  }

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  static String _fmt2(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ── Section variante ──────────────────────────────────────────────────────────
class _VariantSection extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final Map<String, int> stockByVariant;

  const _VariantSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.stockByVariant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final stock = stockByVariant[opt] ?? 0;
            final isSelected = selected == opt;
            final isOutOfStock = stock == 0;
            return GestureDetector(
              onTap: isOutOfStock ? null : () =>
                  onSelect(isSelected ? null : opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1976D2)
                      : isOutOfStock
                          ? Colors.grey.shade100
                          : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1976D2)
                        : isOutOfStock
                            ? Colors.grey.shade300
                            : Colors.grey.shade400,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOutOfStock ? '$opt ✗' : opt,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : isOutOfStock
                            ? Colors.grey.shade400
                            : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ── Section couleur ───────────────────────────────────────────────────────────
class _ColorSection extends StatelessWidget {
  final List<String> colors;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _ColorSection({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Couleur',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) {
            final isSelected = selected == color;
            return GestureDetector(
              onTap: () => onSelect(isSelected ? null : color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1976D2).withOpacity(0.1)
                      : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1976D2)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(color,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF1976D2)
                          : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    )),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ── Bouton quantité ───────────────────────────────────────────────────────────
class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1976D2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF1976D2), size: 18),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOUTON FAVORI
// ═════════════════════════════════════════════════════════════════════════════
class _FavoriteButton extends ConsumerStatefulWidget {
  final String productId;
  final String shopId;
  const _FavoriteButton({required this.productId, required this.shopId});

  @override
  ConsumerState<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<_FavoriteButton> {
  bool? _isFav;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    ref.read(isFavoriteProvider(widget.productId).future)
        .then((v) { if (mounted) setState(() => _isFav = v); });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isFav == true ? Icons.favorite : Icons.favorite_border,
        color: _isFav == true ? Colors.red : null,
      ),
      onPressed: _loading ? null : _toggle,
    );
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/marketplace/favorites/${widget.productId}',
        data: {'shopId': widget.shopId},
      );
      setState(() => _isFav = res.data['isFavorite'] as bool? ?? false);
      ref.invalidate(favoritesProvider);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PRODUITS SIMILAIRES
// ═════════════════════════════════════════════════════════════════════════════
class _SimilarProductsSection extends ConsumerWidget {
  final String category;
  final String excludeId;
  const _SimilarProductsSection({required this.category, required this.excludeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopId    = ref.watch(activeShopIdProvider);
    final productsAsync = ref.watch(productsProvider(shopId));

    return productsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (all) {
        final similar = all
            .where((p) => p.category.name == category && p.id != excludeId && p.isActive)
            .toList()
          ..sort((a, b) => b.orderCount.compareTo(a.orderCount));

        if (similar.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 8),
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Text('🛍️ Vous aimerez aussi',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: similar.take(6).length,
                  itemBuilder: (ctx, i) => SizedBox(
                    width: 150,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ProductCard(
                        product: similar[i],
                        onTap: () => context.push(
                            '/marketplace/products/${similar[i].id}'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HISTORIQUE PRIX
// ═════════════════════════════════════════════════════════════════════════════
class _PriceHistorySection extends ConsumerWidget {
  final String productId;
  const _PriceHistorySection({required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(priceHistoryProvider(productId));

    return histAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (history) {
        if (history.length < 2) return const SizedBox.shrink();

        final spots = history.asMap().entries.map((e) {
          final price = double.tryParse('${e.value['newPrice'] ?? e.value['new_price']}') ?? 0;
          return FlSpot(e.key.toDouble(), price);
        }).toList();

        final minPrice = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
        final maxPrice = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
        final lastPrice = spots.last.y;
        final prevPrice = spots[spots.length - 2].y;
        final dropped = lastPrice < prevPrice;

        return Container(
          margin: const EdgeInsets.only(top: 8),
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('📈 Historique des prix',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                if (dropped)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('📉 Prix en baisse',
                        style: TextStyle(color: Colors.green, fontSize: 11)),
                  ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: LineChart(
                  LineChartData(
                    minY: minPrice * 0.9,
                    maxY: maxPrice * 1.1,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: dropped ? Colors.green : const Color(0xFF1976D2),
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: (dropped ? Colors.green : const Color(0xFF1976D2))
                              .withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Min : ${_fmt(minPrice)} FCFA',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('Actuel : ${_fmt(lastPrice)} FCFA',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: dropped ? Colors.green : const Color(0xFF1976D2))),
                  Text('Max : ${_fmt(maxPrice)} FCFA',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ═════════════════════════════════════════════════════════════════════════════
// AVIS & NOTES
// ═════════════════════════════════════════════════════════════════════════════
class _ReviewsSection extends ConsumerStatefulWidget {
  final String productId;
  final double rating;
  const _ReviewsSection({required this.productId, required this.rating});

  @override
  ConsumerState<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<_ReviewsSection> {
  bool _showForm = false;
  double _myRating = 5;
  final _commentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(productReviewsProvider(widget.productId));

    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('⭐ Avis clients',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(width: 8),
            Text('${widget.rating.toStringAsFixed(1)}/5',
                style: const TextStyle(
                    color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: const Text('Donner mon avis'),
              onPressed: () => setState(() => _showForm = !_showForm),
            ),
          ]),

          // Formulaire avis
          if (_showForm) ...[
            const Divider(),
            const Text('Votre note :',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _myRating = i + 1.0),
                child: Icon(
                  i < _myRating ? Icons.star : Icons.star_border,
                  color: Colors.amber, size: 32,
                ),
              )),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Votre commentaire (optionnel)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _saving ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white),
              child: _saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Envoyer mon avis'),
            ),
            const Divider(),
          ],

          // Liste des avis
          reviewsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (reviews) {
              if (reviews.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucun avis pour l\'instant.',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              return Column(
                children: reviews.take(5).map((r) => _ReviewTile(review: r)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitReview() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/marketplace/reviews', data: {
        'productId': widget.productId,
        'shopId':    AppConfig.shopId,
        'orderId':   'TEMP', // sera validé côté backend
        'rating':    _myRating,
        'comment':   _commentCtrl.text.trim().isEmpty
            ? null : _commentCtrl.text.trim(),
      });
      ref.invalidate(productReviewsProvider(widget.productId));
      setState(() { _showForm = false; _commentCtrl.clear(); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Merci pour votre avis !'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ReviewTile extends StatelessWidget {
  final dynamic review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = double.tryParse('${review['rating']}') ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
              child: Text(
                (review['userName'] ?? review['user_name'] ?? '?')
                    .toString().substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Color(0xFF1976D2),
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review['userName'] ?? review['user_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Row(
                    children: [
                      ...List.generate(5, (i) => Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber, size: 14,
                      )),
                      const SizedBox(width: 4),
                      if (review['isVerified'] ?? review['is_verified'] ?? false)
                        const Text('✅ Achat vérifié',
                            style: TextStyle(fontSize: 10, color: Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
          ]),
          if (review['comment'] != null && review['comment'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 40),
              child: Text(review['comment'].toString(),
                  style: const TextStyle(fontSize: 13)),
            ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}
