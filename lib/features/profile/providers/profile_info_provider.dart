import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/domain/entities/user_entity.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Data lengkap profil user yang ditampilkan di halaman Info Profil.
/// Field-field yang tersedia tergantung role:
///
/// - Murid: dari tabel `students` (NIS, NISN, alamat, ortu, dll).
/// - Guru: dari tabel `guru_staff` (NIP, jabatan, no_telp, dll).
/// - Lainnya: cuma data dasar dari `users`.
class ProfileInfo {
  // Identitas dasar (selalu ada).
  final String namaLengkap;
  final String email;
  final String role;
  final String? avatarUrl;

  // Field role-specific (nullable).
  final Map<String, String?> details;

  const ProfileInfo({
    required this.namaLengkap,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.details = const {},
  });
}

/// Lookup data profil berdasarkan role user yang sedang login.
/// Match by email + id_sekolah ke tabel role-specific (students /
/// guru_staff). Kalau tidak ketemu, fallback ke data dasar dari `users`.
final profileInfoProvider = FutureProvider<ProfileInfo>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) {
    throw Exception('User tidak ditemukan. Silakan login ulang.');
  }

  // Default fallback — kalau tidak ada match di tabel detail.
  final fallback = ProfileInfo(
    namaLengkap: user.name,
    email: user.email,
    role: user.role.displayName,
    avatarUrl: user.avatarUrl,
  );

  final dio = ref.watch(dioClientProvider);

  switch (user.role) {
    case UserRole.murid:
      return _fetchStudent(dio, user, fallback);
    case UserRole.guru:
      return _fetchGuru(dio, user, fallback);
    case UserRole.orangtua:
      return fallback;
  }
});

Future<ProfileInfo> _fetchStudent(
  DioClient dio,
  UserEntity user,
  ProfileInfo fallback,
) async {
  if (user.idSekolah == null) return fallback;
  try {
    final res = await dio.get(
      ApiConstants.studentsTable,
      queryParameters: {
        'email': 'eq.${user.email}',
        'id_sekolah': 'eq.${user.idSekolah}',
        'select': '*',
        'limit': '1',
      },
    );
    final List data = res.data is List ? res.data : [];
    if (data.isEmpty) return fallback;
    final s = data.first as Map<String, dynamic>;
    return ProfileInfo(
      namaLengkap: s['nama_siswa']?.toString() ?? user.name,
      email: s['email']?.toString() ?? user.email,
      role: 'Siswa',
      avatarUrl: s['foto_profile']?.toString() ?? user.avatarUrl,
      details: {
        'NIS': s['nis']?.toString(),
        'NISN': s['nisn']?.toString(),
        'Kelas': s['kelas']?.toString(),
        'Jenis Kelamin': s['jenis_kelamin']?.toString(),
        'Tempat Lahir': s['tempat_lahir']?.toString(),
        'Tanggal Lahir': s['tanggal_lahir']?.toString(),
        'Alamat': s['alamat']?.toString(),
        'Nama Orang Tua': s['nama_orang_tua']?.toString(),
        'No. Telp Orang Tua': s['no_telp_orang_tua']?.toString(),
      },
    );
  } on DioException {
    return fallback;
  }
}

Future<ProfileInfo> _fetchGuru(
  DioClient dio,
  UserEntity user,
  ProfileInfo fallback,
) async {
  if (user.idSekolah == null) return fallback;
  try {
    final res = await dio.get(
      '/guru_staff',
      queryParameters: {
        'email': 'eq.${user.email}',
        'id_sekolah': 'eq.${user.idSekolah}',
        'select': '*',
        'limit': '1',
      },
    );
    final List data = res.data is List ? res.data : [];
    if (data.isEmpty) return fallback;
    final g = data.first as Map<String, dynamic>;
    return ProfileInfo(
      namaLengkap: g['nama']?.toString() ?? user.name,
      email: g['email']?.toString() ?? user.email,
      role: g['jabatan']?.toString() ?? 'Guru',
      avatarUrl: user.avatarUrl,
      details: {
        'NIP': g['nip']?.toString(),
        'Jabatan': g['jabatan']?.toString(),
        'No. Telp': g['no_telp']?.toString(),
        'Status': g['status']?.toString(),
      },
    );
  } on DioException {
    return fallback;
  }
}
