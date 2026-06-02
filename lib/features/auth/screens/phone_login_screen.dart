import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Données pays (flag + indicatif + exemple)
// ─────────────────────────────────────────────────────────────────────────────
class Country {
  final String name;
  final String flag;
  final String dial;
  final String example;
  const Country({required this.name, required this.flag, required this.dial, required this.example});
}

const kCountries = [
  // Afrique Centrale
  Country(name: 'Cameroun',          flag: '🇨🇲', dial: '+237', example: '6XX XXX XXX'),
  Country(name: 'Congo (Brazzaville)',flag: '🇨🇬', dial: '+242', example: '06 XXX XXXX'),
  Country(name: 'Gabon',             flag: '🇬🇦', dial: '+241', example: '07 XXX XXXX'),
  Country(name: 'RD Congo',          flag: '🇨🇩', dial: '+243', example: '8XX XXX XXX'),
  Country(name: 'Tchad',             flag: '🇹🇩', dial: '+235', example: '6X XX XX XX'),
  Country(name: 'Rép. Centrafricaine',flag: '🇨🇫', dial: '+236', example: '7X XX XX XX'),
  // Afrique de l'Ouest
  Country(name: 'Sénégal',           flag: '🇸🇳', dial: '+221', example: '7X XXX XX XX'),
  Country(name: 'Côte d\'Ivoire',    flag: '🇨🇮', dial: '+225', example: '0X XX XX XX XX'),
  Country(name: 'Ghana',             flag: '🇬🇭', dial: '+233', example: '2X XXX XXXX'),
  Country(name: 'Nigeria',           flag: '🇳🇬', dial: '+234', example: '80X XXX XXXX'),
  Country(name: 'Togo',              flag: '🇹🇬', dial: '+228', example: '9X XX XX XX'),
  Country(name: 'Bénin',             flag: '🇧🇯', dial: '+229', example: '97 XX XX XX'),
  Country(name: 'Mali',              flag: '🇲🇱', dial: '+223', example: '7X XX XX XX'),
  Country(name: 'Burkina Faso',      flag: '🇧🇫', dial: '+226', example: '7X XX XX XX'),
  Country(name: 'Guinée',            flag: '🇬🇳', dial: '+224', example: '6XX XX XX XX'),
  // Afrique de l'Est
  Country(name: 'Kenya',             flag: '🇰🇪', dial: '+254', example: '7XX XXX XXX'),
  Country(name: 'Éthiopie',          flag: '🇪🇹', dial: '+251', example: '9X XXX XXXX'),
  Country(name: 'Rwanda',            flag: '🇷🇼', dial: '+250', example: '7XX XXX XXX'),
  // Afrique du Nord
  Country(name: 'Maroc',             flag: '🇲🇦', dial: '+212', example: '6XX XXX XXX'),
  Country(name: 'Algérie',           flag: '🇩🇿', dial: '+213', example: '5XX XXX XXX'),
  Country(name: 'Tunisie',           flag: '🇹🇳', dial: '+216', example: '2X XXX XXX'),
  Country(name: 'Égypte',            flag: '🇪🇬', dial: '+20',  example: '1X XXXX XXXX'),
  // Europe
  Country(name: 'France',            flag: '🇫🇷', dial: '+33',  example: '6 XX XX XX XX'),
  Country(name: 'Belgique',          flag: '🇧🇪', dial: '+32',  example: '4XX XX XX XX'),
  Country(name: 'Suisse',            flag: '🇨🇭', dial: '+41',  example: '7X XXX XX XX'),
  Country(name: 'Allemagne',         flag: '🇩🇪', dial: '+49',  example: '1XX XXXXXXX'),
  Country(name: 'Royaume-Uni',       flag: '🇬🇧', dial: '+44',  example: '7XXX XXX XXX'),
  Country(name: 'Italie',            flag: '🇮🇹', dial: '+39',  example: '3XX XXX XXXX'),
  Country(name: 'Espagne',           flag: '🇪🇸', dial: '+34',  example: '6XX XXX XXX'),
  // Amériques
  Country(name: 'États-Unis',        flag: '🇺🇸', dial: '+1',   example: '2XX XXX XXXX'),
  Country(name: 'Canada',            flag: '🇨🇦', dial: '+1',   example: '2XX XXX XXXX'),
  Country(name: 'Brésil',            flag: '🇧🇷', dial: '+55',  example: '11 9XXXX XXXX'),
  // Asie & Moyen-Orient
  Country(name: 'Arabie Saoudite',   flag: '🇸🇦', dial: '+966', example: '5X XXX XXXX'),
  Country(name: 'Émirats Arabes',    flag: '🇦🇪', dial: '+971', example: '5X XXX XXXX'),
  Country(name: 'Chine',             flag: '🇨🇳', dial: '+86',  example: '1XX XXXX XXXX'),
  Country(name: 'Inde',              flag: '🇮🇳', dial: '+91',  example: '9XXXXX XXXX'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Traductions simples
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, Map<String, String>> _t = {
  'fr': {
    'register': 'Inscription',
    'login': 'Connexion',
    'your_number': 'Votre numéro',
    'sms_hint': 'Un code de vérification sera envoyé par SMS.',
    'phone_label': 'Numéro de téléphone',
    'send_otp': 'Recevoir le code SMS',
    'welcome_back': 'Bon retour !',
    'login_hint': 'Connectez-vous avec votre username ou numéro',
    'identifier': 'Username ou numéro de téléphone',
    'password': 'Mot de passe',
    'connect': 'Se connecter',
    'forgot': 'Mot de passe oublié ?',
  },
  'en': {
    'register': 'Register',
    'login': 'Login',
    'your_number': 'Your number',
    'sms_hint': 'A verification code will be sent by SMS.',
    'phone_label': 'Phone number',
    'send_otp': 'Receive SMS code',
    'welcome_back': 'Welcome back!',
    'login_hint': 'Login with your username or phone',
    'identifier': 'Username or phone number',
    'password': 'Password',
    'connect': 'Sign in',
    'forgot': 'Forgot password?',
  },
  'ar': {
    'register': 'تسجيل',
    'login': 'دخول',
    'your_number': 'رقم هاتفك',
    'sms_hint': 'سيتم إرسال رمز التحقق عبر الرسائل القصيرة.',
    'phone_label': 'رقم الهاتف',
    'send_otp': 'استلام رمز SMS',
    'welcome_back': 'مرحباً بعودتك!',
    'login_hint': 'سجل الدخول باسم المستخدم أو الهاتف',
    'identifier': 'اسم المستخدم أو رقم الهاتف',
    'password': 'كلمة المرور',
    'connect': 'تسجيل الدخول',
    'forgot': 'نسيت كلمة المرور؟',
  },
};

String tr(String lang, String key) => _t[lang]?[key] ?? _t['fr']![key]!;

// ═════════════════════════════════════════════════════════════════════════════
class PhoneLoginScreen extends ConsumerStatefulWidget {
  final int initialTab;
  final String? preselectedRole; // 'client' | 'provider' passé depuis RoleChoiceScreen
  const PhoneLoginScreen({super.key, this.initialTab = 0, this.preselectedRole});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // ── Inscription ──────────────────────────────────────────────────────────
  Country _regCountry = kCountries.first; // Cameroun par défaut
  final _regPhoneCtrl = TextEditingController();
  bool _regLoading = false;

  // ── Connexion ────────────────────────────────────────────────────────────
  final _loginIdentCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  bool _loginLoading = false;
  bool _loginObscure = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tab.dispose();
    _regPhoneCtrl.dispose();
    _loginIdentCtrl.dispose();
    _loginPassCtrl.dispose();
    super.dispose();
  }

  String get _lang => ref.read(languageProvider).value ?? 'fr';
  String get _fullRegPhone => '${_regCountry.dial}${_regPhoneCtrl.text.trim()}';

  // ── Envoyer OTP inscription ───────────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (_regPhoneCtrl.text.trim().isEmpty) {
      _err('Entrez votre numéro'); return;
    }
    final phone = _fullRegPhone;
    setState(() => _regLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/auth/otp/send', data: {'phone': phone, 'purpose': 'registration'});
      if (mounted) {
        final enc = Uri.encodeComponent(phone);
        final role = widget.preselectedRole ?? 'client';
        context.go('/auth/otp?phone=$enc&purpose=registration&role=$role');
      }
    } catch (e) {
      _err(_extractError(e));
    }
    setState(() => _regLoading = false);
  }

  // ── Connexion ─────────────────────────────────────────────────────────────
  Future<void> _login() async {
    final ident = _loginIdentCtrl.text.trim();
    final pass = _loginPassCtrl.text;
    if (ident.isEmpty || pass.isEmpty) { _err('Remplissez tous les champs'); return; }
    setState(() => _loginLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/auth/login', data: {'identifier': ident, 'password': pass});
      await ref.read(authStateProvider.notifier).setAuth(
        res.data['accessToken'],
        res.data['refreshToken'],
        Map<String, dynamic>.from(res.data['user']),
      );
      if (mounted) context.go('/home');
    } catch (_) {
      _err('Identifiant ou mot de passe incorrect');
    }
    setState(() => _loginLoading = false);
  }

  String _extractError(dynamic e) {
    try {
      final d = (e as dynamic).response?.data;
      if (d is Map && d['message'] != null) return d['message'].toString();
    } catch (_) {}
    return 'Erreur réseau';
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _pickCountry(bool isRegister) async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(selected: isRegister ? _regCountry : kCountries.first),
    );
    if (picked != null && isRegister) setState(() => _regCountry = picked);
  }

  void _showLanguagePicker(String currentLang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageSheet(
        currentLang: currentLang,
        onPick: (code) async {
          await ref.read(languageProvider.notifier).setLanguage(code);
          // Force rebuild explicite après fermeture du sheet
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langAsync = ref.watch(languageProvider);
    final lang = langAsync.value ?? 'fr';
    final isRtl = lang == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/auth/welcome'),
          ),
          actions: [
            // Bouton langue
            InkWell(
              onTap: () => _showLanguagePicker(lang),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    kLanguages.firstWhere((l) => l.code == lang,
                        orElse: () => kLanguages.first).flag,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  Text(lang.toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                ]),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tab,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: tr(lang, 'register')),
              Tab(text: tr(lang, 'login')),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            _buildRegisterTab(lang),
            _buildLoginTab(lang),
          ],
        ),
      ),
    );
  }

  // ── Onglet Inscription ────────────────────────────────────────────────────
  Widget _buildRegisterTab(String lang) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(tr(lang, 'your_number'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(tr(lang, 'sms_hint'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 28),

            // ── Sélecteur pays + champ téléphone ─────────────────────────
            Text(tr(lang, 'phone_label'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(children: [
              // Bouton pays
              GestureDetector(
                onTap: () => _pickCountry(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_regCountry.flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    Text(_regCountry.dial,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _regPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: _regCountry.example,
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal,
                        fontSize: 15, letterSpacing: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
            ]),

            // Aperçu du numéro complet
            if (_regPhoneCtrl.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Numéro complet: $_fullRegPhone',
                    style: TextStyle(color: AppColors.primary, fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _regLoading ? null : _sendOtp,
              icon: _regLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sms_outlined),
              label: Text(tr(lang, 'send_otp'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Onglet Connexion ──────────────────────────────────────────────────────
  Widget _buildLoginTab(String lang) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(tr(lang, 'welcome_back'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(tr(lang, 'login_hint'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 28),

            // Identifiant
            TextField(
              controller: _loginIdentCtrl,
              decoration: InputDecoration(
                labelText: tr(lang, 'identifier'),
                prefixIcon: const Icon(Icons.person_outline),
                hintText: 'wanda_dany ou +237677100001',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mot de passe
            TextField(
              controller: _loginPassCtrl,
              obscureText: _loginObscure,
              decoration: InputDecoration(
                labelText: tr(lang, 'password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_loginObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _loginObscure = !_loginObscure),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onSubmitted: (_) => _login(),
            ),

            // ── Mot de passe oublié ───────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/auth/forgot-password'),
                child: Text(tr(lang, 'forgot'),
                    style: const TextStyle(color: AppColors.primary, fontSize: 13)),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _loginLoading ? null : _login,
              icon: _loginLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login_rounded),
              label: Text(tr(lang, 'connect'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET SÉLECTEUR DE PAYS
// ─────────────────────────────────────────────────────────────────────────────
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
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const Text('Choisir un pays',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Rechercher un pays...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
            onChanged: (v) => setState(() {
              final q = v.toLowerCase();
              _filtered = kCountries.where((c) =>
                c.name.toLowerCase().contains(q) || c.dial.contains(q)
              ).toList();
            }),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final c = _filtered[i];
              final sel = c.dial == widget.selected.dial && c.name == widget.selected.name;
              return ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(c.dial,
                      style: TextStyle(
                        color: sel ? AppColors.primary : Colors.grey.shade600,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      )),
                ),
                selected: sel,
                selectedTileColor: AppColors.primary.withOpacity(0.04),
                onTap: () => Navigator.pop(context, c),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET SÉLECTEUR DE LANGUE
// ─────────────────────────────────────────────────────────────────────────────
class _LanguageSheet extends StatelessWidget {
  final String currentLang;
  final void Function(String) onPick;
  const _LanguageSheet({required this.currentLang, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Choisir la langue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...kLanguages.map((l) {
          final sel = l.code == currentLang;
          return ListTile(
            leading: Text(l.flag, style: const TextStyle(fontSize: 28)),
            title: Text(l.label,
                style: TextStyle(fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16)),
            trailing: sel
                ? const Icon(Icons.check_circle, color: AppColors.primary)
                : null,
            tileColor: sel ? AppColors.primary.withOpacity(0.05) : null,
            onTap: () {
              onPick(l.code);
              Navigator.pop(context);
            },
          );
        }),
        const SizedBox(height: 16),
      ]),
    );
  }
}
