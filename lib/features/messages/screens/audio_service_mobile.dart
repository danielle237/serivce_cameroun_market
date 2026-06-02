// IMPLÉMENTATION MOBILE — utilise le package record
// Ce fichier est uniquement compilé sur Android/iOS

import 'dart:async';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();

  bool get isSupported => true;

  Future<bool> hasPermission() async => _recorder.hasPermission();

  Future<void> start(String path) async {
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: path,
    );
  }

  Future<String?> stop() async => _recorder.stop();

  void dispose() => _recorder.dispose();

  Future<String> getTempPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  /// Stream d'amplitude normalisée [0.0 → 1.0] pendant l'enregistrement.
  /// Émet toutes les 80ms. -60 dBFS ou moins → 0.0, 0 dBFS → 1.0.
  Stream<double> get amplitudeStream {
    return _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .map((amp) {
          // amp.current est en dBFS, négatif. On ramène [-60, 0] → [0, 1].
          final db = amp.current.clamp(-60.0, 0.0);
          return ((db + 60.0) / 60.0).clamp(0.0, 1.0);
        });
  }
}
