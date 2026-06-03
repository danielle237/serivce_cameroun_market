// ═══════════════════════════════════════════════════════════════════════════
// Configuration centrale W2D
//
// Variables injectées au build via --dart-define :
//
//   Mode multi-boutiques :
//     flutter run  --dart-define=MULTI_BOUTIQUE=true
//     flutter build apk --dart-define=MULTI_BOUTIQUE=true
//
//   Mode mono-boutique (défaut) :
//     flutter run  --dart-define=MULTI_BOUTIQUE=false --dart-define=SHOP_ID=9c71d236-...
//     flutter build apk --dart-define=MULTI_BOUTIQUE=false --dart-define=SHOP_ID=9c71d236-...
//
// ═══════════════════════════════════════════════════════════════════════════

class AppConfig {
  // ── Multi-boutiques ────────────────────────────────────────────────────────
  // Si true  → le shopId vient du JWT de l'utilisateur connecté
  // Si false → on utilise SHOP_ID ci-dessous (une seule boutique)
  static const bool multiBoutique =
      bool.fromEnvironment('MULTI_BOUTIQUE', defaultValue: false);

  // ── Boutique par défaut (mode mono) ───────────────────────────────────────
  static const String _defaultShopId =
      String.fromEnvironment('SHOP_ID',
          defaultValue: '9c71d236-66cd-4133-af37-9b809ca77757');

  static const String _defaultShopName =
      String.fromEnvironment('SHOP_NAME', defaultValue: 'Tchokos');

  // shopId : utilisé en mono-boutique uniquement
  // En multi-boutique, utilise AppConfig.shopIdFor(user)
  static String get shopId => _defaultShopId;
  static String get shopName => _defaultShopName;

  // ── API ────────────────────────────────────────────────────────────────────
  static const String baseUrl =
      String.fromEnvironment('API_URL',
          defaultValue: 'http://51.83.40.138:3005/api/v1');

  static const String wsBaseUrl =
      String.fromEnvironment('WS_URL',
          defaultValue: 'http://51.83.40.138:3005');

  // ── Helper multi-boutique ──────────────────────────────────────────────────
  // Retourne le shopId selon le mode actif
  // user = Map du JWT (authStateProvider)
  static String shopIdFor(Map<String, dynamic>? user) {
    if (!multiBoutique) return _defaultShopId;
    // En multi : le vendeur a son shopId dans le JWT
    final fromJwt = user?['shopId'] as String?;
    return fromJwt ?? _defaultShopId; // fallback boutique par défaut
  }

  // ── TikTok ─────────────────────────────────────────────────────────────────
  static String shopLink(String shopId, {String? productSlug}) =>
      productSlug != null
          ? 'https://w2d.cm/shop/$shopId/$productSlug'
          : 'https://w2d.cm/shop/$shopId';
}
