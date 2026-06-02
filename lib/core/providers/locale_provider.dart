import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocaleNotifier extends AsyncNotifier<Locale> {
  final _storage = const FlutterSecureStorage();

  @override
  Future<Locale> build() async {
    // Charger la langue sauvegardée (persiste entre sessions)
    final saved = await _storage.read(key: 'app_locale');
    return Locale(saved ?? 'fr');
  }

  Future<void> setLocale(String languageCode) async {
    await _storage.write(key: 'app_locale', value: languageCode);
    state = AsyncData(Locale(languageCode));
  }
}

final localeProvider = AsyncNotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
