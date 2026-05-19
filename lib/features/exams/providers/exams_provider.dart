import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../auth/presentation/providers/guru_staff_provider.dart';

/// Jenis ujian — turunan dari nama_jenis_penilaian di tabel jenis_penilaian.
/// Disesuaikan agar UI bisa pilih warna yang konsisten.
enum ExamType { uts, uas, quiz, dailyTest, other }

/// Model dari tabel `ujian_quiz` (master ujian) + join ke
/// `jenis_penilaian` (untuk jenis) dan `guru_staff` (untuk pengampu).
///
/// Catatan DB: tabel `ujian_quiz` tidak menyimpan nilai/skor maupun
/// status pengerjaan. Yang ada hanya jadwal pelaksanaan. Jadi UI
/// di sini hanya menampilkan informasi jadwal.
class ExamData {
  final String id;
  final String namaUjian;
  final String namaJenis;
  final ExamType type;
  final DateTime tanggal;
  final String jamRange;
  final String ruangan;
  final int durasiMenit;
  final String? guruNama;

  const ExamData({
    required this.id,
    required this.namaUjian,
    required this.namaJenis,
    required this.type,
    required this.tanggal,
    required this.jamRange,
    required this.ruangan,
    required this.durasiMenit,
    this.guruNama,
  });

  bool get isPast {
    final now = DateTime.now();
    return tanggal.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get isToday {
    final now = DateTime.now();
    return tanggal.year == now.year &&
        tanggal.month == now.month &&
        tanggal.day == now.day;
  }

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(tanggal.year, tanggal.month, tanggal.day);
    return examDay.difference(today).inDays;
  }

  factory ExamData.fromJson(Map<String, dynamic> json) {
    final jenisNama = json['jenis_penilaian']?['nama_jenis_penilaian']
            ?.toString() ??
        '';
    final lower = jenisNama.toLowerCase();
    ExamType type = ExamType.other;
    if (lower.contains('uts') || lower.contains('tengah')) {
      type = ExamType.uts;
    } else if (lower.contains('uas') || lower.contains('akhir')) {
      type = ExamType.uas;
    } else if (lower.contains('quiz') || lower.contains('kuis')) {
      type = ExamType.quiz;
    } else if (lower.contains('ulangan') || lower.contains('harian')) {
      type = ExamType.dailyTest;
    }

    final tanggal = DateTime.tryParse(json['tanggal']?.toString() ?? '') ??
        DateTime.now();
    final jamMulai = json['jam_mulai']?.toString() ?? '';
    final jamSelesai = json['jam_selesai']?.toString() ?? '';
    String formatTime(String t) => t.length > 5 ? t.substring(0, 5) : t;

    final guruNama =
        json['guru_staff']?['nama']?.toString() ?? json['guru']?.toString();

    return ExamData(
      id: json['id']?.toString() ?? '',
      namaUjian: json['nama_ujian']?.toString() ?? '',
      namaJenis: jenisNama.isEmpty ? 'Ujian' : jenisNama,
      type: type,
      tanggal: tanggal,
      jamRange:
          '${formatTime(jamMulai)} - ${formatTime(jamSelesai)}',
      ruangan: json['ruangan']?.toString() ?? '-',
      durasiMenit: int.tryParse(json['durasi']?.toString() ?? '0') ?? 0,
      guruNama: guruNama,
    );
  }

  String get typeLabel {
    switch (type) {
      case ExamType.uts:
        return 'UTS';
      case ExamType.uas:
        return 'UAS';
      case ExamType.quiz:
        return 'Quiz';
      case ExamType.dailyTest:
        return 'Ulangan Harian';
      case ExamType.other:
        return namaJenis.isEmpty ? 'Ujian' : namaJenis;
    }
  }
}

/// Fetch ujian/quiz untuk sekolah user yang login.
/// Tabel: `ujian_quiz` (filter by id_sekolah).
/// Join: `jenis_penilaian` (untuk nama jenis), `guru_staff` (untuk
///       nama guru pengampu).
final examsProvider = FutureProvider<List<ExamData>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  if (idSekolah == null) return const [];

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      '/ujian_quiz',
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'select':
            '*,jenis_penilaian:jenis_ujian_id(nama_jenis_penilaian),guru_staff:guru_id(nama)',
        'order': 'tanggal.asc',
      },
    );

    final List data = res.data is List ? res.data : [];
    return data
        .map((json) => ExamData.fromJson(json as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat ujian: ${e.message ?? 'tidak diketahui'}');
  }
});

