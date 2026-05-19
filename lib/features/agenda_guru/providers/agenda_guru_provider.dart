import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/offline_cache_service.dart';
import '../../auth/presentation/providers/guru_staff_provider.dart';

// ═══════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════

class AgendaGuru {
  final String id;
  final String guruId;
  final DateTime tanggal;
  final int jamKe;
  final String materi;
  final String kodeAjar;
  final String kelas;
  final String? keterangan;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AgendaGuru({
    required this.id,
    required this.guruId,
    required this.tanggal,
    required this.jamKe,
    required this.materi,
    required this.kodeAjar,
    required this.kelas,
    this.keterangan,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AgendaGuru.fromJson(Map<String, dynamic> json) {
    return AgendaGuru(
      id: json['id']?.toString() ?? '',
      guruId: json['guru_id']?.toString() ?? '',
      tanggal: DateTime.tryParse(json['tanggal']?.toString() ?? '') ?? DateTime.now(),
      jamKe: int.tryParse(json['jam_ke']?.toString() ?? '0') ?? 0,
      materi: json['materi']?.toString() ?? '',
      kodeAjar: json['kode_ajar']?.toString() ?? '',
      kelas: json['kelas']?.toString() ?? '',
      keterangan: json['keterangan']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'guru_id': guruId,
        'tanggal': tanggal.toIso8601String().split('T').first,
        'jam_ke': jamKe,
        'materi': materi,
        'kode_ajar': kodeAjar,
        'kelas': kelas,
        'keterangan': keterangan,
      };

  String get tanggalFormatted {
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${tanggal.day} ${bulan[tanggal.month - 1]} ${tanggal.year}';
  }

  String get hariNama {
    const hari = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    return hari[tanggal.weekday % 7];
  }
}

// ═══════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════

/// Filter tanggal untuk agenda (default: minggu ini).
final agendaDateFilterProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Fetch agenda guru yang login, filter by tanggal (minggu yang dipilih).
final agendaGuruProvider = FutureProvider<List<AgendaGuru>>((ref) async {
  final guruStaffId = await ref.watch(currentGuruStaffIdProvider.future);
  if (guruStaffId == null) return const [];

  final filterDate = ref.watch(agendaDateFilterProvider);
  // Ambil range 1 minggu (Senin - Minggu)
  final weekday = filterDate.weekday; // 1=Mon, 7=Sun
  final startOfWeek = filterDate.subtract(Duration(days: weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 6));

  final startStr = startOfWeek.toIso8601String().split('T').first;
  final endStr = endOfWeek.toIso8601String().split('T').first;

  final cache = ref.watch(offlineCacheServiceProvider);
  final cacheKey = 'agenda_$guruStaffId';

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      ApiConstants.agendaGuruTable,
      queryParameters: {
        'guru_id': 'eq.$guruStaffId',
        'and': '(tanggal.gte.$startStr,tanggal.lte.$endStr)',
        'select': '*',
        'order': 'tanggal.asc,jam_ke.asc',
      },
    );

    final List data = res.data is List ? res.data : [];
    // Cache the raw response
    await cache.cacheResponse(cacheKey, jsonEncode(data));
    return data
        .map((json) => AgendaGuru.fromJson(json as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    // Offline — try cache
    final cached = await cache.getCachedResponse(cacheKey);
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      return decoded
          .map((json) => AgendaGuru.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat agenda: ${e.message ?? 'tidak diketahui'}');
  }
});

/// Agenda hari ini saja.
final agendaTodayProvider = Provider<AsyncValue<List<AgendaGuru>>>((ref) {
  final allAgenda = ref.watch(agendaGuruProvider);
  final today = DateTime.now();
  return allAgenda.whenData((list) {
    return list.where((a) =>
        a.tanggal.year == today.year &&
        a.tanggal.month == today.month &&
        a.tanggal.day == today.day).toList();
  });
});

// ═══════════════════════════════════════════════════════════════
// NOTIFIER (CRUD)
// ═══════════════════════════════════════════════════════════════

class AgendaGuruNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  AgendaGuruNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Check if device is online.
  static Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createAgenda({
    required DateTime tanggal,
    required int jamKe,
    required String materi,
    required String kodeAjar,
    required String kelas,
    String? keterangan,
  }) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      final guruStaffId = await _ref.read(currentGuruStaffIdProvider.future);
      if (guruStaffId == null) {
        state = AsyncValue.error('Guru staff ID tidak ditemukan', StackTrace.current);
        return false;
      }

      final dio = _ref.read(dioClientProvider);
      await dio.post(
        ApiConstants.agendaGuruTable,
        data: {
          'guru_id': guruStaffId,
          'tanggal': tanggal.toIso8601String().split('T').first,
          'jam_ke': jamKe,
          'materi': materi,
          'kode_ajar': kodeAjar,
          'kelas': kelas,
          'keterangan': keterangan,
        },
      );

      _ref.invalidate(agendaGuruProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateAgenda({
    required String id,
    required DateTime tanggal,
    required int jamKe,
    required String materi,
    required String kodeAjar,
    required String kelas,
    String? keterangan,
  }) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioClientProvider);
      await dio.patch(
        ApiConstants.agendaGuruTable,
        queryParameters: {'id': 'eq.$id'},
        data: {
          'tanggal': tanggal.toIso8601String().split('T').first,
          'jam_ke': jamKe,
          'materi': materi,
          'kode_ajar': kodeAjar,
          'kelas': kelas,
          'keterangan': keterangan,
        },
      );

      _ref.invalidate(agendaGuruProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteAgenda(String id) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioClientProvider);
      await dio.delete(
        ApiConstants.agendaGuruTable,
        queryParameters: {'id': 'eq.$id'},
      );

      _ref.invalidate(agendaGuruProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final agendaGuruNotifierProvider =
    StateNotifierProvider<AgendaGuruNotifier, AsyncValue<void>>((ref) {
  return AgendaGuruNotifier(ref);
});
