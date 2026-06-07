import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/models/ad_campaign.dart';
import '../../../core/api/api_client.dart';

/// Interstitiel actif (affiché au lancement ou entre écrans)
final interstitialAdProvider = FutureProvider.autoDispose<AdCampaign?>((ref) async {
  final client = ref.read(apiClientProvider);
  try {
    final res = await client.get(
      '/ads/interstitial/active',
      cacheTtl: const Duration(minutes: 5),
    );
    if (res.data == null) return null;
    return AdCampaign.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return null; // jamais bloquer l'app pour une pub
  }
});

/// Bannières pub (carousel slots vendus)
final adBannersProvider = FutureProvider.autoDispose<List<AdCampaign>>((ref) async {
  final client = ref.read(apiClientProvider);
  try {
    final res = await client.get(
      '/ads/banners/active',
      cacheTtl: const Duration(minutes: 10),
    );
    final list = res.data as List<dynamic>? ?? [];
    return list.map((e) => AdCampaign.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});
