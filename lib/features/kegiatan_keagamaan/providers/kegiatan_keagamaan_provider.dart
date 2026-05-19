import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../auth/presentation/providers/guru_staff_provider.dart';

// ═══════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════

/// Daftar kegiatan keagamaan yang tersedia.
const List<String> kegiatanKeagamaanOptions = [
  'Iqro',
  'Muhadharah',
  'Sholat Dhuha',
  'Tahfidz Quran',
  'Tahsin Quran',
];

/// Daftar status kegiatan.
const List<String> statusKeagamaanOptions = [
  'Belum Selesai',
  'Sedang Berlangsung',
  'Selesai',
  'Lulus',
  'Tidak Lulus',
];

// ═══════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════

/// Master kegiatan keagamaan (dari tabel `kegiatan_keagamaan`).
class KegiatanKeagamaan {
  final String id;
  final String? idSekolah;
  final String namaKegiatan;
  final String? deskripsi;
  final DateTime? tanggal;
  final String? waktu;
  final String? lokasi;
  final String status;
  final DateTime createdAt;

  const KegiatanKeagamaan({
    required this.id,
    this.idSekolah,
    required this.namaKegiatan,
    this.deskripsi,
    this.tanggal,
    this.waktu,
    this.lokasi,
    required this.status,
    required this.createdAt,
  });

  factory KegiatanKeagamaan.fromJson(Map<String, dynamic> json) {
    return KegiatanKeagamaan(
      id: json['id']?.toString() ?? '',
      idSekolah: json['id_sekolah']?.toString(),
      namaKegiatan: json['nama_kegiatan']?.toString() ?? '',
      deskripsi: json['deskripsi']?.toString(),
      tanggal: json['tanggal'] != null ? DateTime.tryParse(json['tanggal'].toString()) : null,
      waktu: json['waktu']?.toString(),
      lokasi: json['lokasi']?.toString(),
      status: json['status']?.toString() ?? 'Terjadwal',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

/// Record kegiatan keagamaan per siswa.
class KegiatanKeagamaanSiswa {
  final String id;
  final String idSekolah;
  final String? idGuru;
  final String? idKelas;
  final String idSiswa;
  final String idKegiatanKeagamaan;
  final String? namaSurah;
  final int? nomorAyat;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? namaSiswa;
  final String? namaKegiatan;
  final String? namaKelas;

  const KegiatanKeagamaanSiswa({
    required this.id,
    required this.idSekolah,
    this.idGuru,
    this.idKelas,
    required this.idSiswa,
    required this.idKegiatanKeagamaan,
    this.namaSurah,
    this.nomorAyat,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.namaSiswa,
    this.namaKegiatan,
    this.namaKelas,
  });

  factory KegiatanKeagamaanSiswa.fromJson(Map<String, dynamic> json) {
    String? namaSiswa;
    if (json['students'] is Map) {
      namaSiswa = (json['students'] as Map)['nama_siswa']?.toString();
    }
    String? namaKegiatan;
    if (json['kegiatan_keagamaan'] is Map) {
      namaKegiatan = (json['kegiatan_keagamaan'] as Map)['nama_kegiatan']?.toString();
    }
    String? namaKelas;
    if (json['kelas'] is Map) {
      namaKelas = (json['kelas'] as Map)['nama_kelas']?.toString();
    }

    return KegiatanKeagamaanSiswa(
      id: json['id']?.toString() ?? '',
      idSekolah: json['id_sekolah']?.toString() ?? '',
      idGuru: json['id_guru']?.toString(),
      idKelas: json['id_kelas']?.toString(),
      idSiswa: json['id_siswa']?.toString() ?? '',
      idKegiatanKeagamaan: json['id_kegiatan_keagamaan']?.toString() ?? '',
      namaSurah: json['nama_surah']?.toString(),
      nomorAyat: int.tryParse(json['nomor_ayat']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'Belum Selesai',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      namaSiswa: namaSiswa,
      namaKegiatan: namaKegiatan,
      namaKelas: namaKelas,
    );
  }

  Color get statusColor {
    switch (status) {
      case 'Selesai':
      case 'Lulus':
        return const Color(0xFF2E7D32);
      case 'Sedang Berlangsung':
        return const Color(0xFF1565C0);
      case 'Tidak Lulus':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFF9A825);
    }
  }
}

/// Model kelas sederhana.
class KelasData {
  final String id;
  final String namaKelas;
  final String tingkat;

  const KelasData({required this.id, required this.namaKelas, required this.tingkat});

  factory KelasData.fromJson(Map<String, dynamic> json) {
    return KelasData(
      id: json['id']?.toString() ?? '',
      namaKelas: json['nama_kelas']?.toString() ?? '',
      tingkat: json['tingkat']?.toString() ?? '',
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════

/// Fetch master kegiatan keagamaan sekolah.
final kegiatanKeagamaanListProvider = FutureProvider<List<KegiatanKeagamaan>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  if (idSekolah == null) return const [];

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      ApiConstants.kegiatanKeagamaanTable,
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'select': '*',
        'order': 'created_at.desc',
      },
    );

    final List data = res.data is List ? res.data : [];
    return data
        .map((json) => KegiatanKeagamaan.fromJson(json as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat kegiatan: ${e.message ?? 'tidak diketahui'}');
  }
});

/// Fetch daftar kelas sekolah.
final kelasListProvider = FutureProvider<List<KelasData>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  if (idSekolah == null) return const [];

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      ApiConstants.kelasTable,
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'select': 'id,nama_kelas,tingkat',
        'order': 'tingkat.asc,nama_kelas.asc',
      },
    );

