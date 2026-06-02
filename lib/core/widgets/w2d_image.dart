import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Widget image réseau avec cache disque automatique.
/// Utilise CachedNetworkImage → l'image est téléchargée une seule fois
/// et stockée sur le téléphone. Les chargements suivants sont instantanés
/// et ne consomment pas de data.
///
/// Usage:
///   W2dImage(url: product.photoUrls.first, width: 80, height: 80)
///   W2dImage.avatar(url: user.profilePhotoUrl, radius: 24)
///   W2dImage.banner(url: property.photoUrls.first)
///
class W2dImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  const W2dImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  /// Avatar circulaire (profil utilisateur / prestataire)
  factory W2dImage.avatar({
    Key? key,
    required String? url,
    double radius = 28,
  }) =>
      W2dImage(
        key: key,
        url: url,
        width: radius * 2,
        height: radius * 2,
        borderRadius: BorderRadius.circular(radius),
        placeholder: CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade200,
          child: Icon(Icons.person, size: radius, color: Colors.grey.shade400),
        ),
      );

  /// Image bannière pleine largeur (annonce, propriété)
  factory W2dImage.banner({
    Key? key,
    required String? url,
    double height = 180,
  }) =>
      W2dImage(
        key: key,
        url: url,
        height: height,
        fit: BoxFit.cover,
      );

  @override
  Widget build(BuildContext context) {
    final effectivePlaceholder = placeholder ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade100,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );

    final Widget image;

    if (url == null || url!.isEmpty) {
      image = effectivePlaceholder;
    } else {
      image = CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        // Garde l'image en cache disque 7 jours
        maxWidthDiskCache: 800,   // limite la résolution stockée → moins d'espace
        maxHeightDiskCache: 800,
        placeholder: (_, __) => effectivePlaceholder,
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.grey.shade400,
            size: 32,
          ),
        ),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
