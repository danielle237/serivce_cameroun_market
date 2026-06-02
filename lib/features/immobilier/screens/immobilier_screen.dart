import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

final propertiesProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, Map<String, dynamic>>((ref, filters) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/immobilier', params: filters);
  return Map<String, dynamic>.from(res.data);
});

class ImmobilierScreen extends ConsumerStatefulWidget {
  const ImmobilierScreen({super.key});

  @override
  ConsumerState<ImmobilierScreen> createState() => _ImmobilierScreenState();
}

class _ImmobilierScreenState extends ConsumerState<ImmobilierScreen> {
  String _type = 'all';
  String _city = 'Douala';

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(propertiesProvider({'city': _city, 'type': _type == 'all' ? null : _type}));

    return Scaffold(
      appBar: AppBar(title: const Text('Immobilier')),
      body: Column(children: [
        // Filtres
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: DropdownButton<String>(
              value: _city,
              isExpanded: true,
              items: ['Douala', 'Yaoundé', 'Bafoussam'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _city = v!),
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButton<String>(
              value: _type,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('Tous types')),
                const DropdownMenuItem(value: 'studio', child: Text('Studio')),
                const DropdownMenuItem(value: 'appartement', child: Text('Appartement')),
                const DropdownMenuItem(value: 'villa', child: Text('Villa')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            )),
          ]),
        ),
        Expanded(
          child: propertiesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (data) {
              final properties = (data['data'] as List?) ?? [];
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: properties.length,
                itemBuilder: (_, i) => _PropertyCard(property: properties[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final dynamic property;
  const _PropertyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    final photos = (property['photoUrls'] as List?) ?? (property['photos'] as List?) ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (photos.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(photos[0], height: 180, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 180, color: Colors.grey.shade200, child: const Icon(Icons.home, size: 48, color: Colors.grey))),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(property['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text('${property['district'] ?? property['quarter'] ?? ''}, ${property['city'] ?? ''}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              Text('${property['price']} XAF/mois', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              if (property['rooms'] != null) _Tag(text: '${property['rooms']} pièces'),
              const SizedBox(width: 6),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (property['has_water'] == true) _IconTag(icon: '💧', text: 'Eau'),
              if (property['has_electricity'] == true) _IconTag(icon: '⚡', text: 'Électricité'),
              if (property['has_wifi'] == true) _IconTag(icon: '📶', text: 'Wifi'),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
  );
}

class _IconTag extends StatelessWidget {
  final String icon, text;
  const _IconTag({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Text('$icon $text', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
  );
}
