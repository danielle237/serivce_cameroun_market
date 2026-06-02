import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    try {
      final token = await _storage.read(key: 'access_token');
      final userJson = await _storage.read(key: 'user');

      if (token != null && userJson != null) {
        return AuthState(
          accessToken: token,
          user: json.decode(userJson),
        );
      }
    } catch (_) {
      // Stockage sécurisé indisponible (web sans crypto, ou première init)
    }
    return const AuthState();
  }

  Future<void> setAuth(String accessToken, String refreshToken, Map<String, dynamic> user) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
    await _storage.write(key: 'user', value: json.encode(user));
    state = AsyncData(AuthState(accessToken: accessToken, refreshToken: refreshToken, user: user));
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
