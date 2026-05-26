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
      // Trim input dulu — user kadang input dengan trailing spaces.
      final kodeTrimmed = kodeSekolah.trim();
      final normalizedEmail = email.trim().toLowerCase();

      if (kodeTrimmed.isEmpty || normalizedEmail.isEmpty || password.isEmpty) {
        throw const AuthException(
          message: 'Kode sekolah, email, dan password wajib diisi.',
        );
      }

      // 1. Validasi Kode Sekolah. Ambil `id` (UUID) dan `id_sekolah` (kode
      //    text). Filter pakai `id_sekolah` text yang diketik user.
      final schoolResponse = await dioClient.get(
        '/schools',
        queryParameters: {
          'id_sekolah': 'eq.$kodeTrimmed',
          'select': 'id,id_sekolah',
        },
      );

      final List schoolData =
          schoolResponse.data is List ? schoolResponse.data : [];
      if (schoolData.isEmpty) {
        throw const AuthException(
            message: 'Kode sekolah tidak valid atau tidak terdaftar.');
      }
      final schoolUuid = schoolData.first['id']?.toString();
      final schoolKode = schoolData.first['id_sekolah']?.toString();

      // 2. Query users by email saja. Email punya UNIQUE constraint di DB
      //    sehingga tidak perlu filter sekolah di sini. Sebagian row di
      //    tabel `users` punya `id_sekolah` null (tidak konsisten di-populate
      //    untuk semua role) — kalau kita filter pakai itu, login bakal
      //    selalu gagal walau credential benar. Verifikasi keanggotaan
      //    sekolah dilakukan pasca-login lewat tabel role-spesifik
      //    (students / guru_staff) di repository.
      //    Password DIBANDINGKAN DI CLIENT supaya tidak pernah jadi bagian
      //    URL/log.
      final response = await dioClient.get(
        ApiConstants.usersTable,
        queryParameters: {
          'email': 'eq.$normalizedEmail',
          'select': '*',
          'limit': '1',
        },
      );

      final List data = response.data is List ? response.data : [];

      const credErr = AuthException(
        message:
            'Email atau password salah, atau Anda tidak terdaftar di sekolah ini.',
      );

      if (data.isEmpty) throw credErr;

      final user = data.first as Map<String, dynamic>;
      final storedHash = user['password_hash']?.toString() ?? '';

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

      return {
        'access_token': 'simulated_jwt_${user['id']}',
        'refresh_token': null,
        'user': {
          'id': user['id'],
          'email': user['email'],
          'name': user['nama_user'] ?? user['email'],
          'role': mappedRole,
          'avatar_url': user['foto_profile'],
          // `id_sekolah` di payload user kita pakai kode text (`SCH0005`)
          // — itu yang dipakai semua query downstream (students, jadwal, dll).
          'id_sekolah': schoolKode,
          'school_uuid': schoolUuid,
          'created_at': user['created_at'],
        },
      };
    } on AuthException {
      // Kalau sudah AuthException (kode sekolah salah / kredensial salah),
      // lempar lagi tanpa di-wrap jadi ServerException.
      rethrow;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException(
          message: 'Koneksi timeout. Coba lagi nanti.',
        );
      }
      // Translate beberapa status umum ke pesan user-friendly.
      final status = e.response?.statusCode;
      if (status == 400) {
        throw const ServerException(
          message:
              'Format input tidak valid. Pastikan kode sekolah, email, '
              'dan password Anda benar.',
          statusCode: 400,
        );
      }
      if (status == 401 || status == 403) {
        throw const ServerException(
          message:
              'Akses ke server ditolak. Hubungi admin sekolah untuk '
              'memeriksa konfigurasi izin database.',
          statusCode: 401,
        );
      }
      if (status == 404) {
        throw const ServerException(
          message: 'Endpoint tidak ditemukan. Hubungi admin sekolah.',
          statusCode: 404,
        );
      }
      throw ServerException(
        message: 'Gagal login. ${e.message ?? 'Periksa koneksi internet Anda.'}',
        statusCode: status,
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
