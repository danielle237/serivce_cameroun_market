import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

// ── Spécialités avec icône + couleur ─────────────────────────────────────────
class _Specialty {
  final String value, label, emoji;
  final Color color;
  const _Specialty(this.value, this.label, this.emoji, this.color);
}

const _specialties = [
  _Specialty('electricien',   'Électricien',   '⚡', Color(0xFFF59E0B)),
  _Specialty('plombier',      'Plombier',      '🔧', Color(0xFF3B82F6)),
  _Specialty('macon',         'Maçon',         '🧱', Color(0xFF8B5CF6)),
  _Specialty('mecanicien',    'Mécanicien',    '🚗', Color(0xFFEF4444)),
  _Specialty('climatisation', 'Climaticien',   '❄️', Color(0xFF06B6D4)),
  _Specialty('peintre',       'Peintre',       '🎨', Color(0xFFEC4899)),
  _Specialty('menuisier',     'Menuisier',     '🪚', Color(0xFF84CC16)),
  _Specialty('soudeur',       'Soudeur',       '🔥', Color(0xFFF97316)),
  _Specialty('carreleur',     'Carreleur',     '🏠', Color(0xFF6366F1)),
  _Specialty('autre',         'Autre',         '🛠️', Color(0xFF6B7280)),
];

// ── Budgets prédéfinis ────────────────────────────────────────────────────────
const _budgetPresets = [
  {'label': '< 20 000', 'min': 0,      'max': 20000},
  {'label': '20–50K',   'min': 20000,  'max': 50000},
  {'label': '50–150K',  'min': 50000,  'max': 150000},
  {'label': '150–500K', 'min': 150000, 'max': 500000},
  {'label': '> 500K',   'min': 500000, 'max': 2000000},
];

class ArtisanRequestScreen extends ConsumerStatefulWidget {
  const ArtisanRequestScreen({super.key});

  @override
  ConsumerState<ArtisanRequestScreen> createState() => _ArtisanRequestScreenState();
}

