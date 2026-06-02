import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';

class RateArtisanScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String artisanName;
  const RateArtisanScreen({super.key, required this.requestId, required this.artisanName});

  @override
  ConsumerState<RateArtisanScreen> createState() => _RateArtisanScreenState();
}

class _RateArtisanScreenState extends ConsumerState<RateArtisanScreen> {
  double _quality      = 4;
  double _punctuality  = 4;
  double _cleanliness  = 4;
  double _overall      = 4;
  final _commentCtrl = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).post(
        '/artisans/requests/${widget.requestId}/rate',
        data: {
          'quality':     _quality,
          'punctuality': _punctuality,
          'cleanliness': _cleanliness,
          'overall':     _overall,
          if (_commentCtrl.text.trim().isNotEmpty) 'comment': _commentCtrl.text.trim(),
        },
      );
      setState(() { _submitted = true; _loading = false; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Évaluer l\'artisan'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 90, height: 90,
        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 50)),
    const SizedBox(height: 24),
    const Text('Merci pour votre évaluation !',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('Votre avis aide les autres clients à choisir le bon artisan.',
        style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
    const SizedBox(height: 32),
    ElevatedButton(
      onPressed: () => context.go('/artisans'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Retour'),
    ),
  ]));

  Widget _buildForm() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(Icons.handyman_outlined, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(
            'Évaluez le travail de ${widget.artisanName}',
            style: TextStyle(fontSize: 13, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
          )),
        ]),
      ),
      const SizedBox(height: 20),

      _Criterion(label: '🔨 Qualité du travail', value: _quality,
          onChanged: (v) => setState(() => _quality = v)),
      const SizedBox(height: 14),
      _Criterion(label: '⏰ Ponctualité', value: _punctuality,
          onChanged: (v) => setState(() => _punctuality = v)),
      const SizedBox(height: 14),
      _Criterion(label: '🧹 Propreté du chantier', value: _cleanliness,
          onChanged: (v) => setState(() => _cleanliness = v)),
      const SizedBox(height: 20),

      // Note globale
      Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const Text('Note globale', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_overall.toStringAsFixed(1),
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800,
                    color: Colors.orange.shade700)),
            const Text('/5', style: TextStyle(fontSize: 22, color: Colors.grey)),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _overall = (i + 1).toDouble()),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  i < _overall ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber, size: 36,
                )),
            )),
          ),
        ])),
      ),
      const SizedBox(height: 16),
      const Text('Commentaire (optionnel)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(height: 8),
      TextField(
        controller: _commentCtrl, maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Décrivez votre expérience avec cet artisan...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded),
          label: const Text('Envoyer l\'évaluation', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Center(child: TextButton(
        onPressed: () => context.go('/artisans'),
        child: const Text('Passer', style: TextStyle(color: Colors.grey)),
      )),
    ]),
  );
}

class _Criterion extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _Criterion({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = value >= 4 ? Colors.green : value >= 3 ? Colors.orange : Colors.red;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Text(value.toStringAsFixed(1),
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
        ]),
        Slider(
          value: value, min: 1, max: 5, divisions: 8,
          activeColor: Colors.orange.shade700,
          onChanged: onChanged,
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Insuffisant', style: TextStyle(fontSize: 10, color: Colors.grey)),
          const Text('Excellent', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ])),
    );
  }
}
