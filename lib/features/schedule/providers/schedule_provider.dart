import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/offline_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Model untuk baris `jadwal_pelajaran_v2`.
///
/// Perbedaan dari v1: kolom `guru_id` (UUID FK) wajib diisi — dipakai untuk
/// guard "hanya guru pengampu yang bisa absen kelasnya".
class JadwalPelajaran {
  final String id;
  final String idSekolah;
  final String kelas;
  final String mataPelajaran;
  final String hari;
  final String jamMulai;
  final String jamSelesai;
  final String guru;
  final String? guruId;
  final String ruangan;

  JadwalPelajaran({
    required this.id,
    required this.idSekolah,
    required this.kelas,
    required this.mataPelajaran,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
    required this.guru,
    required this.guruId,
    required this.ruangan,
  });

  factory JadwalPelajaran.fromJson(Map<String, dynamic> json) {
    return JadwalPelajaran(
      id: json['id']?.toString() ?? '',
      idSekolah: json['id_sekolah']?.toString() ?? '',
      kelas: json['kelas']?.toString() ?? '',
      mataPelajaran: json['mata_pelajaran']?.toString() ?? '',
      hari: json['hari']?.toString() ?? '',
      jamMulai: json['jam_mulai']?.toString() ?? '',
      jamSelesai: json['jam_selesai']?.toString() ?? '',
      guru: json['guru']?.toString() ?? '',
      guruId: json['guru_id']?.toString(),
      ruangan: json['ruangan']?.toString() ?? '',
    );
  }

  String get jamRange => '$jamMulai - $jamSelesai';
  String get kelasMapelKey => '$kelas|$mataPelajaran';

  Color get color {
    final hash = mataPelajaran.hashCode;
    final colors = [
      AppColors.pelajaranColor,
      AppColors.kehadiranColor,
      AppColors.tugasColor,
      AppColors.ujianColor,
      AppColors.perpustakaanColor,
      AppColors.info,
      AppColors.secondary,
    ];
    return colors[hash.abs() % colors.length];
  }
}

class DaySchedule {
  final String hari;
  final List<JadwalPelajaran> jadwalList;

  DaySchedule({required this.hari, required this.jadwalList});
}

const _dayOrder = {
  'senin': 0,
  'selasa': 1,
  'rabu': 2,
  'kamis': 3,
  'jumat': 4,
  'sabtu': 5,
  'minggu': 6,
};

String _getTodayName() {
  final now = DateTime.now();
  const days = ['minggu', 'senin', 'selasa', 'rabu', 'kamis', 'jumat', 'sabtu'];
  return days[now.weekday % 7];
}

// ═══════════════════════════════════════════════════
// Semua jadwal di sekolah user (dari v2).
// ═══════════════════════════════════════════════════

final allJadwalProvider = FutureProvider<List<JadwalPelajaran>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  if (idSekolah == null) return [];

  final cache = ref.watch(offlineCacheServiceProvider);
  final cacheKey = 'jadwal_$idSekolah';

  try {
    final dioClient = ref.watch(dioClientProvider);
    final response = await dioClient.get(
      ApiConstants.jadwalPelajaranV2Table,
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'select': '*',
        'order': 'jam_mulai.asc',
      },
    );

    final List data = response.data is List ? response.data : [];
    // Cache the raw response
    await cache.cacheResponse(cacheKey, jsonEncode(data));
    return data
        .map((json) => JadwalPelajaran.fromJson(json as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    // Offline — try cache
    final cached = await cache.getCachedResponse(cacheKey);
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      return decoded
          .map((json) => JadwalPelajaran.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    if (e.response?.statusCode == 404) return [];
    throw Exception('Gagal memuat jadwal: ${e.message}');
  }
});

// ═══════════════════════════════════════════════════
// Mapel yang diajar guru (dari tabel mapel_guru → mapel.nama_mapel).
// Dipakai untuk fallback match jadwal kalau guru_id di v2 belum di-set.
// ═══════════════════════════════════════════════════

final teacherMapelNamesProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return const [];

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      ApiConstants.mapelGuruTable,
      queryParameters: {
        'id_guru': 'eq.${user.id}',
        'select': 'id_mapel,mapel:id_mapel(nama_mapel)',
      },
    );

    final List data = res.data is List ? res.data : [];
    final names = <String>[];
    for (final row in data) {
      if (row is Map<String, dynamic>) {
        final mapel = row['mapel'];
        if (mapel is Map<String, dynamic>) {
          final nama = mapel['nama_mapel']?.toString().trim();
          if (nama != null && nama.isNotEmpty) names.add(nama);
        }
      }
    }
    return names;
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return const [];
    // Tabel mungkin belum ada / relasi embed gagal — gracefully return kosong.
    return const [];
  }
});

