import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/offline_cache_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../schedule/providers/schedule_provider.dart';

/// Model for student data from Supabase
class StudentData {
  final String id;
  final String nis;
  final String nisn;
  final String namaSiswa;
  final String jenisKelamin;
  final String alamat;
  final String tempatLahir;
  final String tanggalLahir;
  final String? namaOrangTua;
  final String? noTelpOrangTua;
  final String kelas;

  StudentData({
    required this.id,
    required this.nis,
    required this.nisn,
    required this.namaSiswa,
    required this.jenisKelamin,
    required this.alamat,
    required this.tempatLahir,
    required this.tanggalLahir,
    this.namaOrangTua,
    this.noTelpOrangTua,
    required this.kelas,
  });

  factory StudentData.fromJson(Map<String, dynamic> json) {
    return StudentData(
      id: json['id']?.toString() ?? '',
      nis: json['nis']?.toString() ?? '',
      nisn: json['nisn']?.toString() ?? '',
      namaSiswa: json['nama_siswa']?.toString() ?? '',
      jenisKelamin: json['jenis_kelamin']?.toString() ?? '',
      alamat: json['alamat']?.toString() ?? '-',
      tempatLahir: json['tempat_lahir']?.toString() ?? '-',
      tanggalLahir: json['tanggal_lahir']?.toString() ?? '-',
      namaOrangTua: json['nama_orang_tua']?.toString(),
      noTelpOrangTua: json['no_telp_orang_tua']?.toString(),
      kelas: json['kelas']?.toString() ?? '-',
    );
  }
}

/// Provider that fetches students for the current school.
/// Always filters by `id_sekolah` to keep multi-tenant isolation.
final studentsProvider = FutureProvider<List<StudentData>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  if (idSekolah == null) return const [];

  final cache = ref.watch(offlineCacheServiceProvider);
  final cacheKey = 'students_$idSekolah';

  try {
    final dioClient = ref.watch(dioClientProvider);
    final response = await dioClient.get(
      ApiConstants.studentsTable,
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'select': '*',
        'order': 'nama_siswa.asc',
      },
    );

    if (response.data == null) {
      return [];
    }

    final List data = response.data is List ? response.data : [];
    // Cache the raw response
    await cache.cacheResponse(cacheKey, jsonEncode(data));
    return data
        .map((json) => StudentData.fromJson(json as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    // Offline — try cache
    final cached = await cache.getCachedResponse(cacheKey);
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      return decoded
          .map((json) => StudentData.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw Exception('Koneksi timeout. Periksa jaringan Anda.');
    }
    if (e.response?.statusCode == 404) {
      throw Exception('Tabel siswa belum tersedia di database.');
    }
    if (e.response?.statusCode == 401) {
      throw Exception('Sesi telah berakhir. Silakan login kembali.');
    }
    throw Exception(
      'Gagal memuat data siswa: ${e.message ?? 'Kesalahan server'}',
    );
  } catch (e) {
    throw Exception('Terjadi kesalahan: $e');
  }
});

/// Normalisasi nama kelas untuk matching lintas sumber data.
/// Contoh: "XI DKV" vs "XI-DKV" vs "xi dkv" → semua jadi "XIDKV".
String _normalizeKelas(String s) =>
    s.toUpperCase().replaceAll(RegExp(r'[\s\-_/.]+'), '');

/// Provider that returns ONLY students from classes the teacher teaches.
/// Matching kelas dilakukan dengan normalisasi supaya tahan terhadap
/// variasi spasi/dash/case antara `jadwal_pelajaran_v2.kelas` dan
/// `students.kelas`.
final myStudentsProvider = Provider<AsyncValue<List<StudentData>>>((ref) {
  final allStudents = ref.watch(studentsProvider);
  final teacherClasses = ref.watch(teacherClassesProvider);

  return teacherClasses.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (classes) {
      if (classes.isEmpty) {
        return const AsyncValue.data([]);
      }
      return allStudents.whenData((students) {
        final normalized = classes.map(_normalizeKelas).toSet();
        return students
            .where((s) => normalized.contains(_normalizeKelas(s.kelas)))
            .toList();
      });
    },
  );
});
