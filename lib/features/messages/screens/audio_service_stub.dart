// STUB WEB — aucune dépendance à record
// Ce fichier est utilisé sur web/desktop où record n'est pas supporté

import 'dart:async';

class AudioService {
  Future<bool> hasPermission() async => false;
  Future<String> getTempPath() async => '';
  Future<void> start(String path) async {}
  Future<String?> stop() async => null;
  void dispose() {}
  bool get isSupported => false;
  Stream<double> get amplitudeStream => const Stream.empty();
}
