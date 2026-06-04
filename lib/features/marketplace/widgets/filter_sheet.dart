import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/marketplace_providers.dart';

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const FilterSheet(),
      );

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late FilterState _local;

  @override
  void initState() {
    super.initState();
    _local = ref.read(filterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: maxH,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              const Text('Filtres & Tri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _local = const FilterState()),
                child: const Text('Réinitialiser',
                    style: TextStyle(color: Colors.red)),
              ),
            ]),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [

                // ── Tri ──────────────────────────────────────────────────
                const _SectionTitle('Trier par'),
                ...SortOption.values.map((opt) => RadioListTile<SortOption>(
                  value: opt,
                  groupValue: _local.sort,
                  onChanged: (v) => setState(() =>
                      _local = _local.copyWith(sort: v)),
                  title: Text(opt.label),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
                const Divider(height: 24),

                // ── Prix ─────────────────────────────────────────────────
                const _SectionTitle('Fourchette de prix'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _PriceField(
                    label: 'Min (FCFA)',
                    value: _local.minPrice,
                    onChanged: (v) => setState(() =>
                        _local = _local.copyWith(minPrice: v, clearMinPrice: v == null)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _PriceField(
                    label: 'Max (FCFA)',
                    value: _local.maxPrice,
                    onChanged: (v) => setState(() =>
                        _local = _local.copyWith(maxPrice: v, clearMaxPrice: v == null)),
                  )),
                ]),
                const Divider(height: 24),

                // ── Filtres rapides ───────────────────────────────────────
                const _SectionTitle('Filtres rapides'),
                SwitchListTile(
                  title: const Text('En stock uniquement'),
                  subtitle: const Text('Masquer les articles épuisés'),
                  value: _local.inStockOnly,
                  onChanged: (v) => setState(() =>
                      _local = _local.copyWith(inStockOnly: v)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                SwitchListTile(
                  title: const Text('Prix gros disponible'),
                  subtitle: const Text('Articles avec remise quantité'),
                  value: _local.wholesaleOnly,
                  onChanged: (v) => setState(() =>
                      _local = _local.copyWith(wholesaleOnly: v)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Bouton appliquer
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: ElevatedButton(
              onPressed: () {
                ref.read(filterProvider.notifier).state = _local;
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Appliquer les filtres',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
      );
}

class _PriceField extends StatefulWidget {
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  const _PriceField({required this.label, required this.value, required this.onChanged});

  @override
  State<_PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<_PriceField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: widget.label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          isDense: true,
        ),
        onChanged: (v) => widget.onChanged(double.tryParse(v)),
      );
}
