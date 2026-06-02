import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';

class RateClientScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String clientName;

  const RateClientScreen({
    super.key,
    required this.requestId,
    required this.clientName,
  });

  @override
  ConsumerState<RateClientScreen> createState() => _RateClientScreenState();
}

class _RateClientScreenState extends ConsumerState<RateClientScreen> {
  double _overall       = 0;
  double _seriousness   = 0;
  double _payment       = 0;
  double _communication = 0;
  final _commentCtrl    = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_overall == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Donnez au moins une note globale'),
          backgroundColor: Colors.orange));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).post(
        '/artisans/requests/${widget.requestId}/rate-client',
        data: {
          'overall':       _overall,
          'seriousness':   _seriousness > 0 ? _seriousness : _overall,
          'payment':       _payment > 0 ? _payment : _overall,
          'communication': _communication > 0 ? _communication : _overall,
          if (_commentCtrl.text.trim().isNotEmpty)
            'comment': _commentCtrl.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Évaluation envoyée — merci !'),
          backgroundColor: Colors.green,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Évaluer le client'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06), blurRadius: 8)],
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
                child: Text(
                  widget.clientName.isNotEmpty
                      ? widget.clientName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Évaluation du client',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(widget.clientName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ])),
            ]),
          ),
          const SizedBox(height: 20),

          // Note globale
          _RatingRow(
            label: '⭐ Note globale',
            sublabel: 'Votre satisfaction générale avec ce client',
            value: _overall,
            onChanged: (v) => setState(() => _overall = v),
            required: true,
          ),
          const SizedBox(height: 16),

          // Sérieux
          _RatingRow(
            label: '📋 Sérieux de la demande',
            sublabel: 'La description était-elle précise et fidèle ?',
            value: _seriousness,
            onChanged: (v) => setState(() => _seriousness = v),
          ),
          const SizedBox(height: 16),

          // Paiement
          _RatingRow(
            label: '💰 Respect du paiement',
            sublabel: 'Paiement dans les délais, pas de litige injustifié',
            value: _payment,
            onChanged: (v) => setState(() => _payment = v),
          ),
          const SizedBox(height: 16),

          // Communication
          _RatingRow(
            label: '💬 Communication',
            sublabel: 'Disponibilité et réactivité du client',
            value: _communication,
            onChanged: (v) => setState(() => _communication = v),
          ),
          const SizedBox(height: 20),

          // Commentaire
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Commentaire (optionnel)',
              hintText: 'Ce client était…',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.comment_outlined)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_loading ? 'Envoi…' : 'Soumettre l\'évaluation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label, sublabel;
  final double value;
  final ValueChanged<double> onChanged;
  final bool required;

  const _RatingRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          if (required) ...[
            const SizedBox(width: 4),
            const Text('*', style: TextStyle(color: Colors.red, fontSize: 14)),
          ],
        ]),
        const SizedBox(height: 2),
        Text(sublabel,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ...List.generate(5, (i) {
            final starVal = (i + 1).toDouble();
            return GestureDetector(
              onTap: () => onChanged(starVal),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  i < value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 36,
                  color: i < value ? Colors.amber : Colors.grey.shade300,
                ),
              ),
            );
          }),
        ]),
        if (value > 0)
          Center(
            child: Text(
              ['', '😞 Mauvais', '😐 Passable', '🙂 Bien', '😊 Très bien', '🌟 Excellent'][value.toInt()],
              style: TextStyle(
                color: value >= 4 ? Colors.green : value >= 3 ? Colors.orange : Colors.red,
                fontWeight: FontWeight.w600, fontSize: 13,
              ),
            ),
          ),
      ]),
    );
  }
}
