import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/i18n/app_translations.dart';

// ─── Campagnes statiques (en attendant l'API) ─────────────────────────────────
const _campaigns = [
  _Campaign(
    id: 'w2d',
    title: 'Soutenir W2D',
    subtitle: 'Aidez-nous à améliorer la plateforme et à servir plus de Camerounais',
    emoji: '🚀',
    color: Color(0xFF1A237E),
    goal: 0, // pas d\'objectif affiché
    raised: 0,
    isW2D: true,
  ),
  _Campaign(
    id: 'education',
    title: 'Éducation pour tous',
    subtitle: 'Financer les fournitures scolaires dans les zones rurales',
    emoji: '📚',
    color: Color(0xFF4F46E5),
    goal: 500000,
    raised: 312000,
  ),
  _Campaign(
    id: 'sante',
    title: 'Santé communautaire',
    subtitle: 'Accès aux soins de base dans les quartiers défavorisés',
    emoji: '🏥',
    color: Color(0xFF10B981),
    goal: 1000000,
    raised: 670000,
  ),
  _Campaign(
    id: 'femmes',
    title: 'Autonomisation des femmes',
    subtitle: "Former les femmes aux métiers du numérique et de l'artisanat",
    emoji: '👩‍💼',
    color: Color(0xFFEC4899),
    goal: 750000,
    raised: 210000,
  ),
  _Campaign(
    id: 'eau',
    title: 'Eau potable',
    subtitle: 'Construction de puits dans les villages sans eau courante',
    emoji: '💧',
    color: Color(0xFF0288D1),
    goal: 2000000,
    raised: 890000,
  ),
];

const _amounts = [1000, 2500, 5000, 10000, 25000, 50000];

class _Campaign {
  final String id, title, subtitle, emoji;
  final Color color;
  final int goal, raised;
  final bool isW2D;
  const _Campaign({
    required this.id, required this.title, required this.subtitle,
    required this.emoji, required this.color,
    required this.goal, required this.raised,
    this.isW2D = false,
  });
  double get progress => goal == 0 ? 0 : (raised / goal).clamp(0.0, 1.0);
}

// ═════════════════════════════════════════════════════════════════════════════
class DonationScreen extends ConsumerStatefulWidget {
  const DonationScreen({super.key});

