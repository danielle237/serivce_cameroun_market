import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class LivenessScreen extends ConsumerStatefulWidget {
  const LivenessScreen({super.key});

  @override
  ConsumerState<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends ConsumerState<LivenessScreen> {
  CameraController? _controller;
  bool _isCapturing = false;
  bool _isCaptured = false;
  String? _imagePath;
  int _step = 0; // 0: instructions, 1: caméra, 2: confirmation

  final _steps = ['Regardez droit', 'Souriez', 'Tournez légèrement la tête'];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(front, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || _isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final file = await _controller!.takePicture();
      setState(() {
        _imagePath = file.path;
        _step = 2;
      });
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _uploadSelfie() async {
    if (_imagePath == null) return;
    setState(() => _isCapturing = true);

    try {
      final api = ref.read(apiClientProvider);
      final form = FormData.fromMap({
        'selfie': await MultipartFile.fromFile(_imagePath!, filename: 'selfie.jpg'),
      });
      await api.uploadFile('/auth/selfie', form);
      if (mounted) context.go('/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur upload. Réessayez.'),
        backgroundColor: AppColors.error,
      ));
      setState(() { _step = 1; _imagePath = null; });
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification d\'identité')),
      body: SafeArea(
        child: _step == 0 ? _buildInstructions()
            : _step == 1 ? _buildCamera()
            : _buildConfirmation(),
      ),
    );
  }

  Widget _buildInstructions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.face, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text('Selfie de vérification', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
            'Pour votre sécurité, nous devons vérifier votre identité. Prenez un selfie clair depuis la caméra frontale.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),
          _InstructionTile(icon: Icons.lightbulb_outline, text: 'Bonne luminosité recommandée'),
          _InstructionTile(icon: Icons.no_photography, text: 'Pas de lunettes de soleil'),
          _InstructionTile(icon: Icons.phone_android, text: 'Tenez votre téléphone à hauteur du visage'),
          _InstructionTile(icon: Icons.lock, text: 'Photo utilisée uniquement pour la vérification KYC'),
          const Spacer(),
          ElevatedButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text('Commencer la vérification'),
          ),
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Plus tard'),
          ),
        ],
      ),
    );
  }

  Widget _buildCamera() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              CameraPreview(_controller!),
              // Overlay oval pour guide
              Center(
                child: Container(
                  width: 240, height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(120),
                  ),
                ),
              ),
              Positioned(
                bottom: 20, left: 0, right: 0,
                child: Text(
                  _steps[_step < 3 ? 0 : 0],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black54)]),
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: GestureDetector(
            onTap: _capturePhoto,
            child: Container(
              width: 72, height: 72,
              margin: const EdgeInsets.symmetric(horizontal: 150),
              decoration: BoxDecoration(
                color: _isCapturing ? Colors.grey : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 4),
              ),
              child: _isCapturing
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.camera_alt, color: AppColors.primary, size: 32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmation() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text('Vérifiez votre selfie', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          if (_imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(_imagePath!), height: 300, width: 240, fit: BoxFit.cover),
            ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isCapturing ? null : _uploadSelfie,
            child: _isCapturing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Confirmer et continuer'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() { _step = 1; _imagePath = null; }),
            child: const Text('Reprendre la photo'),
          ),
        ],
      ),
    );
  }
}

class _InstructionTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InstructionTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}
