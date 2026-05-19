import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/user_model.dart';

/// Remote data source for authentication — Supabase REST via Dio.
///
/// ⚠️ SECURITY DEBT — login dilakukan dengan query langsung ke tabel `users`
/// (custom auth), BUKAN Supabase Auth. Konsekuensinya:
///   1. `access_token` yang dikembalikan adalah JWT simulasi
///      (`simulated_jwt_<uuid>`) → RLS `auth.uid()` tidak bisa jalan.
///   2. Password dikirim **plaintext** sebagai query string ke PostgREST,
///      sehingga bisa muncul di log proxy / Dio interceptor logs.
///   3. Perbandingan password pakai string-equal di SQL — rentan terhadap
///      timing attack walau di backend Postgres.
///
/// Migrasi yang direkomendasikan (urutan):
///   a. Pindah ke Supabase Auth (`/auth/v1/token?grant_type=password`).
///   b. Hash semua password existing di DB (bcrypt/argon2) lewat migration.
///   c. Hash di client memakai algoritma yang sama sebelum kirim.
///
/// Sampai migrasi dilakukan, JANGAN aktifkan logging request body/URL untuk
/// endpoint /users di production.
class AuthRemoteDataSource {
  final DioClient dioClient;

  AuthRemoteDataSource({required this.dioClient});

  /// Login by querying the public users table, memvalidasi kode sekolah dulu.
  Future<Map<String, dynamic>> login({
    required String kodeSekolah,
    required String email,
    required String password,
  }) async {
    try {
      // 1. Validasi Kode Sekolah dan ambil id_sekolah
      final schoolResponse = await dioClient.get(
        '/schools',
        queryParameters: {
          'id_sekolah': 'eq.$kodeSekolah',
          'select': 'id_sekolah',
        },
      );

      final List schoolData =
          schoolResponse.data is List ? schoolResponse.data : [];
      if (schoolData.isEmpty) {
        throw const AuthException(
            message: 'Kode sekolah tidak valid atau tidak terdaftar.');
      }
      final schoolId = schoolData.first['id_sekolah'];

      // 2. Query users table — TARIK by email + id_sekolah saja, password
      //    DIBANDINGKAN DI CLIENT supaya tidak pernah jadi bagian URL/log.
      //    (URL bisa ke-log di proxy / interceptor / crash report.)
      final normalizedEmail = email.trim().toLowerCase();
      final response = await dioClient.get(
        ApiConstants.usersTable,
        queryParameters: {
          'email': 'eq.$normalizedEmail',
          'id_sekolah': 'eq.$schoolId',
          'select': '*',
          'limit': '1',
        },
      );

      final List data = response.data is List ? response.data : [];

      // Pakai pesan yang sama untuk semua kegagalan kredensial supaya
      // tidak bocor info "email ada tapi password salah".
      const credErr = AuthException(
        message:
            'Email atau password salah, atau Anda tidak terdaftar di sekolah ini.',
      );

      if (data.isEmpty) throw credErr;

      final user = data.first as Map<String, dynamic>;
      final storedHash = user['password_hash']?.toString() ?? '';

      // Constant-time compare → tidak rentan terhadap timing attack.
      if (storedHash.isEmpty || !_constantTimeEquals(storedHash, password)) {
        throw credErr;
      }

      // Determine role safely
      final roleStr = (user['role']?.toString() ?? 'Siswa').toLowerCase();
      String mappedRole = 'murid';
      if (roleStr.contains('guru')) {
        mappedRole = 'guru';
      } else if (roleStr.contains('orang') || roleStr.contains('tua')) {
        mappedRole = 'orangtua';
      }

      // JWT simulasi — belum Supabase Auth asli.
      return {
        'access_token': 'simulated_jwt_${user['id']}',
        'refresh_token': null,
        'user': {
          'id': user['id'],
          'email': user['email'],
          'name': user['nama_user'] ?? user['email'],
          'role': mappedRole,
          'avatar_url': user['foto_profile'],
          'id_sekolah': schoolId?.toString(),
          'created_at': user['created_at'],
        },
      };
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException(
          message: 'Koneksi timeout. Coba lagi nanti.',
        );
      }
      throw ServerException(
        message: e.message ?? 'Gagal login.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Get current user.
  /// Saat ini tidak memverifikasi JWT ke Supabase Auth — cukup lempar error
  /// supaya repository fallback ke data lokal yang sudah di-cache di login.
  Future<UserModel> getUser(String accessToken) async {
    throw const ServerException(message: 'Use local cache', statusCode: 400);
  }

  /// Logout from Supabase Auth endpoint (no-op kalau token simulasi).
  Future<void> logout(String accessToken) async {
    if (accessToken.startsWith('simulated_jwt_')) return;

    try {
      final authDio = dioClient.authDio;
      authDio.options.headers['Authorization'] = 'Bearer $accessToken';
      await authDio.post(ApiConstants.logoutEndpoint);
    } on DioException catch (e) {
      throw ServerException(
        message: e.message ?? 'Gagal logout.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Konstan-time string comparison.
  ///
  /// Penting: panjang string sengaja **tidak** di-early-return supaya waktu
  /// eksekusi tidak bocorin info length. Tetap aman dipakai walau salah satu
  /// argumen lebih pendek — beda panjang akan ter-flag lewat XOR + length flag
  /// di akhir.
  static bool _constantTimeEquals(String a, String b) {
    final ab = a.codeUnits;
    final bb = b.codeUnits;
    final len = ab.length > bb.length ? ab.length : bb.length;
    var diff = ab.length ^ bb.length;
    for (var i = 0; i < len; i++) {
      final x = i < ab.length ? ab[i] : 0;
      final y = i < bb.length ? bb[i] : 0;
      diff |= x ^ y;
    }
    return diff == 0;
  }
}
