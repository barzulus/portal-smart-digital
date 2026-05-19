import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import 'auth_interceptor.dart';
import '../storage/secure_storage_service.dart';

/// Provider for the Dio client instance
final dioClientProvider = Provider<DioClient>((ref) {
  final storageService = ref.watch(secureStorageServiceProvider);
  return DioClient(storageService: storageService);
});

/// Configured Dio HTTP client for Supabase REST API
class DioClient {
  late final Dio dio;
  final SecureStorageService storageService;

  DioClient({required this.storageService}) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.restBaseUrl,
        connectTimeout: const Duration(
          milliseconds: ApiConstants.connectTimeout,
        ),
        receiveTimeout: const Duration(
          milliseconds: ApiConstants.receiveTimeout,
        ),
        sendTimeout: const Duration(milliseconds: ApiConstants.sendTimeout),
        headers: {
          'apikey': ApiConstants.supabaseAnonKey,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
      ),
    );

    // Add interceptors. LogInterceptor hanya aktif di debug build —
    // request body/URL bisa berisi password (custom auth via /users) atau
    // token, jadi JANGAN aktifkan di release.
    dio.interceptors.add(AuthInterceptor(storageService: storageService));
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('🌐 DIO: $obj'),
        ),
      );
    }
  }

  /// Create a separate Dio instance for Auth API calls
  Dio get authDio {
    final authDio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.authBaseUrl,
        connectTimeout: const Duration(
          milliseconds: ApiConstants.connectTimeout,
        ),
        receiveTimeout: const Duration(
          milliseconds: ApiConstants.receiveTimeout,
        ),
        headers: {
          'apikey': ApiConstants.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
      ),
    );

    if (kDebugMode) {
      authDio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('🔐 AUTH: $obj'),
        ),
      );
    }

    return authDio;
  }

  // ── Convenience Methods ──

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await dio.patch(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await dio.delete(path, queryParameters: queryParameters);
  }
}
