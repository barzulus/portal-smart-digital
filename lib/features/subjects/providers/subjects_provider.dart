import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/offline_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Subject/Mata Pelajaran model — diambil dari jadwal_pembelajaran_v2.
class SubjectData {
  final String id;
  final String name;
  final String teacher;
  final String day;
  final String time;
  final String room;
  final Color color;

  const SubjectData({
    required this.id,
    required this.name,
    required this.teacher,
    required this.day,
    required this.time,
    required this.room,
    required this.color,
  });

  factory SubjectData.fromJson(Map<String, dynamic> json) {
    final mataPelajaran = json['mata_pelajaran']?.toString() ?? '';
    final colors = [
      AppColors.pelajaranColor,
      AppColors.kehadiranColor,
      AppColors.tugasColor,
      AppColors.ujianColor,
      AppColors.perpustakaanColor,
      AppColors.info,
      AppColors.secondary,
    ];
    final color = colors[mataPelajaran.hashCode.abs() % colors.length];

    final jamMulai = json['jam_mulai']?.toString() ?? '';
    final jamSelesai = json['jam_selesai']?.toString() ?? '';
    String formatTime(String t) => t.length > 5 ? t.substring(0, 5) : t;

    return SubjectData(
      id: json['id']?.toString() ?? '',
      name: mataPelajaran,
      teacher: json['guru']?.toString() ?? '',
      day: json['hari']?.toString() ?? '',
      time: '${formatTime(jamMulai)} - ${formatTime(jamSelesai)}',
      room: json['ruangan']?.toString() ?? '',
      color: color,
    );
  }
}

const _dayOrder = {
  'senin': 0, 'selasa': 1, 'rabu': 2, 'kamis': 3,
  'jumat': 4, 'sabtu': 5, 'minggu': 6,
};

/// Fetch jadwal pelajaran siswa dari tabel jadwal_pembelajaran_v2.
/// Filter by id_sekolah + kelas siswa yang login.
final subjectsProvider = FutureProvider<List<SubjectData>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  final user = ref.watch(authProvider).user;
  if (idSekolah == null || user == null) return const [];

  final cache = ref.watch(offlineCacheServiceProvider);
  final kelasKey = 'student_kelas_${user.email}_$idSekolah';

  // Lookup kelas siswa — cache hasilnya untuk offline
  String? kelas;
  try {
    final dio = ref.watch(dioClientProvider);
    final studentRes = await dio.get(
      ApiConstants.studentsTable,
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'email': 'eq.${user.email}',
        'select': 'kelas',
        'limit': '1',
      },
    );
    final List studentData = studentRes.data is List ? studentRes.data : [];
    if (studentData.isNotEmpty) {
      kelas = (studentData.first as Map<String, dynamic>)['kelas']?.toString();
      if (kelas != null && kelas.isNotEmpty) {
        await cache.cacheResponse(kelasKey, kelas);
      }
    }
  } catch (_) {
    // Offline — restore kelas dari cache
    kelas = await cache.getCachedResponse(kelasKey);
  }

  if (kelas == null || kelas.isEmpty) return const [];

  final cacheKey = 'subjects_${idSekolah}_$kelas';

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      ApiConstants.jadwalPelajaranV2Table,
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'kelas': 'eq.$kelas',
        'select': '*',
        'order': 'jam_mulai.asc',
      },
    );

    final List data = res.data is List ? res.data : [];
    await cache.cacheResponse(cacheKey, jsonEncode(data));
    final subjects = data
        .map((json) => SubjectData.fromJson(json as Map<String, dynamic>))
        .toList();

    subjects.sort((a, b) {
      final dayA = _dayOrder[a.day.toLowerCase()] ?? 99;
      final dayB = _dayOrder[b.day.toLowerCase()] ?? 99;
      if (dayA != dayB) return dayA.compareTo(dayB);
      return a.time.compareTo(b.time);
    });

    return subjects;
  } on DioException catch (e) {
    // Offline — try cache
    final cached = await cache.getCachedResponse(cacheKey);
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      final subjects = decoded
          .map((json) => SubjectData.fromJson(json as Map<String, dynamic>))
          .toList();
      subjects.sort((a, b) {
        final dayA = _dayOrder[a.day.toLowerCase()] ?? 99;
        final dayB = _dayOrder[b.day.toLowerCase()] ?? 99;
        if (dayA != dayB) return dayA.compareTo(dayB);
        return a.time.compareTo(b.time);
      });
      return subjects;
    }
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat jadwal: ${e.message ?? 'tidak diketahui'}');
  }
});

/// Today's schedule for student.
final todayScheduleProvider = Provider<List<SubjectData>>((ref) {
  const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  final now = DateTime.now();
  final todayName = dayNames[now.weekday - 1];

  final subjectsAsync = ref.watch(subjectsProvider);
  return subjectsAsync.when(
    data: (subjects) => subjects.where((s) => s.day.toLowerCase() == todayName.toLowerCase()).toList(),
    loading: () => const [],
    error: (_, __) => const [],
  );
});
