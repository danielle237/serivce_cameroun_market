import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import 'phone_login_screen.dart' show kCountries, Country;

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  // Étapes : 0=saisie téléphone, 1=saisie OTP, 2=nouveau mot de passe
  int _step = 0;

  // Étape 0
  Country _country = kCountries.first;
  final _phoneCtrl = TextEditingController();

  // Étape 1
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  int _attemptsLeft = 3;

  // Étape 2
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  bool _loading = false;
  String get _fullPhone => '${_country.dial}${_phoneCtrl.text.trim()}';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Étape 0 : envoyer OTP ────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) { _snack('Entrez votre numéro de téléphone', Colors.orange); return; }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/auth/forgot-password', data: {'phone': _fullPhone});
      if (mounted) {
        _snack('Code OTP envoyé par SMS', Colors.green);
        setState(() { _step = 1; });
      }
    } catch (e) {
      _snack(_extractError(e), Colors.red);
    }
    setState(() => _loading = false);
  }

  // ── Étape 1 : vérifier OTP ───────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) { _snack('Entrez le code à 6 chiffres', Colors.orange); return; }
    if (_attemptsLeft <= 0) { _snack('Maximum de tentatives atteint', Colors.red); return; }

    setState(() => _loading = true);
    try {
      // On vérifie l'OTP en essayant un reset factice (le backend validera)
      // Ici on passe juste à l'étape 2 et on validera au moment du reset final
      setState(() { _step = 2; });
    } catch (e) {
      setState(() => _attemptsLeft--);
      _snack('Code incorrect. $_attemptsLeft tentative${_attemptsLeft > 1 ? 's' : ''} restante${_attemptsLeft > 1 ? 's' : ''}', Colors.red);
      if (_attemptsLeft <= 0) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/auth/login');
      }
    }
    setState(() => _loading = false);
  }

  // ── Étape 2 : réinitialiser le mot de passe ──────────────────────────────
  Future<void> _resetPassword() async {
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pass.length < 6) { _snack('Minimum 6 caractères', Colors.orange); return; }
    if (pass != confirm) { _snack('Les mots de passe ne correspondent pas', Colors.orange); return; }

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final otp = _otpCtrls.map((c) => c.text).join();
      await api.post('/auth/reset-password', data: {
        'phone': _fullPhone,
        'otpCode': otp,
        'newPassword': pass,
      });
      if (mounted) {
        _snack('Mot de passe réinitialisé ✅', Colors.green);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/auth/login');
      }
    } catch (e) {
      final msg = _extractError(e);
      _snack(msg, Colors.red);
      // Si OTP invalide, retour à l'étape 1
      if (msg.contains('OTP') || msg.contains('expiré')) {
        setState(() { _step = 1; _attemptsLeft--; });
      }
    }
    setState(() => _loading = false);
  }

  String _extractError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
    } catch (_) {}
    return 'Erreur réseau. Réessayez.';
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _step == 0 ? context.go('/auth/login') : setState(() => _step--),
        ),
        title: const Text('Mot de passe oublié'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Indicateur d'étapes ───────────────────────────────────
              _StepIndicator(current: _step),
              const SizedBox(height: 32),

              // ── Contenu selon l'étape ─────────────────────────────────
              if (_step == 0) _buildStep0(),
              if (_step == 1) _buildStep1(),
              if (_step == 2) _buildStep2(),
            ],
          ),
        ),
      ),
    );
  }

  // ── ÉTAPE 0 : Saisie du téléphone ─────────────────────────────────────────
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Votre numéro de téléphone',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Entrez le numéro associé à votre compte W2D.\nVous recevrez un code OTP par SMS.',
            style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 28),

        // Sélecteur de pays + champ téléphone
        Row(children: [
          // Bouton pays
          GestureDetector(
            onTap: _pickCountry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_country.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(_country.dial, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 20),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: _country.example,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
        const SizedBox(height: 32),

        ElevatedButton.icon(
          onPressed: _loading ? null : _sendOtp,
          icon: _loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send),
          label: const Text('Envoyer le code OTP', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ── ÉTAPE 1 : Saisie OTP ──────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Code de vérification',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Code envoyé au $_fullPhone',
            style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 28),

        // 6 cases OTP
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => SizedBox(
            width: 46,
            child: TextField(
              controller: _otpCtrls[i],
              focusNode: _otpFocus[i],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onChanged: (v) {
                if (v.isNotEmpty && i < 5) {
                  _otpFocus[i + 1].requestFocus();
                } else if (v.isEmpty && i > 0) {
                  _otpFocus[i - 1].requestFocus();
                }
                if (i == 5 && v.isNotEmpty) _verifyOtp();
              },
            ),
          )),
        ),

        if (_attemptsLeft < 3) ...[
          const SizedBox(height: 10),
          Text(
            '$_attemptsLeft tentative${_attemptsLeft > 1 ? 's' : ''} restante${_attemptsLeft > 1 ? 's' : ''}',
            style: TextStyle(
              color: _attemptsLeft == 1 ? Colors.red : Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 28),

        ElevatedButton.icon(
          onPressed: _loading ? null : _verifyOtp,
          icon: _loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline),
          label: const Text('Valider le code', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: _loading ? null : _sendOtp,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Renvoyer le code'),
          ),
        ),
      ],
    );
  }

  // ── ÉTAPE 2 : Nouveau mot de passe ────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nouveau mot de passe',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Choisissez un mot de passe sécurisé (minimum 6 caractères)',
            style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 28),

        TextField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          decoration: InputDecoration(
            labelText: 'Nouveau mot de passe',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _confirmCtrl,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirmer le mot de passe',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 32),

        ElevatedButton.icon(
          onPressed: _loading ? null : _resetPassword,
          icon: _loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.lock_reset),
          label: const Text('Réinitialiser le mot de passe', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(selected: _country),
    );
    if (picked != null) setState(() => _country = picked);
  }
}

