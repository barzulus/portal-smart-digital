import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../auth/presentation/providers/guru_staff_provider.dart';

// ── Models ──

/// Status kehadiran guru (match nilai text di kolom status_absensi).
enum TeacherAttendanceStatus { hadir, terlambat, sakit, izin }

extension TeacherAttendanceStatusExt on TeacherAttendanceStatus {
  String get label {
    switch (this) {
      case TeacherAttendanceStatus.hadir:
        return 'Hadir';
      case TeacherAttendanceStatus.terlambat:
        return 'Terlambat';
      case TeacherAttendanceStatus.sakit:
        return 'Sakit';
      case TeacherAttendanceStatus.izin:
        return 'Izin';
    }
  }

  /// Nilai untuk dikirim ke DB — match CHECK constraint:
  /// 'Hadir', 'Sakit', 'Izin', 'Alpa', 'Terlambat'.
  /// Catatan: ini sama dengan label, jadi kita pakai label langsung.
  String get value => label;

  static TeacherAttendanceStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'terlambat':
        return TeacherAttendanceStatus.terlambat;
      case 'sakit':
        return TeacherAttendanceStatus.sakit;
      case 'izin':
        return TeacherAttendanceStatus.izin;
      default:
        return TeacherAttendanceStatus.hadir;
    }
  }
}

/// Satu baris `guru_absensi` (skema match DB): jam_masuk + jam_keluar
/// disatuin per hari, bukan dua row terpisah.
class GuruAbsensiRecord {
  final String? id;
  final String idGuru;
  final String idSekolah;
  final String tanggal;
  final String statusAbsensi;
  final String? keterangan;
  final String? jamMasuk;
  final String? jamKeluar;
  final String? foto;
  final double? latitude;
  final double? longitude;

  const GuruAbsensiRecord({
    this.id,
    required this.idGuru,
    required this.idSekolah,
    required this.tanggal,
    required this.statusAbsensi,
    this.keterangan,
    this.jamMasuk,
    this.jamKeluar,
    this.foto,
    this.latitude,
    this.longitude,
  });

  factory GuruAbsensiRecord.fromJson(Map<String, dynamic> json) {
    double? parseNum(dynamic v) => v == null ? null : (v as num).toDouble();
    return GuruAbsensiRecord(
      id: json['id']?.toString(),
      idGuru: json['id_guru']?.toString() ?? '',
      idSekolah: json['id_sekolah']?.toString() ?? '',
      tanggal: json['tanggal_absensi']?.toString() ?? '',
      statusAbsensi: json['status_absensi']?.toString() ?? 'hadir',
      keterangan: json['keterangan']?.toString(),
      jamMasuk: json['jam_masuk']?.toString(),
      jamKeluar: json['jam_keluar']?.toString(),
      foto: json['foto']?.toString(),
      latitude: parseNum(json['latitude']),
      longitude: parseNum(json['longitude']),
    );
  }

  bool get hasMasuk => jamMasuk != null && jamMasuk!.isNotEmpty;
  bool get hasPulang => jamKeluar != null && jamKeluar!.isNotEmpty;
}

/// Koordinat + radius sekolah (diambil dari tabel `schools`).
class SchoolLocation {
  final double latitude;
  final double longitude;
  final double radiusMeter;
  final String? namaSekolah;

  const SchoolLocation({
    required this.latitude,
    required this.longitude,
    required this.radiusMeter,
    this.namaSekolah,
  });
}

// ── Service ──

class TeacherSelfAttendanceService {
  final DioClient _dioClient;

  TeacherSelfAttendanceService(this._dioClient);