    final List data = res.data is List ? res.data : [];
    return data
        .map((json) => KelasData.fromJson(json as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat kelas: ${e.message ?? 'tidak diketahui'}');
  }
});

/// Fetch record kegiatan keagamaan siswa (guru yang login).
final kegiatanKeagamaanSiswaProvider =
    FutureProvider<List<KegiatanKeagamaanSiswa>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  final guruStaffId = await ref.watch(currentGuruStaffIdProvider.future);
  if (idSekolah == null || guruStaffId == null) return const [];

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      ApiConstants.kegiatanKeagamaanSiswaTable,
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'id_guru': 'eq.$guruStaffId',
        'select': '*,students(nama_siswa),kegiatan_keagamaan(nama_kegiatan),kelas(nama_kelas)',
        'order': 'created_at.desc',
      },
    );

    final List data = res.data is List ? res.data : [];
    return data
        .map((json) => KegiatanKeagamaanSiswa.fromJson(json as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat data: ${e.message ?? 'tidak diketahui'}');
  }
});

// ═══════════════════════════════════════════════════════════════
// NOTIFIER (CRUD)
// ═══════════════════════════════════════════════════════════════

class KegiatanKeagamaanSiswaNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  KegiatanKeagamaanSiswaNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Check if device is online.
  static Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createRecord({
    required String idSiswa,
    required String idKegiatanKeagamaan,
    String? idKelas,
    String? namaSurah,
    int? nomorAyat,
    required String status,
  }) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      final idSekolah = _ref.read(currentIdSekolahProvider);
      final guruStaffId = await _ref.read(currentGuruStaffIdProvider.future);
      if (idSekolah == null || guruStaffId == null) {
        state = AsyncValue.error('Data guru/sekolah tidak ditemukan', StackTrace.current);
        return false;
      }

      final dio = _ref.read(dioClientProvider);
      await dio.post(
        ApiConstants.kegiatanKeagamaanSiswaTable,
        data: {
          'id_sekolah': idSekolah,
          'id_guru': guruStaffId,
          'id_kelas': idKelas,
          'id_siswa': idSiswa,
          'id_kegiatan_keagamaan': idKegiatanKeagamaan,
          'nama_surah': namaSurah,
          'nomor_ayat': nomorAyat,
          'status': status,
        },
      );

      _ref.invalidate(kegiatanKeagamaanSiswaProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateRecord({
    required String id,
    String? namaSurah,
    int? nomorAyat,
    required String status,
  }) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioClientProvider);
      await dio.patch(
        ApiConstants.kegiatanKeagamaanSiswaTable,
        queryParameters: {'id': 'eq.$id'},
        data: {
          'nama_surah': namaSurah,
          'nomor_ayat': nomorAyat,
          'status': status,
        },
      );

      _ref.invalidate(kegiatanKeagamaanSiswaProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteRecord(String id) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioClientProvider);
      await dio.delete(
        ApiConstants.kegiatanKeagamaanSiswaTable,
        queryParameters: {'id': 'eq.$id'},
      );

      _ref.invalidate(kegiatanKeagamaanSiswaProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final kegiatanKeagamaanSiswaNotifierProvider =
    StateNotifierProvider<KegiatanKeagamaanSiswaNotifier, AsyncValue<void>>((ref) {
  return KegiatanKeagamaanSiswaNotifier(ref);
});
