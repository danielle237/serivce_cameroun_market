import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

// ── Favoris ───────────────────────────────────────────────────────────────────
final favoritesProvider = FutureProvider.autoDispose<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/favorites');
  final data = res.data;
  return data is List ? data : (data['data'] ?? []);
});

final isFavoriteProvider = FutureProvider.autoDispose.family<bool, String>((ref, productId) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/marketplace/favorites/$productId/check');
    return res.data['isFavorite'] as bool? ?? false;
  } catch (_) { return false; }
});

// ── Avis ──────────────────────────────────────────────────────────────────────
final productReviewsProvider = FutureProvider.autoDispose.family<List, String>((ref, productId) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/products/$productId/reviews');
  final data = res.data;
  return data is List ? data : (data['data'] ?? []);
});

// ── Historique prix ────────────────────────────────────────────────────────────
final priceHistoryProvider = FutureProvider.autoDispose.family<List, String>((ref, productId) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/marketplace/products/$productId/price-history');
  final data = res.data;
  return data is List ? data : (data['data'] ?? []);
});

// ── Fidélité ───────────────────────────────────────────────────────────────────
final loyaltyProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/marketplace/loyalty');
    return Map<String, dynamic>.from(res.data);
  } catch (_) { return {}; }
});

final loyaltyConfigProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/marketplace/loyalty/config');
    return Map<String, dynamic>.from(res.data);
  } catch (_) { return {}; }
});

// ── Préférences notifications ──────────────────────────────────────────────────
final notifPrefsProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/marketplace/notifications/prefs');
    return res.data != null ? Map<String, dynamic>.from(res.data) : null;
  } catch (_) { return null; }
});