class _ArtisanRequestScreenState extends ConsumerState<ArtisanRequestScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Spécialité
  String _specialty = 'electricien';

  // Budget
  int _budgetPresetIndex = 1; // 20–50K par défaut
  final _budgetMinCtrl = TextEditingController(text: '20000');
  final _budgetMaxCtrl = TextEditingController(text: '50000');
  bool _budgetCustom = false;

  // Urgence
  String _urgency = 'normal';

  // Date préférée
  DateTime? _preferredDate;

  // Localisation
  double? _lat, _lng;
  bool _locLoading = false;

  // Soumission
  bool _loading = false;
  int _currentStep = 0; // 0=service, 1=détails, 2=budget

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose();
    _addressCtrl.dispose(); _budgetMinCtrl.dispose(); _budgetMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _locLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        setState(() { _lat = pos.latitude; _lng = pos.longitude; });
        _snack('📍 Localisation obtenue', Colors.green);
      }
    } catch (_) {
      _snack('Impossible d\'obtenir la localisation', Colors.orange);
    }
    setState(() => _locLoading = false);
  }

  void _selectBudgetPreset(int index) {
    setState(() {
      _budgetPresetIndex = index;
      _budgetCustom = false;
      final preset = _budgetPresets[index];
      _budgetMinCtrl.text = '${preset['min']}';
      _budgetMaxCtrl.text = '${preset['max']}';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_addressCtrl.text.trim().isEmpty) {
      _snack('Indiquez l\'adresse des travaux', Colors.orange);
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/artisans/requests', data: {
        'specialty':      _specialty,
        'title':          _titleCtrl.text.trim(),
        'description':    _descCtrl.text.trim(),
        'locationAddress': _addressCtrl.text.trim(),
        if (_lat != null) 'locationLat': _lat,
        if (_lng != null) 'locationLng': _lng,
        'urgency':        _urgency,
        'budgetMin':      int.tryParse(_budgetMinCtrl.text),
        'budgetMax':      int.tryParse(_budgetMaxCtrl.text),
        if (_preferredDate != null)
          'preferredDate': DateFormat('yyyy-MM-dd').format(_preferredDate!),
      });
      if (mounted) {
        _snack('✅ Demande publiée ! Les artisans vont vous contacter.', Colors.green);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/artisans');
      }
    } catch (e) {
      _snack('Erreur: $e', Colors.red);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color,
          duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Nouvelle demande artisan'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Column(children: [
          // ── Indicateur de progression ──────────────────────────────────
          _StepIndicator(currentStep: _currentStep),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ═══ ÉTAPE 1 : TYPE DE SERVICE ════════════════════════════
                _SectionCard(
                  step: 1,
                  title: 'Quel service cherchez-vous ?',
                  icon: Icons.handyman_outlined,
                  isActive: _currentStep == 0,
                  onTap: () => setState(() => _currentStep = 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10, mainAxisSpacing: 10,
                      childAspectRatio: 1.1,
                      children: _specialties.map((s) => _SpecialtyCard(
                        specialty: s,
                        selected: _specialty == s.value,
                        onTap: () => setState(() {
                          _specialty = s.value;
                          _currentStep = 1;
                        }),
                      )).toList(),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // ═══ ÉTAPE 2 : DESCRIPTION & LOCALISATION ════════════════
                _SectionCard(
                  step: 2,
                  title: 'Décrivez votre besoin',
                  icon: Icons.description_outlined,
                  isActive: _currentStep == 1,
                  onTap: () => setState(() => _currentStep = 1),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // Titre
                    _fieldLabel('Titre court *'),
                    TextFormField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _dec(
                        hint: _titleHint(),
                        icon: Icons.title_outlined,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Décrivez brièvement votre besoin' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    _fieldLabel('Description détaillée'),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _dec(
                        hint: _descHint(),
                        icon: Icons.notes_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Adresse
                    _fieldLabel('Adresse des travaux *'),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _addressCtrl,
                          decoration: _dec(
                            hint: 'Quartier, rue, ville...',
                            icon: Icons.location_on_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _locLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: Icon(
                                _lat != null ? Icons.location_on : Icons.my_location,
                                color: _lat != null ? Colors.green : AppColors.primary,
                                size: 26,
                              ),
                              tooltip: 'Localisation GPS',
                              onPressed: _getLocation,
                            ),
                    ]),
                    if (_lat != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 14),
                          const SizedBox(width: 4),
                          Text('Position GPS enregistrée',
                              style: const TextStyle(fontSize: 11, color: Colors.green,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    const SizedBox(height: 14),

                    // Date préférée
                    _fieldLabel('Date souhaitée (optionnel)'),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 60)),
                        );
                        if (d != null) setState(() => _preferredDate = d);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today_outlined,
                              color: _preferredDate != null ? AppColors.primary : Colors.grey,
                              size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _preferredDate != null
                                ? DateFormat('EEEE dd MMMM yyyy', 'fr').format(_preferredDate!)
                                : 'Choisir une date',
                            style: TextStyle(
                              fontSize: 14,
                              color: _preferredDate != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          if (_preferredDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _preferredDate = null),
                              child: const Icon(Icons.close, size: 18, color: Colors.grey),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Urgence
                    _fieldLabel('Niveau d\'urgence'),
                    Row(children: [
                      Expanded(child: _UrgenceCard(
                        value: 'normal',
                        selected: _urgency == 'normal',
                        label: 'Normal',
                        subtitle: 'Sous 48h–72h',
                        icon: Icons.schedule_outlined,
                        color: Colors.blue,
                        onTap: () => setState(() { _urgency = 'normal'; _currentStep = 2; }),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _UrgenceCard(
                        value: 'urgent',
                        selected: _urgency == 'urgent',
                        label: 'Urgent',
                        subtitle: 'Aujourd\'hui',
                        icon: Icons.flash_on_rounded,
                        color: Colors.red,
                        onTap: () => setState(() { _urgency = 'urgent'; _currentStep = 2; }),
                      )),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),

                // ═══ ÉTAPE 3 : BUDGET ═════════════════════════════════════
                _SectionCard(
                  step: 3,
                  title: 'Votre budget',
                  icon: Icons.account_balance_wallet_outlined,
                  isActive: _currentStep == 2,
                  onTap: () => setState(() => _currentStep = 2),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        SizedBox(width: 6),
                        Expanded(child: Text(
                          'Indiquer votre budget permet aux artisans de vous envoyer des devis adaptés. '
                          'Vous n\'êtes pas obligé d\'accepter le premier devis reçu.',
                          style: TextStyle(fontSize: 11, color: Colors.blue),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Presets budget
                    _fieldLabel('Fourchette de budget'),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: List.generate(_budgetPresets.length, (i) {
                        final preset = _budgetPresets[i];
                        final sel = !_budgetCustom && _budgetPresetIndex == i;
                        return GestureDetector(
                          onTap: () => _selectBudgetPreset(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel ? AppColors.primary : Colors.grey.shade300,
                                width: sel ? 2 : 1,
                              ),
                              boxShadow: sel ? [BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 6,
                              )] : null,
                            ),
                            child: Text(
                              preset['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                                color: sel ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Budget personnalisé
                    GestureDetector(
                      onTap: () => setState(() => _budgetCustom = !_budgetCustom),
                      child: Row(children: [
                        Icon(
                          _budgetCustom ? Icons.check_box : Icons.check_box_outline_blank,
                          color: AppColors.primary, size: 20,
                        ),
                        const SizedBox(width: 6),
                        const Text('Saisir un budget personnalisé',
                            style: TextStyle(fontSize: 13, color: AppColors.primary)),
                      ]),
                    ),
                    if (_budgetCustom) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: TextFormField(
                          controller: _budgetMinCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _dec(hint: 'Min (XAF)', icon: Icons.south_outlined),
                        )),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('–', style: TextStyle(fontSize: 20, color: Colors.grey)),
                        ),
                        Expanded(child: TextFormField(
                          controller: _budgetMaxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _dec(hint: 'Max (XAF)', icon: Icons.north_outlined),
                        )),
                      ]),
                    ] else ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${_fmt(int.parse(_budgetMinCtrl.text.isEmpty ? '0' : _budgetMinCtrl.text))} — '
                          '${_fmt(int.parse(_budgetMaxCtrl.text.isEmpty ? '0' : _budgetMaxCtrl.text))} FCFA',
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary,
                          ),
                        ),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Récap avant envoi ────────────────────────────────────
                if (_titleCtrl.text.isNotEmpty) _buildRecap(),
                const SizedBox(height: 24),

                // ── Bouton soumettre ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: const Text('Publier ma demande', style: TextStyle(fontSize: 17)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _urgency == 'urgent' ? Colors.red : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Les artisans de votre zone seront notifiés par SMS',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRecap() {
    final specialty = _specialties.firstWhere((s) => s.value == _specialty);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
          SizedBox(width: 6),
          Text('Récapitulatif de votre demande',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        _recapRow(specialty.emoji, specialty.label),
        if (_titleCtrl.text.isNotEmpty) _recapRow('📝', _titleCtrl.text),
        if (_addressCtrl.text.isNotEmpty) _recapRow('📍', _addressCtrl.text),
        _recapRow(
          '💰',
          '${_fmt(int.tryParse(_budgetMinCtrl.text) ?? 0)} — ${_fmt(int.tryParse(_budgetMaxCtrl.text) ?? 0)} FCFA',
        ),
        _recapRow(
          _urgency == 'urgent' ? '🔴' : '🟢',
          _urgency == 'urgent' ? 'Urgence — aujourd\'hui' : 'Normal — sous 48–72h',
        ),
        if (_preferredDate != null)
          _recapRow('📅', DateFormat('dd MMMM yyyy', 'fr').format(_preferredDate!)),
      ]),
    );
  }

  Widget _recapRow(String emoji, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87))),
    ]),
  );

  String _titleHint() => {
    'electricien':   'Ex: Installation prise électrique dans le salon',
    'plombier':      'Ex: Fuite d\'eau sous l\'évier cuisine',
    'macon':         'Ex: Rénovation mur fissuré chambre principale',
    'mecanicien':    'Ex: Panne moteur Toyota Corolla 2018',
    'climatisation': 'Ex: Installation climatiseur 1CV chambre',
    'peintre':       'Ex: Peinture intérieure appartement 3 pièces',
    'menuisier':     'Ex: Fabrication porte en bois sur mesure',
    'soudeur':       'Ex: Grille de fenêtre en fer forgé',
  }[_specialty] ?? 'Décrivez brièvement votre besoin';

  String _descHint() => {
    'electricien':   'Surface, nombre de prises, type d\'installation, problème rencontré...',
    'plombier':      'Localisation de la fuite, ancienneté, matériaux (PVC, acier)...',
    'macon':         'Dimensions, matériaux souhaités, nature des travaux...',
    'mecanicien':    'Symptômes, kilométrage, date du dernier entretien...',
    'climatisation': 'Surface de la pièce, marque souhaitée, installation neuve ou remplacement...',
    'peintre':       'Nombre de pièces, état actuel des murs, type de peinture...',
    'menuisier':     'Dimensions, type de bois, finitions souhaitées...',
    'soudeur':       'Dimensions, type de métal, modèle ou croquis disponible...',
  }[_specialty] ?? 'Donnez un maximum de détails pour recevoir des devis précis...';

  InputDecoration _dec({required String hint, required IconData icon}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
    prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true,
    fillColor: Colors.white,
  );

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: const TextStyle(
        fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
  );

  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ── Indicateur d'étapes ───────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(children: List.generate(3, (i) {
        final done = i < currentStep;
        final active = i == currentStep;
        final labels = ['Service', 'Détails', 'Budget'];
        final color = done || active ? AppColors.primary : Colors.grey.shade300;
        return Expanded(child: Row(children: [
          Column(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: done ? AppColors.primary : active ? Colors.white : Colors.grey.shade100,
                border: Border.all(color: color, width: 2),
                shape: BoxShape.circle,
              ),
              child: Center(child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text('${i + 1}', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: active ? AppColors.primary : Colors.grey))),
            ),
            const SizedBox(height: 2),
            Text(labels[i], style: TextStyle(
                fontSize: 10,
                color: active ? AppColors.primary : done ? AppColors.primary : Colors.grey,
                fontWeight: active || done ? FontWeight.w600 : FontWeight.normal)),
          ]),
          if (i < 2)
            Expanded(child: Container(
              height: 2, margin: const EdgeInsets.only(bottom: 16),
              color: done ? AppColors.primary : Colors.grey.shade200,
            )),
        ]));
      })),
    );
  }
}

