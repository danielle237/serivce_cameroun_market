import 'package:flutter/material.dart';

enum BannerType { promo, info, announcement, alert, newProduct }

extension BannerTypeExt on BannerType {
  String get label {
    switch (this) {
      case BannerType.promo:        return 'Promotion';
      case BannerType.info:         return 'Information';
      case BannerType.announcement: return 'Annonce';
      case BannerType.alert:        return 'Alerte';
      case BannerType.newProduct:   return 'Nouveauté';
    }
  }

  String get emoji {
    switch (this) {
      case BannerType.promo:        return '🔥';
      case BannerType.info:         return '📢';
      case BannerType.announcement: return '🎉';
      case BannerType.alert:        return '⚠️';
      case BannerType.newProduct:   return '🆕';
    }
  }

  List<Color> get gradient {
    switch (this) {
      case BannerType.promo:
        return [const Color(0xFFE53935), const Color(0xFFFF6F00)];
      case BannerType.info:
        return [const Color(0xFF1565C0), const Color(0xFF1976D2)];
      case BannerType.announcement:
        return [const Color(0xFF6A1B9A), const Color(0xFFE91E63)];
      case BannerType.alert:
        return [const Color(0xFFE65100), const Color(0xFFFDD835)];
      case BannerType.newProduct:
        return [const Color(0xFF1B5E20), const Color(0xFF00BCD4)];
    }
  }
}

class MarketplaceBanner {
  final String id;
  final String shopId;
  final BannerType type;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? linkProductId;
  final String? linkCategory;
  final int order;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  const MarketplaceBanner({
    required this.id,
    required this.shopId,
    required this.type,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.linkProductId,
    this.linkCategory,
    required this.order,
    this.isActive = true,
    this.startDate,
    this.endDate,
    required this.createdAt,
  });

  // ── Getters pour la navigation depuis le carousel ────────────────────────
  /// 'product' | 'category' | 'url' | 'none'
  String get actionType {
    if (linkProductId != null) return 'product';
    if (linkCategory != null)  return 'category';
    return 'none';
  }

  /// Valeur associée à l'action (productId, nom de catégorie, ou null)
  String? get actionValue {
    if (linkProductId != null) return linkProductId;
    if (linkCategory != null)  return linkCategory;
    return null;
  }

  bool get isCurrentlyActive {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  factory MarketplaceBanner.fromJson(Map<String, dynamic> j) =>
      MarketplaceBanner(
        id:              j['id'] as String,
        shopId:          j['shopId'] as String,
        type:            BannerType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => BannerType.info,
        ),
        title:           j['title'] as String,
        subtitle:        j['subtitle'] as String?,
        imageUrl:        j['imageUrl'] as String?,
        linkProductId:   j['linkProductId'] as String?,
        linkCategory:    j['linkCategory'] as String?,
        order:           j['order'] as int? ?? 0,
        isActive:        j['isActive'] as bool? ?? true,
        startDate:       j['startDate'] != null
            ? DateTime.parse(j['startDate']) : null,
        endDate:         j['endDate'] != null
            ? DateTime.parse(j['endDate']) : null,
        createdAt:       DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id':            id,
    'shopId':        shopId,
    'type':          type.name,
    'title':         title,
    'subtitle':      subtitle,
    'imageUrl':      imageUrl,
    'linkProductId': linkProductId,
    'linkCategory':  linkCategory,
    'order':         order,
    'isActive':      isActive,
    'startDate':     startDate?.toIso8601String(),
    'endDate':       endDate?.toIso8601String(),
    'createdAt':     createdAt.toIso8601String(),
  };
}