  /// Fetch koordinat + radius sekolah. Radius null → fallback 200m.
  Future<SchoolLocation?> getSchoolLocation(String idSekolah) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.schoolsTable,
        queryParameters: {
          'id_sekolah': 'eq.$idSekolah',
          'select': 'latitude,longitude,radius_meter,nama_sekolah',
          'limit': '1',
        },
      );

      final data = response.data;
      if (data is List && data.isNotEmpty) {
        final school = data.first as Map<String, dynamic>;
        final lat = school['latitude'];
        final lng = school['longitude'];
        if (lat != null && lng != null) {
          return SchoolLocation(
            latitude: (lat as num).toDouble(),
            longitude: (lng as num).toDouble(),
            radiusMeter: (school['radius_meter'] as num?)?.toDouble() ?? 200.0,
            namaSekolah: school['nama_sekolah']?.toString(),
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Ambil row guru_absensi untuk hari ini (1 row per guru per hari).
  Future<GuruAbsensiRecord?> getTodayRecord({
    required String idGuru,
    required String idSekolah,
  }) async {
    final now = DateTime.now();
    final tanggal = _formatDate(now);

    try {
      final response = await _dioClient.get(
        ApiConstants.absensiGuruTable,
        queryParameters: {
          'id_guru': 'eq.$idGuru',
          'id_sekolah': 'eq.$idSekolah',
          'tanggal_absensi': 'eq.$tanggal',
          'select': '*',
          'limit': '1',
        },
      );

      final data = response.data;
      if (data is List && data.isNotEmpty) {
        return GuruAbsensiRecord.fromJson(data.first as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Upload foto selfie ke bucket Supabase Storage → kembalikan public URL.
  Future<String?> uploadSelfiePhoto({
    required File photoFile,
    required String idGuru,
    required String idSekolah,
    required String tipeAbsen,
  }) async {
    try {
      final now = DateTime.now();
      final timestamp =
          '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
      final fileName = '${idGuru}_${tipeAbsen}_$timestamp.jpg';
      final storagePath = '$idSekolah/absensi_guru/$fileName';

      final bytes = await photoFile.readAsBytes();
      final uploadUrl =
          '${ApiConstants.supabaseUrl}/storage/v1/object/attendance-photos/$storagePath';

      final dio = Dio();
      await dio.post(
        uploadUrl,
        data: Stream.fromIterable(bytes.map((e) => [e])),
        options: Options(
          headers: {
            'apikey': ApiConstants.supabaseAnonKey,
            'Authorization': 'Bearer ${ApiConstants.supabaseAnonKey}',
            'Content-Type': 'image/jpeg',
          },
          contentType: 'image/jpeg',
        ),
      );

      return '${ApiConstants.supabaseUrl}/storage/v1/object/public/attendance-photos/$storagePath';
    } catch (_) {
      return null;
    }
  }

  /// Insert atau update (upsert) row guru_absensi per hari.
  ///
  /// - Kalau belum ada row hari ini → INSERT dengan jam_masuk.
  /// - Kalau tipe 'pulang' dan row sudah ada → PATCH jam_keluar.
  Future<void> submitAttendance({
    required String idGuru,
    required String idSekolah,
    required String tipeAbsen, // 'masuk' | 'pulang'
    required double latitude,
    required double longitude,
    String? fotoUrl,
    required String statusKehadiran,
    String? keterangan,
  }) async {
    final now = DateTime.now();
    final tanggal = _formatDate(now);
    final jam = _formatTime(now);

    try {
      // Cek apakah row hari ini sudah ada
      final existing = await getTodayRecord(
        idGuru: idGuru,
        idSekolah: idSekolah,
      );

      if (tipeAbsen == 'pulang') {
        // PULANG — wajib ada row masuk dulu, lalu update jam_keluar.
        if (existing == null || !existing.hasMasuk) {
          throw Exception('Belum absen masuk hari ini.');
        }
        await _dioClient.patch(
          ApiConstants.absensiGuruTable,
          data: {
            'jam_keluar': jam,
            'latitude': latitude,
            'longitude': longitude,
            if (fotoUrl != null) 'foto': fotoUrl,
            if (keterangan != null && keterangan.isNotEmpty)
              'keterangan': keterangan,
            'updated_at': now.toUtc().toIso8601String(),
          },
          queryParameters: {
            'id': 'eq.${existing.id}',
            'id_sekolah': 'eq.$idSekolah',
          },
        );
      } else {
        // MASUK — INSERT baru (atau update kalau sudah ada row masuk = overwrite).
        if (existing != null) {
          await _dioClient.patch(
            ApiConstants.absensiGuruTable,
            data: {
              'jam_masuk': jam,
              'status_absensi': statusKehadiran,
              'latitude': latitude,
              'longitude': longitude,
              if (fotoUrl != null) 'foto': fotoUrl,
              if (keterangan != null && keterangan.isNotEmpty)
                'keterangan': keterangan,
              'updated_at': now.toUtc().toIso8601String(),
            },
            queryParameters: {
              'id': 'eq.${existing.id}',
              'id_sekolah': 'eq.$idSekolah',
            },
          );
        } else {
          await _dioClient.post(
            ApiConstants.absensiGuruTable,
            data: {
              'id_guru': idGuru,
              'id_sekolah': idSekolah,
              'tanggal_absensi': tanggal,
              'status_absensi': statusKehadiran,
              'jam_masuk': jam,
              'latitude': latitude,
              'longitude': longitude,
              if (fotoUrl != null) 'foto': fotoUrl,
              if (keterangan != null && keterangan.isNotEmpty)
                'keterangan': keterangan,
            },
          );
        }
      }
    } on DioException catch (e) {
      // Translate ke pesan yang user-friendly. 401 di endpoint write
      // biasanya karena RLS — tabel `guru_absensi` punya policy yang
      // butuh user terotentikasi via Supabase Auth, padahal app masih
      // pakai custom auth. Solusi: minta admin DB matikan RLS untuk
      // tabel ini, atau migrasi ke Supabase Auth.
      final status = e.response?.statusCode;
      String msg;
      if (status == 401) {
        msg =
            'Tidak diizinkan menyimpan absensi (401). Hubungi admin untuk mengatur izin tabel guru_absensi di Supabase.';
      } else if (status == 403) {
        msg = 'Akses ditolak (403). Periksa izin akun Anda.';
      } else if (status == 409 || status == 23505) {
        msg = 'Data absensi sudah ada untuk hari ini.';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        msg = 'Koneksi timeout. Coba lagi.';
      } else {
        msg = e.message ?? 'Tidak diketahui';
      }
      throw Exception('Gagal menyimpan absensi: $msg');
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';
  String _formatTime(DateTime d) =>
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
  String _two(int v) => v.toString().padLeft(2, '0');
}

// ── Providers ──

final teacherSelfAttendanceServiceProvider =
    Provider<TeacherSelfAttendanceService>((ref) {
  return TeacherSelfAttendanceService(ref.watch(dioClientProvider));
});

/// Koordinat + radius sekolah aktif.
final schoolLocationProvider = FutureProvider<SchoolLocation?>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  if (idSekolah == null) return null;
  final service = ref.watch(teacherSelfAttendanceServiceProvider);
  return service.getSchoolLocation(idSekolah);
});

/// Record guru_absensi untuk hari ini.
final teacherTodayAttendanceProvider =
    FutureProvider<GuruAbsensiRecord?>((ref) async {
  final guruStaffId = await ref.watch(currentGuruStaffIdProvider.future);
  final idSekolah = ref.watch(currentIdSekolahProvider);
  if (guruStaffId == null || idSekolah == null) return null;
  final service = ref.watch(teacherSelfAttendanceServiceProvider);
  return service.getTodayRecord(idGuru: guruStaffId, idSekolah: idSekolah);
});

// ── GPS + Camera helpers ──

Future<Position> getCurrentPosition() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Layanan lokasi tidak aktif. Aktifkan GPS Anda.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Izin lokasi ditolak.');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception(
        'Izin lokasi ditolak permanen. Buka pengaturan untuk mengizinkan.');
  }

  return await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
    ),
  );
}

double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
}

Future<File?> pickSelfiePhoto() async {
  final picker = ImagePicker();
  final photo = await picker.pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 80,
  );
  if (photo != null) {
    return File(photo.path);
  }
  return null;
}