/// Jumlah ujian yang akan datang (untuk badge dashboard).
final upcomingExamsCountProvider = Provider<int>((ref) {
  final examsAsync = ref.watch(examsProvider);
  return examsAsync.when(
    data: (list) => list.where((e) => !e.isPast).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});


// ═══════════════════════════════════════════════════════════════
// JENIS PENILAIAN (master untuk dropdown jenis ujian)
// ═══════════════════════════════════════════════════════════════

class JenisPenilaian {
  final String id;
  final String nama;
  final String kode;

  const JenisPenilaian({
    required this.id,
    required this.nama,
    required this.kode,
  });

  factory JenisPenilaian.fromJson(Map<String, dynamic> json) {
    return JenisPenilaian(
      id: json['id']?.toString() ?? '',
      nama: json['nama_jenis_penilaian']?.toString() ?? '',
      kode: json['kode']?.toString() ?? '',
    );
  }
}

final jenisPenilaianListProvider =
    FutureProvider<List<JenisPenilaian>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  if (idSekolah == null) return const [];

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      '/jenis_penilaian',
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'select': 'id,nama_jenis_penilaian,kode',
        'order': 'nama_jenis_penilaian.asc',
      },
    );
    final List data = res.data is List ? res.data : [];
    return data
        .map((j) => JenisPenilaian.fromJson(j as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat jenis penilaian: ${e.message ?? ''}');
  }
});

// ═══════════════════════════════════════════════════════════════
// UJIAN MILIK GURU YANG LOGIN (untuk halaman manage ujian guru)
// ═══════════════════════════════════════════════════════════════

final myExamsProvider = FutureProvider<List<ExamData>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  final guruStaffId = await ref.watch(currentGuruStaffIdProvider.future);
  if (idSekolah == null || guruStaffId == null) return const [];

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      '/ujian_quiz',
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'guru_id': 'eq.$guruStaffId',
        'select':
            '*,jenis_penilaian:jenis_ujian_id(nama_jenis_penilaian),guru_staff:guru_id(nama)',
        'order': 'tanggal.desc',
      },
    );
    final List data = res.data is List ? res.data : [];
    return data
        .map((j) => ExamData.fromJson(j as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat ujian saya: ${e.message ?? ''}');
  }
});

// ═══════════════════════════════════════════════════════════════
// CRUD NOTIFIER (untuk halaman manage ujian guru)
// ═══════════════════════════════════════════════════════════════

class ExamNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  ExamNotifier(this._ref) : super(const AsyncValue.data(null));

  static Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createExam({
    required String namaUjian,
    required String jenisUjianId,
    required DateTime tanggal,
    required String jamMulai, // format HH:mm
    required String jamSelesai,
    required int durasi,
    required String ruangan,
    bool acakSoal = false,
    bool tampilkanNilai = true,
    List<String> kelasIds = const [], // kelas yang ikut ujian
  }) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      final guruStaffId = await _ref.read(currentGuruStaffIdProvider.future);
      final idSekolah = _ref.read(currentIdSekolahProvider);
      if (guruStaffId == null || idSekolah == null) {
        state = AsyncValue.error(
          'Sesi guru tidak valid',
          StackTrace.current,
        );
        return false;
      }
      final dio = _ref.read(dioClientProvider);

      // Insert ujian_quiz dulu, supaya dapat id-nya untuk peserta.
      // Pakai header Prefer: return=representation supaya response
      // berisi row yang baru dibuat.
      final res = await dio.post(
        '/ujian_quiz',
        data: {
          'nama_ujian': namaUjian,
          'jenis_ujian_id': jenisUjianId,
          'tanggal': tanggal.toIso8601String().split('T').first,
          'jam_mulai': jamMulai,
          'jam_selesai': jamSelesai,
          'durasi': durasi,
          'ruangan': ruangan,
          'acak_soal': acakSoal,
          'tampilkan_nilai': tampilkanNilai,
          'guru_id': guruStaffId,
          'id_sekolah': idSekolah,
        },
      );

      // Parse id ujian yang baru dibuat.
      String? newExamId;
      final data = res.data;
      if (data is List && data.isNotEmpty) {
        newExamId = (data.first as Map)['id']?.toString();
      } else if (data is Map) {
        newExamId = data['id']?.toString();
      }

      // Insert peserta per kelas (kalau ada kelas yang dipilih).
      if (newExamId != null && kelasIds.isNotEmpty) {
        await _insertPeserta(
          examId: newExamId,
          kelasIds: kelasIds,
          guruStaffId: guruStaffId,
          idSekolah: idSekolah,
        );
      }

      _ref.invalidate(myExamsProvider);
      _ref.invalidate(examsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Untuk setiap kelas, ambil daftar siswa lalu insert satu row
  /// `ujian_peserta` per siswa. Berjalan paralel per kelas.
  Future<void> _insertPeserta({
    required String examId,
    required List<String> kelasIds,
    required String guruStaffId,
    required String idSekolah,
  }) async {
    final dio = _ref.read(dioClientProvider);

    for (final kelasId in kelasIds) {
      // Ambil nama_kelas dulu untuk match dengan students.kelas (text).
      // Tabel kelas pakai id (uuid), tapi students.kelas pakai text.
      // Jadi kita lookup nama kelas, lalu cari students by kolom kelas.
      final kelasRes = await dio.get(
        '/kelas',
        queryParameters: {
          'id': 'eq.$kelasId',
          'select': 'nama_kelas',
          'limit': '1',
        },
      );
      final kelasList = kelasRes.data is List ? kelasRes.data : [];
      if (kelasList.isEmpty) continue;
      final namaKelas =
          (kelasList.first as Map)['nama_kelas']?.toString() ?? '';
      if (namaKelas.isEmpty) continue;

      // Ambil semua siswa di kelas itu.
      final siswaRes = await dio.get(
        '/students',
        queryParameters: {
          'id_sekolah': 'eq.$idSekolah',
          'kelas': 'eq.$namaKelas',
          'select': 'id',
        },
      );
      final List siswaList =
          siswaRes.data is List ? siswaRes.data : [];
      if (siswaList.isEmpty) continue;

      // Bulk insert ujian_peserta — satu request, banyak row.
      final pesertaPayload = siswaList.map((s) {
        return {
          'ujian_id': examId,
          'siswa_id': (s as Map)['id'],
          'kelas_id': kelasId,
          'guru_id': guruStaffId,
        };
      }).toList();

      await dio.post('/ujian_peserta', data: pesertaPayload);
    }
  }

  Future<bool> updateExam({
    required String id,
    required String namaUjian,
    required String jenisUjianId,
    required DateTime tanggal,
    required String jamMulai,
    required String jamSelesai,
    required int durasi,
    required String ruangan,
    bool acakSoal = false,
    bool tampilkanNilai = true,
  }) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioClientProvider);
      await dio.patch(
        '/ujian_quiz',
        queryParameters: {'id': 'eq.$id'},
        data: {
          'nama_ujian': namaUjian,
          'jenis_ujian_id': jenisUjianId,
          'tanggal': tanggal.toIso8601String().split('T').first,
          'jam_mulai': jamMulai,
          'jam_selesai': jamSelesai,
          'durasi': durasi,
          'ruangan': ruangan,
          'acak_soal': acakSoal,
          'tampilkan_nilai': tampilkanNilai,
        },
      );
      _ref.invalidate(myExamsProvider);
      _ref.invalidate(examsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteExam(String id) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioClientProvider);
      await dio.delete(
        '/ujian_quiz',
        queryParameters: {'id': 'eq.$id'},
      );
      _ref.invalidate(myExamsProvider);
      _ref.invalidate(examsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final examNotifierProvider =
    StateNotifierProvider<ExamNotifier, AsyncValue<void>>((ref) {
  return ExamNotifier(ref);
});
