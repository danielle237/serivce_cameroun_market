import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';

class RateSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final Map<String, dynamic>? sessionData;

  const RateSessionScreen({
    super.key,
    required this.sessionId,
    this.sessionData,
  });

  @override
  ConsumerState<RateSessionScreen> createState() => _RateSessionScreenState();
}

class _RateSessionScreenState extends ConsumerState<RateSessionScreen> {
  double _punctuality   = 4;
  double _pedagogy      = 4;
  double _communication = 4;
  double _overall       = 4;
  final _commentCtrl = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  bool get _isTeacher =>
      ref.read(authStateProvider).value?.user?['activeMode'] == 'provider';

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/education/sessions/${widget.sessionId}/rate', data: {
        'punctuality':   _punctuality,
        'pedagogy':      _pedagogy,
        'communication': _communication,
        'overall':       _overall,
        if (_commentCtrl.text.trim().isNotEmpty)
          'comment': _commentCtrl.text.trim(),
      });
      setState(() { _submitted = true; _loading = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Évaluation de la séance'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 90, height: 90,
        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 50),
      ),
      const SizedBox(height: 24),
      const Text('Merci pour votre évaluation !',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
        _isTeacher
            ? 'Votre retour aide à améliorer la qualité des cours.'
            : 'Votre avis aide les autres familles à choisir.',
        style: const TextStyle(color: Colors.grey, fontSize: 13),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      ElevatedButton(
        onPressed: () => context.pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Retour aux séances'),
      ),
    ]));
  }

  Widget _buildForm() {
    final isTeacher = _isTeacher;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Bandeau contexte
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.stars_rounded, color: Color(0xFF1976D2), size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(
              isTeacher
                  ? 'Évaluez l\'implication et le sérieux de l\'élève.'
                  : 'Évaluez la qualité du cours dispensé par l\'enseignant.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF1976D2)),
            )),
          ]),
        ),
        const SizedBox(height: 24),

        // Critères de notation
        _RatingCriterion(
          label: isTeacher ? 'Ponctualité de l\'élève' : 'Ponctualité',
          icon: Icons.access_time_rounded,
          value: _punctuality,
          onChanged: (v) => setState(() => _punctuality = v),
        ),
        const SizedBox(height: 16),
        _RatingCriterion(
          label: isTeacher ? 'Sérieux & implication' : 'Qualité pédagogique',
          icon: isTeacher ? Icons.school_outlined : Icons.menu_book_outlined,
          value: _pedagogy,
          onChanged: (v) => setState(() => _pedagogy = v),
        ),
        const SizedBox(height: 16),
        _RatingCriterion(
          label: 'Communication',
          icon: Icons.chat_bubble_outline,
          value: _communication,
          onChanged: (v) => setState(() => _communication = v),
        ),
        const SizedBox(height: 24),

        // Note globale — plus grande
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('Note globale',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  _overall.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const Text(' /5', style: TextStyle(fontSize: 22, color: Colors.grey)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.center, children:
                List.generate(5, (i) => GestureDetector(
                  onTap: () => setState(() => _overall = (i + 1).toDouble()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _overall ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 36,
                    ),
                  ),
                )),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Commentaire
        const Text('Commentaire (optionnel)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: isTeacher
                ? 'Points forts, axes d\'amélioration de l\'élève...'
                : 'Votre expérience avec cet enseignant...',
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
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: const Text('Passer pour l\'instant',
                style: TextStyle(color: Colors.grey)),
          ),
        ),
      ]),
    );
  }
}

class _RatingCriterion extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const _RatingCriterion({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = value >= 4 ? Colors.green : value >= 3 ? Colors.orange : Colors.red;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: const Color(0xFF1976D2)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value.toStringAsFixed(1),
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF1976D2),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: const Color(0xFF1976D2),
              overlayColor: const Color(0xFF1976D2).withOpacity(0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: 1,
              max: 5,
              divisions: 8,
              onChanged: onChanged,
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Insuffisant', style: TextStyle(fontSize: 10, color: Colors.grey)),
            const Text('Excellent', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ]),
      ),
    );
  }
}
