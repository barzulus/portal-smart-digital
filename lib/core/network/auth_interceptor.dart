import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

/// Interceptor yang attach JWT token ke setiap request.
///
/// Karena aplikasi saat ini pakai custom auth (bukan Supabase Auth), token
/// yang disimpan di secure storage adalah placeholder seperti
/// `simulated_jwt_*` atau `mock_jwt_*` (dari versi lama). Semuanya
/// di-treat sebagai "bukan JWT Supabase Auth asli" — di-fallback ke anon key
/// supaya PostgREST tetap menerima request.
class AuthInterceptor extends Interceptor {
  final SecureStorageService storageService;

  AuthInterceptor({required this.storageService});

  /// Prefix-prefix token yang kita ketahui BUKAN JWT Supabase Auth asli.
  static const _simulatedPrefixes = [
    'simulated_jwt_',
    'mock_jwt_',
  ];

  bool _isSimulatedToken(String token) {
    for (final p in _simulatedPrefixes) {
      if (token.startsWith(p)) return true;
    }
    // Fallback guard: JWT Supabase asli selalu punya 2 titik (`header.payload.sig`).
    // Kalau token kita tidak punya titik sama sekali, anggap placeholder.
    if (!token.contains('.')) return true;
    return false;
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storageService.getAccessToken();

    if (token != null && token.isNotEmpty && !_isSimulatedToken(token)) {
      // JWT asli dari Supabase Auth.
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      // Simulated / placeholder / tidak ada token → pakai anon key.
      // PostgREST butuh Authorization untuk role mapping; tanpa header
      // ini di Supabase mode tertentu request bisa ditolak 401.
      options.headers['Authorization'] =
          'Bearer ${ApiConstants.supabaseAnonKey}';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final isAuthEndpoint = path.contains('/auth/') || path == '/token';

    if (status == 401 && isAuthEndpoint) {
      // Hanya hapus token kalau yang gagal endpoint auth — artinya kredensial
      // memang invalid. Endpoint data yang 401 biasanya karena RLS; tidak
      // perlu auto-logout user.
      await storageService.deleteTokens();
    }

    handler.next(err);
  }
}
