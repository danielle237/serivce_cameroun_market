import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

// Stockage pré-lu dans main() avant runApp — évite le flash d'écran de chargement
AuthState? _preloadedAuthState;

class AuthState {
  final String? accessToken;
  final String? refreshToken;
  final Map<String, dynamic>? user;
  final bool isLoading;

  const AuthState({this.accessToken, this.refreshToken, this.user, this.isLoading = false});

  bool get isAuthenticated => accessToken != null;

  AuthState copyWith({String? accessToken, String? refreshToken, Map<String, dynamic>? user, bool? isLoading}) {
    return AuthState(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  final _storage = const FlutterSecureStorage(
    webOptions: WebOptions(dbName: 'w2d_secure', publicKey: 'w2d_pub_key'),
  );

  @override
  Future<AuthState> build() async {
    // Si main() a pré-lu les tokens, on retourne directement sans I/O
    if (_preloadedAuthState != null) {
      final s = _preloadedAuthState!;
      _preloadedAuthState = null;
      return s;
    }
    // Fallback (ne devrait pas arriver si preloadAuth() est appelé dans main)
    try {
      final token = await _storage.read(key: 'access_token');
      final refreshToken = await _storage.read(key: 'refresh_token');
      final userJson = await _storage.read(key: 'user');

      if (token != null && userJson != null) {
        return AuthState(
          accessToken: token,
          refreshToken: refreshToken,
          user: json.decode(userJson),
        );
      }
    } catch (_) {
      // Stockage sécurisé indisponible (web sans crypto, ou première init)
    }
    return const AuthState();
  }

  /// Appeler dans main() avant runApp() pour supprimer le flash d'écran de chargement.
  static Future<void> preloadAuth() async {
    const storage = FlutterSecureStorage(
      webOptions: WebOptions(dbName: 'w2d_secure', publicKey: 'w2d_pub_key'),
    );
    try {
      final token       = await storage.read(key: 'access_token');
      final refreshTok  = await storage.read(key: 'refresh_token');
      final userJson    = await storage.read(key: 'user');
      if (token != null && userJson != null) {
        _preloadedAuthState = AuthState(
          accessToken: token,
          refreshToken: refreshTok,
          user: json.decode(userJson) as Map<String, dynamic>,
        );
      } else {
        _preloadedAuthState = const AuthState();
      }
    } catch (_) {
      _preloadedAuthState = const AuthState();
    }
  }

  Future<void> setAuth(String accessToken, String refreshToken, Map<String, dynamic> user) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
    await _storage.write(key: 'user', value: json.encode(user));
    state = AsyncData(AuthState(accessToken: accessToken, refreshToken: refreshToken, user: user));
    // Enregistrer le FCM token en arrière-plan
    _registerFcmToken(accessToken);
  }

  Future<void> _registerFcmToken(String accessToken) async {
    if (kIsWeb) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      // Dio au lieu de http — profite du retry + timeout configurés globalement
      final dio = Dio(BaseOptions(
        baseUrl: 'http://51.83.40.138:3005/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ));
      await dio.patch('/users/profile', data: {'fcmToken': fcmToken});
    } catch (_) { /* silencieux — ne pas bloquer le login */ }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AsyncData(AuthState());
  }

  Map<String, dynamic>? get currentUser => state.value?.user;

  /// Met à jour les données user localement (après switch mode, etc.)
  Future<void> updateUser(Map<String, dynamic> updatedUser) async {
    final current = state.value;
    if (current == null) return;
    await _storage.write(key: 'user', value: json.encode(updatedUser));
    state = AsyncData(current.copyWith(user: updatedUser));
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
