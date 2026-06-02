// STUB web/desktop — l'enregistrement vidéo n'est pas disponible sur cette plateforme

class VideoService {
  bool get isSupported => false;

  Future<bool> hasPermission() async => false;

  Future<void> initialize() async {}

  Future<String?> recordAndStop(int maxSeconds) async => null;

  Future<void> stopRecording() async {}

  void dispose() {}
}
