import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cache_service.dart';

// ─── URL du serveur ────────────────────────────────────────────────────────────
const _baseUrl   = 'http://51.83.40.138:3005/api/v1';
const _wsBaseUrl = 'http://51.83.40.138:3005';

// ─── Paramètres réseau Cameroun (MTN/Orange 3G/4G instable) ───────────────────
const _connectTimeout = Duration(seconds: 15);
const _receiveTimeout = Duration(seconds: 30);
const _maxRetries     = 3;

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage(
    webOptions: WebOptions(dbName: 'w2d_secure', publicKey: 'w2d_pub_key'),
  );

  // Queue des actions effectuées hors-ligne à rejouer quand la connexion revient
  final List<_QueuedAction> _offlineQueue = [];

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate, br', // compression → -60% data
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';

        // Limiter à 20 items par page pour économiser la data
        if (options.method == 'GET' && options.queryParameters['limit'] == null) {
          options.queryParameters['limit'] = 20;
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: 'access_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final retry = await _dio.fetch(error.requestOptions);
            return handler.resolve(retry);
          }
        }
        handler.next(error);
      },
    ));

    _dio.interceptors.add(_RetryInterceptor(_dio, retries: _maxRetries));
  }

  Future<bool> _refreshToken() async {
    try {
      final refresh = await _storage.read(key: 'refresh_token');
      if (refresh == null) return false;
      final res = await _dio.post('/auth/refresh', data: {'refreshToken': refresh});
      await _storage.write(key: 'access_token',  value: res.data['accessToken']);
      await _storage.write(key: 'refresh_token', value: res.data['refreshToken']);
      return true;
    } catch (_) {
      await _storage.deleteAll();
      return false;
    }
  }

  // ── GET avec cache-first ──────────────────────────────────────────────────
  /// [cacheTtl] : durée de validité du cache (défaut 5 min).
  /// En mode hors-ligne, retourne le cache même expiré.
  Future<Response> get(
    String path, {
    Map<String, dynamic>? params,
    Duration cacheTtl = CacheService.kShort,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(path, params);

    // 1. Essai réseau (sauf si on a du cache frais et pas de forceRefresh)
    if (!forceRefresh) {
      final cached = CacheService.get<dynamic>(cacheKey);
      if (cached != null) {
        // Cache frais → retourner directement sans appel réseau
        return Response(
          requestOptions: RequestOptions(path: path),
          data: cached,
          statusCode: 200,
        );
      }
    }

    try {
      final res = await _dio.get(path, queryParameters: params);
      // Mettre en cache la réponse
      await CacheService.set(cacheKey, res.data, ttl: cacheTtl);
      return res;
    } on DioException catch (e) {
      // Hors-ligne : retourner le cache même expiré
      final stale = CacheService.getStale<dynamic>(cacheKey);
      if (stale != null) {
        return Response(
          requestOptions: RequestOptions(path: path),
          data: stale,
          statusCode: 200,
          extra: {'fromCache': true, 'stale': true},
        );
      }
      rethrow;
    }
  }

  // ── POST / PATCH / DELETE avec queue hors-ligne ──────────────────────────
  Future<Response> post(String path, {dynamic data, bool queueIfOffline = false}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      if (queueIfOffline && _isOfflineError(e)) {
        _queueAction('POST', path, data);
        return _offlineResponse();
      }
      rethrow;
    }
  }

  Future<Response> patch(String path, {dynamic data, bool queueIfOffline = false}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      if (queueIfOffline && _isOfflineError(e)) {
        _queueAction('PATCH', path, data);
        return _offlineResponse();
      }
      rethrow;
    }
  }

  Future<Response> delete(String path) => _dio.delete(path);

  /// Upload multipart — timeout plus long sur 3G
  Future<Response> uploadFile(String path, FormData formData) => _dio.post(
    path,
    data: formData,
    options: Options(
      contentType: 'multipart/form-data',
      receiveTimeout: const Duration(minutes: 3),
      sendTimeout: const Duration(minutes: 3),
    ),
    onSendProgress: (sent, total) {
      // Progression visible (utile sur 3G lent)
    },
  );

  // ── Rejouer la queue quand la connexion revient ───────────────────────────
  Future<void> replayOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    final toReplay = List<_QueuedAction>.from(_offlineQueue);
    _offlineQueue.clear();

    for (final action in toReplay) {
      try {
        if (action.method == 'POST') {
          await _dio.post(action.path, data: action.data);
        } else if (action.method == 'PATCH') {
          await _dio.patch(action.path, data: action.data);
        }
      } catch (_) {
        // Si encore en échec, remettre dans la queue
        _offlineQueue.add(action);
      }
    }
  }

  int get pendingActionsCount => _offlineQueue.length;

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _cacheKey(String path, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return 'cache:$path';
    final sorted = Map.fromEntries(params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key)));
    return 'cache:$path?${sorted.entries.map((e) => '${e.key}=${e.value}').join('&')}';
  }

  bool _isOfflineError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.unknown;

  void _queueAction(String method, String path, dynamic data) {
    _offlineQueue.add(_QueuedAction(
      method: method, path: path,
      data: data, queuedAt: DateTime.now(),
    ));
  }

  Response _offlineResponse() => Response(
    requestOptions: RequestOptions(path: ''),
    data: {'offline': true, 'queued': true},
    statusCode: 200,
    extra: {'offline': true},
  );
}

class _QueuedAction {
  final String method;
  final String path;
  final dynamic data;
  final DateTime queuedAt;
  _QueuedAction({required this.method, required this.path, required this.data, required this.queuedAt});
}

// ─── Intercepteur de retry ─────────────────────────────────────────────────────
class _RetryInterceptor extends Interceptor {
  final Dio dio;
  final int retries;
  _RetryInterceptor(this.dio, {this.retries = 3});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['retryCount'] as int?) ?? 0;
    final shouldRetry = attempt < retries &&
        (err.type == DioExceptionType.connectionTimeout ||
         err.type == DioExceptionType.receiveTimeout ||
         err.type == DioExceptionType.sendTimeout ||
         err.response?.statusCode == 503 ||
         err.response?.statusCode == 502);

    if (shouldRetry) {
      await Future.delayed(Duration(seconds: 1 << attempt)); // backoff exponentiel
      err.requestOptions.extra['retryCount'] = attempt + 1;
      try {
        final retryResp = await dio.fetch(err.requestOptions);
        return handler.resolve(retryResp);
      } catch (_) {}
    }
    handler.next(err);
  }
}
