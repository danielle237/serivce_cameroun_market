import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_translations.dart';

class MotoScreen extends ConsumerStatefulWidget {
  const MotoScreen({super.key});

  @override
  ConsumerState<MotoScreen> createState() => _MotoScreenState();
}

class _MotoScreenState extends ConsumerState<MotoScreen> {
  final _pickupCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  String _type = 'transport_personne';
  double _distance = 2.0;
  bool _loading = false;
  int? _estimatedPrice;

  void _estimate() {
    final priceMap = {'transport_personne': 150, 'livraison_colis': 200, 'courses': 180, 'livraison_repas': 200};
    final rate = priceMap[_type] ?? 150;
    setState(() => _estimatedPrice = (300 + _distance * rate).round());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('moto_delivery'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Type de service
          Text(t.t('service_type'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _TypeChip(label: t.t('transport_chip'), value: 'transport_personne', selected: _type == 'transport_personne', onTap: () => setState(() { _type = 'transport_personne'; _estimate(); })),
              _TypeChip(label: t.t('parcel_chip'), value: 'livraison_colis', selected: _type == 'livraison_colis', onTap: () => setState(() { _type = 'livraison_colis'; _estimate(); })),
              _TypeChip(label: t.t('shopping_chip'), value: 'courses', selected: _type == 'courses', onTap: () => setState(() { _type = 'courses'; _estimate(); })),
              _TypeChip(label: t.t('food_chip'), value: 'livraison_repas', selected: _type == 'livraison_repas', onTap: () => setState(() { _type = 'livraison_repas'; _estimate(); })),
            ]),
          ),
          const SizedBox(height: 20),

          // Trajet
          TextFormField(controller: _pickupCtrl, decoration: InputDecoration(labelText: t.t('pickup_point'), prefixIcon: const Icon(Icons.my_location, color: AppColors.primary))),
          const SizedBox(height: 8),
          Container(height: 24, width: 2, margin: const EdgeInsets.only(left: 24), color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 8),
          TextFormField(controller: _dropoffCtrl, decoration: InputDecoration(labelText: t.t('destination'), prefixIcon: const Icon(Icons.location_on, color: AppColors.error))),

          const SizedBox(height: 20),

          // Distance slider (estimée)
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t.t('estimated_distance'), style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${_distance.toStringAsFixed(1)} km', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ]),
          Slider(value: _distance, min: 0.5, max: 20, divisions: 39, onChanged: (v) { setState(() => _distance = v); _estimate(); }),

          const SizedBox(height: 20),

          // Estimation prix
          if (_estimatedPrice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t.t('estimated_price'), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('$_estimatedPrice XAF', style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
            ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _loading ? null : _requestRide,
            icon: const Icon(Icons.motorcycle),
            label: Text(t.t('find_driver')),
          ),
        ]),
      ),
    );
  }

  Future<void> _requestRide() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/moto/rides', data: {
        'type': _type, 'pickupAddress': _pickupCtrl.text, 'dropoffAddress': _dropoffCtrl.text,
        'pickupLat': 4.05, 'pickupLng': 9.75, 'dropoffLat': 4.06, 'dropoffLng': 9.76,
        'distanceKm': _distance,
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.of(context).t('request_sent_driver')), backgroundColor: AppColors.success));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _TypeChip extends StatelessWidget {
  final String label, value;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}