// ─── Indicateur d'étapes ──────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    const steps = ['Téléphone', 'Code OTP', 'Mot de passe'];
    return Row(
      children: List.generate(steps.length, (i) {
        final done = i < current;
        final active = i == current;
        return Expanded(
          child: Row(children: [
            Expanded(
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: active ? 32 : 26,
                  height: active ? 32 : 26,
                  decoration: BoxDecoration(
                    color: done ? AppColors.primary : active ? AppColors.primary : Colors.grey.shade200,
                    shape: BoxShape.circle,
                    border: active ? Border.all(color: AppColors.primary, width: 2) : null,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : Text('${i + 1}',
                            style: TextStyle(
                              color: active ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            )),
                  ),
                ),
                const SizedBox(height: 4),
                Text(steps[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: active || done ? AppColors.primary : Colors.grey,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    )),
              ]),
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: done ? AppColors.primary : Colors.grey.shade300,
                ),
              ),
          ]),
        );
      }),
    );
  }
}

// ─── Sheet de sélection de pays (réutilise le même que phone_login_screen) ───
class _CountryPickerSheet extends StatefulWidget {
  final Country selected;
  const _CountryPickerSheet({required this.selected});
  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Country> _filtered = kCountries;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const Text('Choisir un pays', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Rechercher un pays...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
            onChanged: (v) => setState(() {
              _filtered = kCountries.where((c) =>
                c.name.toLowerCase().contains(v.toLowerCase()) ||
                c.dial.contains(v)
              ).toList();
            }),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final c = _filtered[i];
              final selected = c.dial == widget.selected.dial;
              return ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                title: Text(c.name),
                trailing: Text(c.dial,
                    style: TextStyle(color: selected ? AppColors.primary : Colors.grey,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                selected: selected,
                selectedTileColor: AppColors.primary.withOpacity(0.05),
                onTap: () => Navigator.pop(context, c),
              );
            },
          ),
        ),
      ]),
    );
  }
}
