import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/offline_cache_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// Model yang match kolom `public.pengumuman` di Supabase:
///   id uuid, id_sekolah text, judul text, isi text,
///   file_url text, file_type text, status text,
///   created_at timestamptz, updated_at timestamptz.
class PengumumanData {
  final String id;
  final String idSekolah;
  final String judul;
  final String isi;
  final String? fileUrl;
  final String? fileType;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PengumumanData({
    required this.id,
    required this.idSekolah,
    required this.judul,
    required this.isi,
    required this.fileUrl,
    required this.fileType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PengumumanData.fromJson(Map<String, dynamic> json) {
    DateTime parse(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
      }
      return DateTime.now();
    }

    // file_url di DB berisi path relatif dari bucket (sudah include folder sekolah).
    // Contoh: "SCH0005/1777977952183_ivcm1.png"
    // Construct full URL: pengumuman-files/{file_url}
    String? rawFileUrl = json['file_url']?.toString();
    if (rawFileUrl != null && rawFileUrl.isEmpty) rawFileUrl = null;
    if (rawFileUrl != null && !rawFileUrl.startsWith('http')) {
      rawFileUrl =
          '${ApiConstants.supabaseUrl}/storage/v1/object/public/pengumuman-files/$rawFileUrl';
    }

    return PengumumanData(
      id: json['id']?.toString() ?? '',
      idSekolah: json['id_sekolah']?.toString() ?? '',
      judul: json['judul']?.toString() ?? '',
      isi: json['isi']?.toString() ?? '',
      fileUrl: rawFileUrl,
      fileType: (json['file_type']?.toString().isEmpty ?? true)
          ? null
          : json['file_type']?.toString(),
      status: json['status']?.toString() ?? 'active',
      createdAt: parse(json['created_at']),
      updatedAt: parse(json['updated_at']),
    );
  }

  bool get hasAttachment => fileUrl != null && fileUrl!.isNotEmpty;
  bool get isImageAttachment {
    if (!hasAttachment) return false;

    // Cek file_type dulu
    if (fileType != null && fileType!.isNotEmpty) {
      final t = fileType!.toLowerCase().trim();
      // Jika eksplisit bukan gambar (pdf, doc, dll), return false
      if (t.contains('pdf') || t.contains('word') || t.contains('doc') ||
          t.contains('excel') || t.contains('xls') || t.contains('ppt')) {
        return false;
      }
      // Jika eksplisit gambar
      if (t.startsWith('image') || t == 'jpg' || t == 'jpeg' ||
          t == 'png' || t == 'gif' || t == 'webp' || t == 'jfif') {
        return true;
      }
    }

    // Fallback: cek extension dari URL
    if (fileUrl != null) {
      final u = fileUrl!.toLowerCase().split('?').first;
      // Jika eksplisit bukan gambar
      if (u.endsWith('.pdf') || u.endsWith('.doc') || u.endsWith('.docx') ||
          u.endsWith('.xls') || u.endsWith('.xlsx') || u.endsWith('.ppt') ||
          u.endsWith('.pptx')) {
        return false;
      }
      // Jika eksplisit gambar
      if (u.endsWith('.jpg') || u.endsWith('.jpeg') || u.endsWith('.png') ||
          u.endsWith('.gif') || u.endsWith('.webp') || u.endsWith('.jfif')) {
        return true;
      }
    }

    // Default: kalau ada attachment dan bukan dokumen, anggap gambar
    // (karena di Supabase Storage biasanya upload gambar)
    return true;
  }

  /// Format "2 menit lalu", "3 jam lalu", "kemarin", tanggal pendek.
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    // > 1 minggu: pakai tanggal singkat
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${createdAt.day} ${bulan[createdAt.month - 1]} ${createdAt.year}';
  }
}

/// Fetch pengumuman aktif untuk sekolah user — selalu filter `id_sekolah`
/// supaya tetap terisolasi multi-tenant.
final announcementsProvider = FutureProvider<List<PengumumanData>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  if (idSekolah == null) return const [];

  final cache = ref.watch(offlineCacheServiceProvider);
  final cacheKey = 'pengumuman_$idSekolah';

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      ApiConstants.pengumumanTable,
      queryParameters: {
        'id_sekolah': 'eq.$idSekolah',
        'or': '(status.eq.active,status.eq.aktif,status.is.null)',
        'select': '*',
        'order': 'created_at.desc',
      },
    );

    final List data = res.data is List ? res.data : [];
    // Cache raw response
    await cache.cacheResponse(cacheKey, jsonEncode(data));
    return data
        .map((json) => PengumumanData.fromJson(json as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    // Offline — try cache
    final cached = await cache.getCachedResponse(cacheKey);
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      return decoded
          .map((json) => PengumumanData.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat pengumuman: ${e.message ?? 'tidak diketahui'}');
  }
});

/// Jumlah pengumuman yang belum dibaca (fitur bookkeeping lokal).
/// Saat ini belum ada kolom read/unread di DB, jadi return total.
final unreadAnnouncementsCountProvider = Provider<int>((ref) {
  return ref.watch(announcementsProvider).when(
        data: (list) => list.length,
        loading: () => 0,
        error: (_, __) => 0,
      );
});
