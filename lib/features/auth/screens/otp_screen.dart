import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String purpose;
  final String? role; // transmis depuis PhoneLoginScreen
  const OtpScreen({super.key, required this.phone, this.purpose = 'registration', this.role});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _countdown = 600; // 10 minutes
  int _attemptsLeft = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        t.cancel();
      }
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 6) return;
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);

      if (widget.purpose == 'login') {
        final res = await api.post('/auth/login', data: {
          'phone': widget.phone,
          'otpCode': _otpCode,
        });
        await ref.read(authStateProvider.notifier).setAuth(
          res.data['accessToken'],
          res.data['refreshToken'],
          Map<String, dynamic>.from(res.data['user']),
        );
        if (mounted) context.go('/home');
      } else {
        // registration flow
        final res = await api.post('/auth/otp/verify', data: {
          'phone': widget.phone,
          'code': _otpCode,
          'purpose': widget.purpose,
        });
        final token = res.data['otpToken'] as String;
        final encodedPhone = Uri.encodeComponent(widget.phone);
        final encodedToken = Uri.encodeComponent(token);
        final roleParam = widget.role != null ? '&role=${widget.role}' : '';
        if (mounted) context.go('/auth/register?phone=$encodedPhone&otpToken=$encodedToken$roleParam');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Code invalide ou expiré. Réessayez.'),
        backgroundColor: AppColors.error,
      ));
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Code de vérification')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('Entrez le code SMS', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Code envoyé au ${widget.phone}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),

              // 6 champs OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) => SizedBox(
                  width: 48,
                  height: 60,
                  child: TextFormField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                      if (val.isNotEmpty && i == 5) _verifyOtp();
                      if (val.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                    },
                  ),
                )),
              ),

              const SizedBox(height: 32),

              Center(
                child: Column(
                  children: [
                    if (_countdown > 0) ...[
                      Text(
                        'Code valable : ${(_countdown ~/ 60).toString().padLeft(2, '0')}:${(_countdown % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tentatives restantes : $_attemptsLeft/3',
                        style: TextStyle(
                          color: _attemptsLeft == 1 ? AppColors.error : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ] else
                      _attemptsLeft > 0
                          ? TextButton(
                              onPressed: () {
                                setState(() => _countdown = 600);
                                _startCountdown();
                              },
                              child: const Text('Renvoyer le code'),
                            )
                          : const Text(
                              'Maximum atteint. Réessayez dans 10 minutes.',
                              style: TextStyle(color: AppColors.error, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                  ],
                ),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _isLoading || _otpCode.length != 6 ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Vérifier'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
