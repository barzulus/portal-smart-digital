import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

/// Interceptor yang attach token ke setiap request.
///
/// Karena aplikasi pakai custom auth (bukan Supabase Auth), token yang
/// disimpan di secure storage adalah placeholder seperti `simulated_jwt_*`
/// atau `mock_jwt_*` — bukan JWT Supabase Auth asli. Untuk request semacam
/// itu kita FALLBACK ke publishable anon key di header `Authorization` agar
/// PostgREST tetap men-resolve role anon dengan benar.
///
/// Catatan: walau publishable key (`sb_publishable_*`) bukan JWT, Supabase
/// menerimanya pada header `Authorization: Bearer <key>` untuk role anon.
/// Pola lama ini terbukti bekerja; jangan dihapus tanpa migrasi penuh ke
/// Supabase Auth.
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
      // JWT asli dari Supabase Auth → set sebagai Bearer.
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      // Simulated / no JWT → pakai publishable anon key sebagai Bearer.
      // PostgREST akan resolve role `anon` dari kombinasi header `apikey`
      // + `Authorization`. Tanpa Authorization sama sekali request bisa
      // ditolak 400 oleh konfigurasi Supabase tertentu.
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
