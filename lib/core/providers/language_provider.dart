import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLanguage {
  final String code;
  final String label;
  final String flag;
  const AppLanguage({required this.code, required this.label, required this.flag});
}

const kLanguages = [
  AppLanguage(code: 'fr', label: 'Français', flag: '🇫🇷'),
  AppLanguage(code: 'en', label: 'English',  flag: '🇬🇧'),
  AppLanguage(code: 'ar', label: 'عربي',     flag: '🇸🇦'),
];

class LanguageNotifier extends AsyncNotifier<String> {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String> build() async {
    return await _storage.read(key: 'app_language') ?? 'fr';
  }

  Future<void> setLanguage(String code) async {
    await _storage.write(key: 'app_language', value: code);
    state = AsyncData(code);
  }
}

final languageProvider = AsyncNotifierProvider<LanguageNotifier, String>(LanguageNotifier.new);