// ═══════════════════════════════════════════════════
// Jadwal guru yang sedang login.
//
// Strategi match (3 level, fallback berurutan):
//   1. `guru_id` di v2 sama dengan user.id (UUID FK).
//   2. Nama `guru` (case-insensitive) sama dengan nama user.
//   3. `mata_pelajaran` ada di list mapel yang diajar guru (via mapel_guru).
// Level 3 paling longgar — aman untuk view-only (lihat jadwal mengajar)
// karena tetap filter id_sekolah di query awal, TAPI tidak boleh dipakai
// untuk write actions seperti absensi (lihat myJadwalForAttendanceProvider).
// ═══════════════════════════════════════════════════

final myJadwalProvider = Provider<AsyncValue<List<JadwalPelajaran>>>((ref) {
  final allJadwal = ref.watch(allJadwalProvider);
  final mapelNames = ref.watch(teacherMapelNamesProvider);
  final user = ref.watch(authProvider).user;

  if (user == null) return const AsyncValue.data([]);

  final userId = user.id;
  final userName = user.name.trim().toLowerCase();

  return allJadwal.whenData((list) {
    // Level 1: guru_id
    final byId = list.where((j) => j.guruId == userId).toList();
    if (byId.isNotEmpty) return byId;

    // Level 2: nama
    if (userName.isNotEmpty) {
      final byName = list
          .where((j) => j.guru.trim().toLowerCase() == userName)
          .toList();
      if (byName.isNotEmpty) return byName;
    }

    // Level 3: mapel yang diajar guru (lowercase set untuk lookup cepat)
    final mapelSet = mapelNames
            .maybeWhen(data: (n) => n, orElse: () => const <String>[])
            .map((n) => n.trim().toLowerCase())
            .toSet();
    if (mapelSet.isEmpty) return const <JadwalPelajaran>[];

    return list
        .where((j) => mapelSet.contains(j.mataPelajaran.trim().toLowerCase()))
        .toList();
  });
});

/// Versi STRICT untuk write actions (absensi, dll). Hanya level 1 dan 2:
/// yaitu jadwal yang `guru_id`-nya FK ke user, atau nama guru di kolom
/// teks `guru` persis match dengan nama user. Fallback by-mapel SENGAJA
/// dihilangkan supaya guru A tidak bisa absen kelas guru B yang kebetulan
/// mengajar mapel sama.
final myJadwalForAttendanceProvider =
    Provider<AsyncValue<List<JadwalPelajaran>>>((ref) {
  final allJadwal = ref.watch(allJadwalProvider);
  final user = ref.watch(authProvider).user;

  if (user == null) return const AsyncValue.data([]);

  final userId = user.id;
  final userName = user.name.trim().toLowerCase();

  return allJadwal.whenData((list) {
    final byId = list.where((j) => j.guruId == userId).toList();
    if (byId.isNotEmpty) return byId;

    if (userName.isNotEmpty) {
      return list
          .where((j) => j.guru.trim().toLowerCase() == userName)
          .toList();
    }
    return const <JadwalPelajaran>[];
  });
});

final teacherClassesProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(myJadwalProvider).whenData((jadwalList) {
    final classes = jadwalList.map((j) => j.kelas).toSet().toList()..sort();
    return classes;
  });
});

/// Unique (kelas + mata pelajaran) yang diajar guru.
final teacherClassSubjectsProvider =
    Provider<AsyncValue<List<JadwalPelajaran>>>((ref) {
  return ref.watch(myJadwalProvider).whenData((jadwalList) {
    final seen = <String>{};
    final unique = <JadwalPelajaran>[];
    for (final j in jadwalList) {
      if (seen.add(j.kelasMapelKey)) unique.add(j);
    }
    unique.sort((a, b) {
      final c = a.kelas.compareTo(b.kelas);
      return c != 0 ? c : a.mataPelajaran.compareTo(b.mataPelajaran);
    });
    return unique;
  });
});

final todayScheduleProvider =
    Provider<AsyncValue<List<JadwalPelajaran>>>((ref) {
  final today = _getTodayName();
  return ref.watch(myJadwalProvider).whenData((list) {
    return list.where((j) => j.hari.toLowerCase() == today).toList();
  });
});

final weeklyScheduleProvider =
    Provider<AsyncValue<List<DaySchedule>>>((ref) {
  return ref.watch(myJadwalProvider).whenData((list) {
    final Map<String, List<JadwalPelajaran>> grouped = {};
    for (final j in list) {
      grouped.putIfAbsent(j.hari, () => []).add(j);
    }

    final days = grouped.entries
        .map((e) => DaySchedule(hari: e.key, jadwalList: e.value))
        .toList();
    days.sort((a, b) {
      final aOrder = _dayOrder[a.hari.toLowerCase()] ?? 99;
      final bOrder = _dayOrder[b.hari.toLowerCase()] ?? 99;
      return aOrder.compareTo(bOrder);
    });
    return days;
  });
});
