import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/banner.dart';

class BannerCarousel extends ConsumerStatefulWidget {
  final List<MarketplaceBanner> banners;
  const BannerCarousel({super.key, required this.banners});

  @override
  ConsumerState<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends ConsumerState<BannerCarousel> {
  final _controller = PageController();
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final next = (_current + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoPlay() => _timer?.cancel();

  void _resumeAutoPlay() {
    _stopAutoPlay();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && widget.banners.length > 1) _startAutoPlay();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(children: [
        // Carrousel
        GestureDetector(
          onTapDown: (_) => _stopAutoPlay(),
          onTapUp: (_) => _resumeAutoPlay(),
          child: SizedBox(
            height: 140,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.banners.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (ctx, i) =>
                  _BannerItem(banner: widget.banners[i]),
            ),
          ),
        ),

        // Indicateurs de position
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _current ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _current
                      ? const Color(0xFF1976D2)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Item bannière ─────────────────────────────────────────────────────────────
class _BannerItem extends StatelessWidget {
  final MarketplaceBanner banner;
  const _BannerItem({required this.banner});

  bool get _hasAction =>
      banner.actionType != 'none' && banner.actionValue != null;

  String get _actionLabel {
    switch (banner.actionType) {
      case 'product':  return 'Voir le produit →';
      case 'category': return 'Voir la catégorie →';
      case 'url':      return 'En savoir plus →';
      default:         return 'Découvrir →';
    }
  }

  void _handleBannerTap(BuildContext context) {
    if (!_hasAction) return;
    switch (banner.actionType) {
      case 'product':
        context.push('/marketplace/products/${banner.actionValue}');
        break;
      case 'category':
        // Naviguer vers marketplace avec filtre catégorie
        context.go('/marketplace?category=${banner.actionValue}');
        break;
      case 'url':
        // Ouvrir un lien externe (url_launcher)
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleBannerTap(context),
      child: Container(
        decoration: BoxDecoration(
          gradient: banner.imageUrl == null
              ? LinearGradient(
                  colors: banner.type.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(14),
          image: banner.imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(banner.imageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.35),
                    BlendMode.darken,
                  ),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: banner.type.gradient.first.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${banner.type.emoji}  ${banner.title}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            if (banner.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                banner.subtitle!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
            if (_hasAction) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white54),
                ),
                child: Text(
                  _actionLabel,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
