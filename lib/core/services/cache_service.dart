import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Service de cache local Hive pour limiter la consommation data
/// sur les réseaux MTN/Orange Cameroun (3G instable).
///
/// Usage:
///   await CacheService.init();                          // dans main()
///   await CacheService.set('providers', data, ttl: Duration(minutes: 30));
///   final cached = CacheService.get<List>('providers');
///
class CacheService {
  static const _boxName = 'w2d_cache';
  static const _metaBoxName = 'w2d_cache_meta'; // TTL timestamps

  static late Box _box;
  static late Box<int> _meta;

  /// Initialiser Hive — appeler une seule fois dans main() avant runApp()
  static Future<void> init() async {
    await Hive.initFlutter();
    _box  = await Hive.openBox(_boxName);
    _meta = await Hive.openBox<int>(_metaBoxName);
  }

  // ── Durées de cache par défaut ──────────────────────────────────────────────
  static const Duration kShort  = Duration(minutes: 5);   // données volatiles
  static const Duration kMedium = Duration(minutes: 30);  // listes produits/properties
  static const Duration kLong   = Duration(hours: 6);     // profils, catégories
  static const Duration kDay    = Duration(hours: 24);    // config statique

  /// Stocker une valeur avec TTL (durée de vie)
  static Future<void> set(String key, dynamic value, {Duration ttl = kMedium}) async {
    final expiry = DateTime.now().add(ttl).millisecondsSinceEpoch;
    await _box.put(key, jsonEncode(value));
    await _meta.put(key, expiry);
  }

  /// Récupérer une valeur (retourne null si absente ou expirée)
  static T? get<T>(String key) {
    final expiry = _meta.get(key);
    if (expiry == null) return null;
    if (DateTime.now().millisecondsSinceEpoch > expiry) {
      // Expiré → retourner null SANS supprimer (reste disponible pour getStale)
      return null;
    }
    return _decode<T>(key);
  }

  /// Récupérer une valeur MÊME expirée (mode hors-ligne)
  static T? getStale<T>(String key) => _decode<T>(key);

  /// Décodage JSON sécurisé — retourne null en cas d'erreur de cast ou de format
  static T? _decode<T>(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is T) return decoded;
      // Tentative de cast souple (ex: List<dynamic> → List)
      return decoded as T;
    } catch (_) {
      // Données corrompues ou type inattendu — on supprime pour éviter la boucle
      _box.delete(key);
      _meta.delete(key);
      return null;
    }
  }

  /// Invalider une clé spécifique (ex: après un POST/PATCH)
  static Future<void> invalidate(String key) async {
    await _box.delete(key);
    await _meta.delete(key);
  }

  /// Invalider toutes les clés qui commencent par un préfixe
  /// Ex: CacheService.invalidatePrefix('products') efface products_food, products_electronics…
  static Future<void> invalidatePrefix(String prefix) async {
    final keys = _box.keys.where((k) => k.toString().startsWith(prefix)).toList();
    for (final k in keys) {
      await _box.delete(k);
      await _meta.delete(k);
    }
  }

  /// Vider tout le cache (utile à la déconnexion)
  static Future<void> clear() async {
    await _box.clear();
    await _meta.clear();
  }

  // ── Clés prédéfinies (évite les fautes de frappe) ──────────────────────────
  static const String keyCategories      = 'categories';
  static const String keyNearbyDrivers   = 'nearby_drivers';
  static const String keyMyContracts     = 'my_contracts';
  static const String keyMyOrders        = 'my_orders';
  static const String keyMyRides         = 'my_rides';
  static const String keyWallet          = 'wallet';
  static const String keyProviderProfile = 'provider_profile';

  static String keyProducts(String? category) =>
      category == null ? 'products_all' : 'products_$category';

  static String keyProperties({
    String? city, String? type, String? transaction,
  }) => 'properties_${city ?? ''}_${type ?? ''}_${transaction ?? ''}';

  // ── Helpers pour les pages list + pagination ───────────────────────────────
  /// Stocke une page de résultats
  static Future<void> setPage(
    String baseKey, int page, Map<String, dynamic> payload, {
    Duration ttl = kMedium,
  }) => set('${baseKey}_p$page', payload, ttl: ttl);

  /// Récupère une page de résultats
  static Map<String, dynamic>? getPage(String baseKey, int page) =>
      get<Map<String, dynamic>>('${baseKey}_p$page');
}