  @override
  ConsumerState<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<DonationScreen> {
  _Campaign? _selected;
  int? _amount;
  final _customCtrl = TextEditingController();
  bool _useCustom = false;
  bool _submitting = false;

  @override
  void dispose() { _customCtrl.dispose(); super.dispose(); }

  int? get _finalAmount {
    if (_useCustom) {
      return int.tryParse(_customCtrl.text.replaceAll(' ', ''));
    }
    return _amount;
  }

  Future<void> _donate() async {
    final campaign = _selected;
    final amount   = _finalAmount;
    if (campaign == null) {
      _showSnack(AppTranslations.of(context).t('choose_cause'), Colors.orange);
      return;
    }
    if (amount == null || amount < 500) {
      _showSnack(AppTranslations.of(context).t('min_donation'), Colors.orange);
      return;
    }
    setState(() => _submitting = true);
    try {
      final api    = ref.read(apiClientProvider);
      final userId = ref.read(authStateProvider).value?.user?['id'];
      await api.post('/donations', data: {
        'campaignId': campaign.id,
        'amount': amount,
        'userId': userId,
      });
      if (mounted) {
        _showSnack('🙏 Merci pour votre don de ${_fmt(amount)} FCFA !', Colors.green);
        setState(() { _selected = null; _amount = null; _useCustom = false; _customCtrl.clear(); });
      }
    } catch (_) {
      // Paiement Flutterwave pas encore intégré — afficher message informatif
      if (mounted) _showFlutterwaveModal();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showFlutterwaveModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('💳', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Paiement bientôt disponible',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'L\'intégration Flutterwave est en cours.\n'
            'En attendant, vous pouvez faire un don par :\n\n'
            '• MTN MoMo : 655 XX XX XX\n'
            '• Orange Money : 699 XX XX XX\n\n'
            'Référence : W2D-DON',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.6)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: 'W2D-DON'));
                Navigator.pop(context);
                _showSnack('Référence copiée !', Colors.green);
              },
              child: const Text('Copier la référence'),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(AppTranslations.of(context).t('donation_title')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('❤️ Ensemble, on va plus loin',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text('Vos dons soutiennent des projets concrets\nauprès des communautés camerounaises.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Choisir une cause ────────────────────────────────────────────
            Text('1. ${AppTranslations.of(context).t('choose_cause')}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...(_campaigns.map((c) => _CampaignCard(
              campaign: c,
              selected: _selected?.id == c.id,
              onTap: () => setState(() => _selected = c),
            ))),

            const SizedBox(height: 24),

            // ── Choisir un montant ───────────────────────────────────────────
            const Text('2. Choisissez un montant (FCFA)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: _amounts.map((a) => GestureDetector(
                onTap: () => setState(() { _amount = a; _useCustom = false; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: (!_useCustom && _amount == a)
                        ? const Color(0xFF1A237E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (!_useCustom && _amount == a)
                          ? const Color(0xFF1A237E) : Colors.grey.shade300),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Text(
                    '${_fmt(a)} F',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: (!_useCustom && _amount == a)
                          ? Colors.white : Colors.black87),
                  ),
                ),
              )).toList()
              ..add(GestureDetector(
                onTap: () => setState(() => _useCustom = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _useCustom ? const Color(0xFF1A237E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _useCustom ? const Color(0xFF1A237E) : Colors.grey.shade300),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Text('Autre',
                    style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13,
                      color: _useCustom ? Colors.white : Colors.black87)),
                ),
              )),
            ),
            if (_useCustom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Montant en FCFA (min. 500)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                  suffixText: 'FCFA',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],

            const SizedBox(height: 28),

            // ── Récapitulatif ────────────────────────────────────────────────
            if (_selected != null && _finalAmount != null && _finalAmount! >= 500)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    '${_selected!.emoji} ${_selected!.title} — ${_fmt(_finalAmount!)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  )),
                ]),
              ),
          ],
        ),
      ),

      // ── Bouton flottant ──────────────────────────────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _donate,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.favorite, size: 20),
            label: Text(
              _submitting ? 'Envoi...' : 'Faire un don',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Card campagne ────────────────────────────────────────────────────────────
class _CampaignCard extends StatelessWidget {
  final _Campaign campaign;
  final bool selected;
  final VoidCallback onTap;
  const _CampaignCard({required this.campaign, required this.selected, required this.onTap});

  String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  @override
  Widget build(BuildContext context) {
    if (campaign.isW2D) return _buildW2DCard();
    return _buildNormalCard();
  }

  // Carte spéciale W2D — gradient bleu avec étoiles
  Widget _buildW2DCard() {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? [const Color(0xFF1A237E), const Color(0xFF283593)]
                : [const Color(0xFF1A237E).withOpacity(0.85), const Color(0xFF3949AB)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.white.withOpacity(0.4) : Colors.transparent,
            width: 2),
          boxShadow: [BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.35),
            blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle),
            child: const Center(child: Text('🚀', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Soutenir W2D',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                    color: Colors.white)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8)),
                child: const Text('❤️ Notre mission',
                  style: TextStyle(fontSize: 9, color: Colors.white,
                      fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 4),
            const Text(
              'Aidez-nous à grandir et à mieux servir\nles Camerounais chaque jour',
              style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.4)),
          ])),
          if (selected)
            const Icon(Icons.check_circle, color: Colors.white, size: 22),
        ]),
      ),
    );
  }

  Widget _buildNormalCard() {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? campaign.color : Colors.grey.shade200,
            width: selected ? 2 : 1),
          boxShadow: [BoxShadow(
            color: selected
                ? campaign.color.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: campaign.color.withOpacity(0.1),
              shape: BoxShape.circle),
            child: Center(child: Text(campaign.emoji,
                style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(campaign.title,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                  color: selected ? campaign.color : Colors.black87)),
            const SizedBox(height: 2),
            Text(campaign.subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: campaign.progress,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(campaign.color),
              ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${_fmt(campaign.raised)} FCFA collectés',
                style: TextStyle(fontSize: 10, color: campaign.color,
                    fontWeight: FontWeight.w600)),
              Text('Objectif : ${_fmt(campaign.goal)} F',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ]),
          ])),
          if (selected)
            Icon(Icons.check_circle, color: campaign.color, size: 22),
        ]),
      ),
    );
  }
}
