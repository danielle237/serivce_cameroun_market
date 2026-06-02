import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Données transmises par l'écran OTP
  String _phone    = '';
  String _otpToken = '';

  // Étape courante: 1=ville/géo  2=selfie  3=username/mdp
  int _step = 1;

  // ── Étape 1 : Ville & géolocalisation ─────────────────────────────────────
  String _city = 'Yaoundé';
  double? _lat;
  double? _lng;
  bool _geoLoading = false;

  final _cities = [
    'Yaoundé', 'Douala', 'Bafoussam', 'Garoua',
    'Maroua', 'Bamenda', 'Ngaoundéré', 'Autre',
  ];

  // ── Étape 2 : Selfie ───────────────────────────────────────────────────────
  XFile? _selfieFile;
  String? _selfieUrl;
  bool _selfieLoading = false;

  // ── Étape 3 : Username, mot de passe, nom, rôle, langue ───────────────────
  final _nameCtrl     = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _pass2Ctrl    = TextEditingController();
  String _role        = 'client';
  String _language    = 'fr';
  List<Map<String, dynamic>> _allProfessions = [];
  final Set<String> _selectedProfessions = {};
  bool _professionsLoading = false;
  bool _obscurePass   = true;
  bool _obscurePass2  = true;
  bool _usernameAvail = true;
  bool _checkingUser  = false;
  bool _isLoading     = false;

  bool _roleInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = GoRouterState.of(context);
    _phone    = s.uri.queryParameters['phone']    ?? (s.extra as Map?)?.cast<String,dynamic>()['phone']    ?? '';
    _otpToken = s.uri.queryParameters['otpToken'] ?? (s.extra as Map?)?.cast<String,dynamic>()['otpToken'] ?? '';
    // Rôle pré-sélectionné depuis RoleChoiceScreen — appliqué une seule fois
    if (!_roleInitialized) {
      final preRole = s.uri.queryParameters['role'];
      if (preRole == 'client' || preRole == 'provider') {
        _role = preRole!;
        _roleInitialized = true;
        if (preRole == 'provider') {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfessions());
        }
      }
    }
    if (_phone.isEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/auth/login'));
    }
  }

  bool get _rolePreselected => _roleInitialized;

  // ── Géolocalisation ────────────────────────────────────────────────────────
  Future<void> _getLocation() async {
    setState(() => _geoLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _err('Autorisation de localisation refusée définitivement');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      setState(() { _lat = pos.latitude; _lng = pos.longitude; });
    } catch (e) {
      _err('Impossible d\'obtenir la localisation');
    } finally {
      setState(() => _geoLoading = false);
    }
  }

  // ── Selfie ─────────────────────────────────────────────────────────────────
  Future<void> _takeSelfie() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() { _selfieFile = file; _selfieLoading = true; });
    try {
      final api  = ref.read(apiClientProvider);
      final form = FormData.fromMap({
        'selfie': await MultipartFile.fromFile(file.path, filename: 'selfie.jpg'),
      });
      final res = await api.uploadFile('/auth/selfie/upload', form);
      setState(() => _selfieUrl = res.data['selfieUrl']);
    } catch (e) {
      _err('Erreur upload selfie');
    } finally {
      setState(() => _selfieLoading = false);
    }
  }

  // ── Charger les professions depuis le backend ─────────────────────────────
  Future<void> _loadProfessions() async {
    if (_allProfessions.isNotEmpty) return;
    setState(() => _professionsLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/professions');
      setState(() {
        _allProfessions = List<Map<String, dynamic>>.from(
          (res.data as List).map((e) => Map<String, dynamic>.from(e)));
      });
    } catch (_) {}
    setState(() => _professionsLoading = false);
  }

  // ── Vérifier disponibilité username ───────────────────────────────────────
  Future<void> _checkUsername(String val) async {
    if (val.length < 3) return;
    setState(() => _checkingUser = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/auth/check-username', params: {'username': val});
      setState(() => _usernameAvail = res.data['available'] == true);
    } catch (_) {}
    finally { setState(() => _checkingUser = false); }
  }

  // ── Inscription finale ─────────────────────────────────────────────────────
  Future<void> _register() async {
    if (_nameCtrl.text.trim().length < 2) { _err('Nom trop court'); return; }
    if (_usernameCtrl.text.trim().length < 3) { _err('Username trop court (min 3 caractères)'); return; }
    if (!_usernameAvail) { _err('Ce username est déjà pris'); return; }
    if (_passCtrl.text.length < 6) { _err('Mot de passe trop court (min 6 caractères)'); return; }
    if (_passCtrl.text != _pass2Ctrl.text) { _err('Les mots de passe ne correspondent pas'); return; }
    if (_role == 'provider' && _selectedProfessions.isEmpty) {
      _err('Sélectionnez au moins un métier'); return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/auth/register', data: {
        'phone':     _phone,
        'otpToken':  _otpToken,
        'fullName':  _nameCtrl.text.trim(),
        'username':  _usernameCtrl.text.trim(),
        'password':  _passCtrl.text,
        'role':      _role,
        'city':      _city,
        if (_lat != null) 'latitude':  _lat,
        if (_lng != null) 'longitude': _lng,
        if (_selfieUrl != null) 'selfieUrl': _selfieUrl,
        'language':  _language,
        if (_role == 'provider') 'professions': _selectedProfessions.toList(),
      });

      await ref.read(authStateProvider.notifier).setAuth(
        res.data['accessToken'],
        res.data['refreshToken'],
        Map<String, dynamic>.from(res.data['user']),
      );

      if (mounted) context.go('/home');
    } catch (e) {
      _err('Erreur inscription: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Checklist des professions groupée par catégorie ──────────────────────
  Widget _buildProfessionChecklist() {
    // Grouper par catégorie
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final p in _allProfessions) {
      final cat = p['category'] as String? ?? 'Autre';
      grouped.putIfAbsent(cat, () => []).add(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de catégorie
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(entry.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primary,
                  )),
            ),
            // Items de la catégorie
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.value.map((p) {
                final name = p['name'] as String;
                final selected = _selectedProfessions.contains(name);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedProfessions.remove(name);
                    } else {
                      _selectedProfessions.add(name);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected ? AppColors.primary : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected ? [
                        BoxShadow(color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 6, offset: const Offset(0, 2))
                      ] : [],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (selected) ...[
                        const Icon(Icons.check_circle, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(name, style: TextStyle(
                        fontSize: 13,
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      )),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inscription — étape $_step/3'),
        leading: _step > 1
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _step--))
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/auth/login')),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _step == 1 ? _buildStep1() : _step == 2 ? _buildStep2() : _buildStep3(),
        ),
      ),
    );
  }

  // ── ÉTAPE 1 : Ville & géolocalisation ─────────────────────────────────────
  Widget _buildStep1() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('Où êtes-vous ?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Cela permet de vous mettre en contact avec des prestataires proches.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 32),
          DropdownButtonFormField<String>(
            value: _city,
            decoration: const InputDecoration(labelText: 'Ville', prefixIcon: Icon(Icons.location_city)),
            items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _city = v!),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _geoLoading ? null : _getLocation,
            icon: _geoLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label: Text(_lat != null
                ? 'Localisation obtenue ✓'
                : 'Utiliser ma position GPS'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _lat != null ? Colors.green : AppColors.primary,
            ),
          ),
          if (_lat != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => setState(() => _step = 2),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  // ── ÉTAPE 2 : Selfie ───────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('Votre photo', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Un selfie est requis pour vérifier votre identité (KYC).',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: _selfieLoading ? null : _takeSelfie,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF3F4F6),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: _selfieLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _selfieFile != null
                        ? ClipOval(child: _SelfiePreview(file: _selfieFile!))
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 48, color: AppColors.primary),
                              SizedBox(height: 8),
                              Text('Prendre un selfie', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Utilisez la caméra frontale, bonne luminosité, visage bien visible.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _selfieLoading ? null : () => setState(() => _step = 3),
            child: Text(_selfieUrl != null ? 'Continuer' : 'Passer (optionnel)'),
          ),
        ],
      ),
    );
  }

  // ── ÉTAPE 3 : Username, mot de passe, nom, rôle ───────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('Votre profil', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Numéro: $_phone', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),

          // Nom complet
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person)),
          ),
          const SizedBox(height: 16),

          // Username
          TextField(
            controller: _usernameCtrl,
            decoration: InputDecoration(
              labelText: 'Username (unique)',
              prefixIcon: const Icon(Icons.alternate_email),
              helperText: 'Lettres, chiffres et _ uniquement. Ex: wanda_dany',
              suffixIcon: _checkingUser
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : _usernameCtrl.text.length >= 3
                      ? Icon(_usernameAvail ? Icons.check_circle : Icons.cancel,
                            color: _usernameAvail ? Colors.green : AppColors.error)
                      : null,
            ),
            onChanged: (v) { setState(() {}); _checkUsername(v); },
          ),
          const SizedBox(height: 16),

          // Mot de passe
          TextField(
            controller: _passCtrl,
            obscureText: _obscurePass,
            decoration: InputDecoration(
              labelText: 'Mot de passe (min. 6 caractères)',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Confirmation mot de passe
          TextField(
            controller: _pass2Ctrl,
            obscureText: _obscurePass2,
            decoration: InputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePass2 ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePass2 = !_obscurePass2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Rôle — badge si pré-sélectionné, sélecteur sinon
          if (_rolePreselected) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _role == 'provider'
                    ? const Color(0xFFF59E0B).withOpacity(0.08)
                    : AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _role == 'provider'
                      ? const Color(0xFFF59E0B).withOpacity(0.4)
                      : AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(children: [
                Icon(
                  _role == 'provider' ? Icons.work_outline : Icons.person_outline,
                  color: _role == 'provider' ? const Color(0xFFF59E0B) : AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _role == 'provider' ? 'Compte Prestataire' : 'Compte Client',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _role == 'provider' ? const Color(0xFFF59E0B) : AppColors.primary,
                    ),
                  ),
                  Text(
                    _role == 'provider'
                        ? 'Vous proposerez vos services sur W2D'
                        : 'Vous rechercherez des services sur W2D',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ])),
                GestureDetector(
                  onTap: () => context.go('/auth/role-choice'),
                  child: const Text('Changer',
                      style: TextStyle(fontSize: 12, color: AppColors.primary,
                          decoration: TextDecoration.underline)),
                ),
              ]),
            ),
          ] else ...[
            const Text('Vous êtes :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _RoleCard(
                  title: 'Client', icon: Icons.person, subtitle: 'Je cherche des services',
                  selected: _role == 'client', onTap: () => setState(() => _role = 'client'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _RoleCard(
                  title: 'Prestataire', icon: Icons.work, subtitle: 'Je propose des services',
                  selected: _role == 'provider',
                  onTap: () { setState(() => _role = 'provider'); _loadProfessions(); },
                )),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // ── Checklist métiers (prestataire uniquement) ────────────────
          if (_role == 'provider') ...[
            const Divider(),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.work_outline, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Vos métiers *',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              if (_selectedProfessions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${_selectedProfessions.length} sélectionné${_selectedProfessions.length > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 4),
            const Text('Sélectionnez tous les métiers que vous exercez.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            if (_professionsLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ))
            else if (_allProfessions.isEmpty)
              Center(
                child: TextButton.icon(
                  onPressed: _loadProfessions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Charger les métiers'),
                ),
              )
            else
              _buildProfessionChecklist(),
            const SizedBox(height: 8),
          ],

          // Langue préférentielle de communication
          const Text('Langue préférentielle de communication :',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          const Text(
            'Les SMS et notifications W2D vous seront envoyés dans cette langue.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _LangCard(
                lang: 'fr', label: '🇫🇷 Français', selected: _language == 'fr',
                onTap: () => setState(() => _language = 'fr'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _LangCard(
                lang: 'en', label: '🇬🇧 English', selected: _language == 'en',
                onTap: () => setState(() => _language = 'en'),
              )),
            ],
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _isLoading ? null : _register,
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Créer mon compte'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Aperçu selfie (Web vs Android) ───────────────────────────────────────────
class _SelfiePreview extends StatelessWidget {
  final XFile file;
  const _SelfiePreview({required this.file});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(file.path, fit: BoxFit.cover, width: 180, height: 180);
    }
    // Android / iOS : utiliser ImageProvider via bytes pour éviter dart:io direct
    return FutureBuilder<List<int>>(
      future: file.readAsBytes().then((b) => b.toList()),
      builder: (ctx, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        return Image.memory(
          Uint8List.fromList(snap.data!),
          fit: BoxFit.cover,
          width: 180,
          height: 180,
        );
      },
    );
  }
}

// ── Widgets réutilisables ─────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE5E7EB), width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary, size: 32),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? AppColors.primary : AppColors.textPrimary)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final String lang, label;
  final bool selected;
  final VoidCallback onTap;
  const _LangCard({required this.lang, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(label, style: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ))),
      ),
    );
  }
}
