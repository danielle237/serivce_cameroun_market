// IMPLÉMENTATION MOBILE — utilise le package camera
// Compilé uniquement sur Android/iOS

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

class VideoService {
  CameraController? _controller;
  bool _initialized = false;

  bool get isSupported => true;

  Future<bool> hasPermission() async {
    try {
      final cameras = await availableCameras();
      return cameras.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    // Préférer la caméra arrière
    final cam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: true,
    );
    await _controller!.initialize();
    _initialized = true;
  }

  CameraController? get controller => _controller;

  /// Démarre l'enregistrement, s'arrête automatiquement après [maxSeconds].
  /// Retourne le chemin du fichier mp4, ou null en cas d'erreur.
  Future<String?> recordAndStop(int maxSeconds) async {
    if (_controller == null || !_initialized) return null;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    await _controller!.startVideoRecording();
    await Future.delayed(Duration(seconds: maxSeconds));

    try {
      final file = await _controller!.stopVideoRecording();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> stopRecording() async {
    if (_controller?.value.isRecordingVideo ?? false) {
      await _controller!.stopVideoRecording();
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }
}
