import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import 'auth_provider.dart';

/// Endpoint tabel `guru_staff` (FK banyak tabel operasional).
const String _guruStaffTable = '/guru_staff';

/// Resolve id dari tabel `guru_staff` untuk user yang sedang login.
///
/// DB catatan: `users.id` ≠ `guru_staff.id`. Banyak tabel operasional
/// (`absensi.id_guru`, `guru_absensi.id_guru`, `tugas_harian.teacher_id`,
/// `materi_ajar.id_guru`, dst.) punya FK ke `guru_staff(id)`. Jadi saat
/// insert harus pakai id ini, bukan `users.id`.
///
/// Lookup dilakukan via email (satu-satunya kolom unik yang overlap antara
/// `users` dan `guru_staff`). Di-cache per session lewat Riverpod.
final currentGuruStaffIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return null;

  final idSekolah = user.idSekolah;
  final email = user.email.trim();
  if (idSekolah == null || email.isEmpty) return null;

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      _guruStaffTable,
      queryParameters: {
        'email': 'eq.$email',
        'id_sekolah': 'eq.$idSekolah',
        'select': 'id',
        'limit': '1',
      },
    );
    final List data = res.data is List ? res.data : [];
    if (data.isEmpty) return null;
    return (data.first as Map<String, dynamic>)['id']?.toString();
  } on DioException {
    return null;
  }
});

/// Resolve foto profil guru dari bucket `guru-photos/{id_sekolah}/`.
///
/// Naming convention file: `guru_{guru_staff_id}_{timestamp}.{ext}`
/// Kita list file di bucket yang prefix-nya match `guru_{id}` lalu ambil yang terbaru.
final guruPhotoUrlProvider = FutureProvider<String?>((ref) async {
  final guruStaffId = await ref.watch(currentGuruStaffIdProvider.future);
  final user = ref.watch(authProvider).user;
  if (guruStaffId == null || user == null) return null;

  // Jika user sudah punya avatar_url (dari users.foto_profile), pakai itu
  if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
    final url = user.avatarUrl!;
    // Jika sudah full URL, return langsung
    if (url.startsWith('http')) return url;
    // Jika hanya filename, construct full URL
    final idSekolah = user.idSekolah ?? '';
    return '${ApiConstants.supabaseUrl}/storage/v1/object/public/guru-photos/$idSekolah/$url';
  }

  final idSekolah = user.idSekolah;
  if (idSekolah == null) return null;

  try {
    // List files di bucket guru-photos/{id_sekolah}/ yang match prefix
    final dio = Dio();
    final listUrl =
        '${ApiConstants.supabaseUrl}/storage/v1/object/list/guru-photos';
    final res = await dio.post(
      listUrl,
      data: {
        'prefix': '$idSekolah/',
        'search': 'guru_$guruStaffId',
      },
      options: Options(
        headers: {
          'apikey': ApiConstants.supabaseAnonKey,
          'Authorization': 'Bearer ${ApiConstants.supabaseAnonKey}',
        },
      ),
    );

    final List files = res.data is List ? res.data : [];
    // Cari file yang namanya mengandung guru_{guruStaffId}
    final prefix = 'guru_$guruStaffId';
    String? matchedFile;
    for (final file in files) {
      final name = file['name']?.toString() ?? '';
      if (name.startsWith(prefix)) {
        matchedFile = name;
        break;
      }
    }

    if (matchedFile == null) return null;

    return '${ApiConstants.supabaseUrl}/storage/v1/object/public/guru-photos/$idSekolah/$matchedFile';
  } catch (_) {
    return null;
  }
});
