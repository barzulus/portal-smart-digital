import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/network/dio_client.dart';
import '../models/class_attendance_models.dart';

/// Pemeta antara identitas mentah (NIS / UUID / RFID code) ke StudentLite.
/// Semua lookup selalu di-filter `id_sekolah` untuk isolasi multi-tenant.
class StudentResolver {
  final DioClient _dio;

  StudentResolver(this._dio);

  /// Resolve QR payload. Kalau payload berupa UUID → cari by id.
  /// Kalau digit → cari by NIS.
  Future<StudentLite> resolveQr({
    required String payload,
    required String idSekolah,
  }) async {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) {
      throw const AttendanceException(
        AttendanceErrorCode.qrInvalidFormat,
        'QR code kosong.',
      );
    }

    if (_uuidPattern.hasMatch(trimmed)) {
      return _findById(trimmed, idSekolah);
    }
    if (_digitsPattern.hasMatch(trimmed)) {
      return _findByNis(trimmed, idSekolah);
    }
    throw const AttendanceException(
      AttendanceErrorCode.qrInvalidFormat,
      'QR code tidak dikenali.',
    );
  }

  /// Resolve NIS dari input manual.
  Future<StudentLite> resolveNis({
    required String nis,
    required String idSekolah,
  }) async {
    final trimmed = nis.trim();
    if (trimmed.isEmpty) {
      throw const AttendanceException(
        AttendanceErrorCode.nisInvalid,
        'NIS tidak boleh kosong.',
      );
    }
    if (!_digitsPattern.hasMatch(trimmed)) {
      throw const AttendanceException(
        AttendanceErrorCode.nisInvalid,
        'NIS harus diisi dengan angka.',
      );
    }
    return _findByNis(trimmed, idSekolah);
  }

  /// Resolve RFID code → lookup rfid_codes (status aktif) → students.
  ///
  /// Aplikasi NFC reader pihak ketiga menampilkan UID dengan format yang
  /// berbeda-beda (hex upper/lower, dengan/tanpa separator, byte order
  /// dibalik, atau desimal). Untuk menghindari gagal match karena format,
  /// kita coba semua variasi umum dengan satu query `in.(...)`.
  Future<StudentLite> resolveRfid({
    required String rfidCode,
    required String idSekolah,
  }) async {
    final trimmed = rfidCode.trim();
    if (trimmed.isEmpty) {
      throw const AttendanceException(
        AttendanceErrorCode.rfidNotRegistered,
        'Kode RFID kosong.',
      );
    }

    final candidates = buildRfidCandidates(trimmed);

    try {
      final res = await _dio.get(
        ApiConstants.rfidCodesTable,
        queryParameters: {
          'rfid_code': 'in.(${candidates.join(',')})',
          'status': 'eq.active',
          'id_sekolah': 'eq.$idSekolah',
          'select': 'id_siswa',
          'limit': '1',
        },
      );

      final List list = res.data is List ? res.data : [];
      if (list.isEmpty) {
        throw const AttendanceException(
          AttendanceErrorCode.rfidNotRegistered,
          'Kartu RFID tidak terdaftar.',
        );
      }
      final idSiswa = (list.first as Map<String, dynamic>)['id_siswa']
          ?.toString();
      if (idSiswa == null || idSiswa.isEmpty) {
        throw const AttendanceException(
          AttendanceErrorCode.rfidNotRegistered,
          'Kartu RFID tidak terikat siswa.',
        );
      }
      return _findById(idSiswa, idSekolah);
    } on DioException catch (e) {
      throw AttendanceException(
        AttendanceErrorCode.network,
        'Gagal memvalidasi RFID: ${e.message ?? 'unknown'}',
      );
    }
  }

  /// Hasilkan daftar kandidat rfid_code dari satu UID raw supaya bisa
  /// match apapun format yang disimpan admin di database.
  ///
  /// Input yang diterima:
  ///   - hex upper/lower dengan/tanpa separator (`:`, `-`, spasi)
  ///   - desimal (angka murni)
  ///
  /// Output kandidat (de-dup) dibungkus kutip ganda untuk PostgREST
  /// `in.(...)` supaya aman walaupun mengandung `:` / `-` / `,`.
  static List<String> buildRfidCandidates(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s:\-]'), '').trim();
    if (cleaned.isEmpty) return const [];

    final set = <String>{raw.trim(), cleaned};

    if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleaned) && cleaned.length.isEven) {
      final hexUpper = cleaned.toUpperCase();
      final hexLower = cleaned.toLowerCase();
      set.add(hexUpper);
      set.add(hexLower);

      final bytes = [
        for (int i = 0; i < cleaned.length; i += 2) cleaned.substring(i, i + 2)
      ];
      final reversedUpper = bytes.reversed.join().toUpperCase();
      final reversedLower = reversedUpper.toLowerCase();
      set.add(reversedUpper);
      set.add(reversedLower);

      String withSep(String hex, String sep) {
        final b = [
          for (int i = 0; i < hex.length; i += 2) hex.substring(i, i + 2)
        ];
        return b.join(sep);
      }

      set.add(withSep(hexUpper, ':'));
      set.add(withSep(hexUpper, '-'));
      set.add(withSep(hexLower, ':'));
      set.add(withSep(hexLower, '-'));
      set.add(withSep(reversedUpper, ':'));
      set.add(withSep(reversedLower, ':'));

      try {
        final decBig = BigInt.parse(hexUpper, radix: 16).toString();
        final decLittle = BigInt.parse(reversedUpper, radix: 16).toString();
        set.add(decBig);
        set.add(decLittle);
        // 10 digit umum di reader Mifare Classic 4-byte UID.
        set.add(decBig.padLeft(10, '0'));
        set.add(decLittle.padLeft(10, '0'));
        // 8 hex chars (4 byte) — beberapa reader menampilkan tanpa leading zero.
        set.add(hexUpper.padLeft(8, '0'));
        set.add(hexLower.padLeft(8, '0'));
      } catch (_) {}
    }

    if (RegExp(r'^\d+$').hasMatch(cleaned)) {
      try {
        final big = BigInt.parse(cleaned);
        var hex = big.toRadixString(16).toUpperCase();
        if (hex.length.isOdd) hex = '0$hex';
        set.add(hex);
        set.add(hex.toLowerCase());
        final bytes = [
          for (int i = 0; i < hex.length; i += 2) hex.substring(i, i + 2)
        ];
        set.add(bytes.reversed.join());
        set.add(bytes.reversed.join().toLowerCase());
      } catch (_) {}

      // Juga simpan varian tanpa leading zero
      final noZero = cleaned.replaceFirst(RegExp(r'^0+'), '');
      if (noZero.isNotEmpty) set.add(noZero);
    }

    // Dibungkus kutip ganda → aman untuk nilai yang mengandung `:` / `-` / `,`.
    return set
        .where((s) => s.isNotEmpty)
        .map((s) => '"${s.replaceAll('"', r'\"')}"')
        .toList();
  }

  Future<StudentLite> _findByNis(String nis, String idSekolah) async {
    try {
      final res = await _dio.get(
        ApiConstants.studentsTable,
        queryParameters: {
          'nis': 'eq.$nis',
          'id_sekolah': 'eq.$idSekolah',
          'select': '*',
          'limit': '1',
        },
      );
      final List list = res.data is List ? res.data : [];
      if (list.isEmpty) {
        throw const AttendanceException(
          AttendanceErrorCode.studentNotFound,
          'Siswa dengan NIS tersebut tidak ditemukan.',
        );
      }
      return StudentLite.fromJson(list.first as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AttendanceException(
        AttendanceErrorCode.network,
        'Gagal mencari siswa: ${e.message ?? 'unknown'}',
      );
    }
  }

  Future<StudentLite> _findById(String id, String idSekolah) async {
    try {
      final res = await _dio.get(
        ApiConstants.studentsTable,
        queryParameters: {
          'id': 'eq.$id',
          'id_sekolah': 'eq.$idSekolah',
          'select': '*',
          'limit': '1',
        },
      );
      final List list = res.data is List ? res.data : [];
      if (list.isEmpty) {
        throw const AttendanceException(
          AttendanceErrorCode.studentNotFound,
          'Siswa tidak ditemukan.',
        );
      }
      return StudentLite.fromJson(list.first as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AttendanceException(
        AttendanceErrorCode.network,
        'Gagal mencari siswa: ${e.message ?? 'unknown'}',
      );
    }
  }

  static final _digitsPattern = RegExp(r'^\d+$');
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
}

final studentResolverProvider = Provider<StudentResolver>((ref) {
  return StudentResolver(ref.watch(dioClientProvider));
});