// ── Section card pliable ──────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final int step;
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Widget child;

  const _SectionCard({
    required this.step, required this.title, required this.icon,
    required this.isActive, required this.onTap, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isActive ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isActive
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: Column(children: [
        // En-tête de section
        InkWell(
          onTap: onTap,
          borderRadius: isActive
              ? const BorderRadius.vertical(top: Radius.circular(14))
              : BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 20, color: isActive ? Colors.white : Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15,
                color: isActive ? AppColors.primary : Colors.black87,
              ))),
              Icon(isActive ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey),
            ]),
          ),
        ),
        // Contenu
        if (isActive) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: child,
          ),
        ],
      ]),
    );
  }
}

// ── Card spécialité ───────────────────────────────────────────────────────────
class _SpecialtyCard extends StatelessWidget {
  final _Specialty specialty;
  final bool selected;
  final VoidCallback onTap;
  const _SpecialtyCard({required this.specialty, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? specialty.color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? specialty.color : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? [BoxShadow(
            color: specialty.color.withOpacity(0.25),
            blurRadius: 8, offset: const Offset(0, 3),
          )] : [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
          )],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(specialty.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text(
            specialty.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? specialty.color : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ]),
      ),
    );
  }
}

// ── Card urgence ──────────────────────────────────────────────────────────────
class _UrgenceCard extends StatelessWidget {
  final String value, label, subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _UrgenceCard({
    required this.value, required this.label, required this.subtitle,
    required this.icon, required this.color,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? color : Colors.grey, size: 26),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 14,
            color: selected ? color : Colors.black87,
          )),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }
}
