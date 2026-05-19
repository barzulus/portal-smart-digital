import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/network/dio_client.dart';
import '../models/class_attendance_models.dart';

/// Repository untuk semua akses tabel `absensi`.
///
/// Wajib filter `id_sekolah` di semua query baca — karena RLS belum aktif,
/// isolasi multi-tenant dijaga di sini.
class AbsensiRepository {
  final DioClient _dio;

  AbsensiRepository(this._dio);

  /// Ambil riwayat absensi untuk satu sesi tertentu (jadwal + tanggal + tipe).
  /// Include nama_siswa via PostgREST embed: `students(nama_siswa,nis)`.
  Future<List<AbsensiRecord>> getSessionRecords({
    required String idSekolah,
    required String idJadwal,
    required String tanggal,
    required TipeAbsensi tipe,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.absensiTable,
        queryParameters: {
          'id_sekolah': 'eq.$idSekolah',
          'id_jadwal': 'eq.$idJadwal',
          'tanggal_absensi': 'eq.$tanggal',
          'tipe_absensi': 'eq.${tipe.value}',
          'select': '*,students:id_siswa(nama_siswa,nis)',
          'order': 'jam_absensi.asc',
        },
      );

      final List data = response.data is List ? response.data : [];
      return data
          .map((raw) => AbsensiRecord.fromJson(raw as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw AttendanceException(
        AttendanceErrorCode.network,
        'Gagal memuat riwayat sesi: ${e.message ?? 'unknown'}',
      );
    }
  }

  /// Simpan record absensi baru. Mengembalikan record dengan id yang terisi.
  /// Melempar AttendanceException(duplicate) jika unique constraint violated.
  Future<AbsensiRecord> createRecord(AbsensiRecord record) async {
    try {
      final response = await _dio.post(
        ApiConstants.absensiTable,
        data: record.toInsertJson(),
      );

      final data = response.data;
      if (data is List && data.isNotEmpty) {
        final saved = AbsensiRecord.fromJson(data.first as Map<String, dynamic>);
        return saved.copyWith(
          namaSiswa: record.namaSiswa,
          nisSiswa: record.nisSiswa,
        );
      }
      if (data is Map<String, dynamic>) {
        final saved = AbsensiRecord.fromJson(data);
        return saved.copyWith(
          namaSiswa: record.namaSiswa,
          nisSiswa: record.nisSiswa,
        );
      }
      // Fallback: backend tidak kembali representation.
      return record;
    } on DioException catch (e) {
      // Supabase mengembalikan 409 untuk unique violation, atau 400 dengan
      // body { code: "23505", ... } untuk PostgreSQL duplicate.
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final isDuplicate = status == 409 ||
          (body is Map && body['code']?.toString() == '23505');
      if (isDuplicate) {
        throw AttendanceException(
          AttendanceErrorCode.duplicate,
          'Siswa sudah diabsen pada sesi ini.',
        );
      }
      throw AttendanceException(
        AttendanceErrorCode.network,
        'Gagal menyimpan absensi: ${e.message ?? 'unknown'}',
      );
    }
  }

  /// Hapus record — dipakai untuk fitur "undo" swipe-to-dismiss.
  Future<void> deleteRecord({
    required String id,
    required String idSekolah,
  }) async {
    try {
      await _dio.delete(
        ApiConstants.absensiTable,
        queryParameters: {
          'id': 'eq.$id',
          'id_sekolah': 'eq.$idSekolah',
        },
      );
    } on DioException catch (e) {
      throw AttendanceException(
        AttendanceErrorCode.network,
        'Gagal membatalkan: ${e.message ?? 'unknown'}',
      );
    }
  }
}

final absensiRepositoryProvider = Provider<AbsensiRepository>((ref) {
  return AbsensiRepository(ref.watch(dioClientProvider));
});
