import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle de badges
// ─────────────────────────────────────────────────────────────────────────────
class BadgeCounts {
  final int artisans;
  final int education;
  final int messages;
  final int total;

  const BadgeCounts({
    this.artisans = 0,
    this.education = 0,
    this.messages = 0,
    this.total = 0,
  });

  factory BadgeCounts.fromJson(Map<String, dynamic> j) => BadgeCounts(
    artisans:  (j['artisans']  as num? ?? 0).toInt(),
    education: (j['education'] as num? ?? 0).toInt(),
    messages:  (j['messages']  as num? ?? 0).toInt(),
    total:     (j['total']     as num? ?? 0).toInt(),
  );

  static const empty = BadgeCounts();
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier qui poll toutes les 30s
// ─────────────────────────────────────────────────────────────────────────────
class BadgesNotifier extends AsyncNotifier<BadgeCounts> {
  Timer? _timer;

  @override
  Future<BadgeCounts> build() async {
    // Annuler le timer précédent si le notifier est recréé
    ref.onDispose(() => _timer?.cancel());
    // Poll toutes les 30s
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
    return _fetch();
  }

  Future<BadgeCounts> _fetch() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/dashboard/badges');
      final counts = BadgeCounts.fromJson(Map<String, dynamic>.from(res.data));
      state = AsyncData(counts);
      return counts;
    } catch (_) {
      return state.value ?? BadgeCounts.empty;
    }
  }

  /// Force un rafraîchissement immédiat (après action importante)
  Future<void> refresh() => _fetch().then((_) {});
}

final badgesProvider =
    AsyncNotifierProvider<BadgesNotifier, BadgeCounts>(BadgesNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// Activité récente dynamique
// ─────────────────────────────────────────────────────────────────────────────
final recentActivityProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/dashboard/activity');
    final data = res.data;
    return List<Map<String, dynamic>>.from(
      (data is List ? data : []).map((e) => Map<String, dynamic>.from(e)));
  } catch (_) {
    return [];
  }
});
