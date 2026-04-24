import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../constants/storage_keys.dart';
import '../error/exceptions.dart';
import '../utils/navigation_service.dart';

/// Central HTTP client.  All features inject this instead of raw Dio.
/// Handles auth headers, token refresh, and maps HTTP errors to typed exceptions.
class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiClient({required Dio dio, required FlutterSecureStorage storage})
      : _dio = dio,
        _storage = storage {
    _dio.interceptors.add(_AuthInterceptor(_storage, _dio));
  }

  // ── Convenience wrappers ─────────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) =>
      _request(() => _dio.get(path, queryParameters: queryParams));

  Future<dynamic> post(String path, {dynamic body, Map<String, dynamic>? queryParams}) =>
      _request(() => _dio.post(path, data: body, queryParameters: queryParams));

  Future<dynamic> put(String path, {dynamic body}) =>
      _request(() => _dio.put(path, data: body));

  Future<dynamic> patch(String path, {dynamic body}) =>
      _request(() => _dio.patch(path, data: body));

  Future<dynamic> delete(String path) =>
      _request(() => _dio.delete(path));

  // ── Error mapper ─────────────────────────────────────────────────────────────

  Future<dynamic> _request(Future<Response> Function() call) async {
    try {
      final response = await call();
      final body = response.data;
      // Backend always wraps: {"success": bool, "message": str, "data": ...}
      if (body is Map && body['success'] == false) {
        throw ServerException(message: body['message'] ?? 'Server error');
      }
      return body['data'];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const NetworkException();
      }
      final statusCode = e.response?.statusCode;
      final message = (e.response?.data is Map)
          ? (e.response!.data['detail'] ?? e.response!.data['message'] ?? e.message)
          : e.message ?? 'Unknown error';
      if (statusCode == 401) throw AuthenticationException(message: message ?? 'Unauthorized');
      if (statusCode == 422) throw ValidationException(message: message ?? 'Validation error');
      throw ServerException(message: message ?? 'Server error', statusCode: statusCode);
    }
  }
}

// ── Auth Interceptor ──────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._storage, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: StorageKeys.accessToken);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshed = await _refreshTokens();
        if (refreshed) {
          // Retry the original request with the new token
          final token = await _storage.read(key: StorageKeys.accessToken);
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $token';
          final response = await _dio.fetch(opts);
          _isRefreshing = false;
          return handler.resolve(response);
        }
        // Refresh token missing or expired — clear session and redirect
        await _storage.delete(key: StorageKeys.accessToken);
        await _storage.delete(key: StorageKeys.refreshToken);
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (_) => false);
      } catch (_) {
        // Refresh call threw — clear session and redirect to login
        await _storage.delete(key: StorageKeys.accessToken);
        await _storage.delete(key: StorageKeys.refreshToken);
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (_) => false);
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = await _storage.read(key: StorageKeys.refreshToken);
    if (refreshToken == null) return false;

    // Use a clean Dio instance (no interceptors) to avoid infinite loop
    final cleanDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
    final response = await cleanDio.post(
      ApiConstants.refreshToken,
      data: {'refresh_token': refreshToken},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'];
      await _storage.write(key: StorageKeys.accessToken, value: data['access_token']);
      await _storage.write(key: StorageKeys.refreshToken, value: data['refresh_token']);
      return true;
    }
    return false;
  }
}
