import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Source unique de vérité pour la langue de l'app.
/// Remplace l'ancien languageProvider (obsolète).
class LocaleNotifier extends AsyncNotifier<Locale> {
  final _storage = const FlutterSecureStorage();

  @override
  Future<Locale> build() async {
    // Lire depuis le stockage persistant (clé unifiée)
    final saved = await _storage.read(key: 'app_locale')
        ?? await _storage.read(key: 'app_language') // rétro-compat ancienne clé
        ?? 'fr';
    return Locale(saved);
  }

  Future<void> setLocale(String languageCode) async {
    await _storage.write(key: 'app_locale', value: languageCode);
    state = AsyncData(Locale(languageCode));
  }
}

final localeProvider = AsyncNotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

/// Getter rapide du code langue courant (ex: 'fr', 'en', 'ar')
extension LocaleProviderRef on AsyncValue<Locale> {
  String get langCode => value?.languageCode ?? 'fr';
}
