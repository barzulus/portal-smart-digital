import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/offline_cache_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class ReligiousActivity {
  final String id;
  final String title;
  final String description;
  final String? day;
  final String? time;
  final String location;
  final String status;

  const ReligiousActivity({
    required this.id,
    required this.title,
    required this.description,
    this.day,
    this.time,
    required this.location,
    required this.status,
  });

  factory ReligiousActivity.fromJson(Map<String, dynamic> json) {
    // Format tanggal as day name if available
    String? day;
    final tanggal = json['tanggal']?.toString();
    if (tanggal != null && tanggal.isNotEmpty) {
      final date = DateTime.tryParse(tanggal);
      if (date != null) {
        const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
        day = days[date.weekday - 1];
      }
    }

    return ReligiousActivity(
      id: json['id']?.toString() ?? '',
      title: json['nama_kegiatan']?.toString() ?? '',
      description: json['deskripsi']?.toString() ?? '',
      day: day,
      time: json['waktu']?.toString(),
      location: json['lokasi']?.toString() ?? '-',
      status: json['status']?.toString() ?? 'Terjadwal',
    );
  }
}

/// Fetch kegiatan keagamaan sekolah (untuk siswa — read only).
/// Tabel: kegiatan_keagamaan, filter by id_sekolah.
final religiousActivitiesProvider =
    FutureProvider<List<ReligiousActivity>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  if (idSekolah == null) return const [];

  final cache = ref.watch(offlineCacheServiceProvider);
  final cacheKey = 'religious_$idSekolah';

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      ApiConstants.kegiatanKeagamaanTable,
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'select': '*',
        'order': 'tanggal.desc.nullslast,created_at.desc',
      },
    );

    final List data = res.data is List ? res.data : [];
    // Cache the raw response
    await cache.cacheResponse(cacheKey, jsonEncode(data));
    return data
        .map((json) => ReligiousActivity.fromJson(json as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    // Offline — try cache
    final cached = await cache.getCachedResponse(cacheKey);
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      return decoded
          .map((json) => ReligiousActivity.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat kegiatan: ${e.message ?? 'tidak diketahui'}');
  }
});
