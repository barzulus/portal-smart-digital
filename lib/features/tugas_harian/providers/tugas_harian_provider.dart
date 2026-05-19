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

class TugasHarian {
  final String id;
  final String teacherId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? documentUrl;
  final String? documentName;
  final String? youtubeLink;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TugasHarian({
    required this.id,
    required this.teacherId,
    required this.title,
    this.description,
    this.dueDate,
    this.documentUrl,
    this.documentName,
    this.youtubeLink,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TugasHarian.fromJson(Map<String, dynamic> json) {
    return TugasHarian(
      id: json['id']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      documentUrl: json['document_url']?.toString(),
      documentName: json['document_name']?.toString(),
      youtubeLink: json['youtube_link']?.toString(),
      status: json['status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
    );
  }

  bool get isActive => status == 'active';
  bool get isOverdue =>
      isActive && dueDate != null && DateTime.now().isAfter(dueDate!);
  bool get hasDocument => documentUrl != null && documentUrl!.isNotEmpty;
  bool get hasYoutube => youtubeLink != null && youtubeLink!.isNotEmpty;

  int get daysLeft =>
      dueDate != null ? dueDate!.difference(DateTime.now()).inDays : 0;

  String get dueDateFormatted {
    if (dueDate == null) return '-';
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dueDate!.day} ${bulan[dueDate!.month - 1]} ${dueDate!.year}';
  }
}

// ═══════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════

/// Fetch semua tugas harian milik guru yang login.
final tugasHarianProvider = FutureProvider<List<TugasHarian>>((ref) async {
  final guruStaffId = await ref.watch(currentGuruStaffIdProvider.future);
  if (guruStaffId == null) return const [];

  final cache = ref.watch(offlineCacheServiceProvider);
  final cacheKey = 'tugas_$guruStaffId';

  try {
    final dio = ref.watch(dioClientProvider);
    final res = await dio.get(
      ApiConstants.tugasHarianTable,
      queryParameters: {
        'teacher_id': 'eq.$guruStaffId',
        'select': '*',
        'order': 'created_at.desc',
      },
    );

    final List data = res.data is List ? res.data : [];
    // Cache the raw response
    await cache.cacheResponse(cacheKey, jsonEncode(data));
    return data
        .map((json) => TugasHarian.fromJson(json as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    // Offline — try cache
    final cached = await cache.getCachedResponse(cacheKey);
    if (cached != null) {
      final List decoded = jsonDecode(cached);
      return decoded
          .map((json) => TugasHarian.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat tugas: ${e.message ?? 'tidak diketahui'}');
  }
});

/// Jumlah tugas aktif (belum lewat deadline).
final activeTugasCountProvider = Provider<int>((ref) {
  return ref.watch(tugasHarianProvider).maybeWhen(
        data: (list) => list.where((t) => t.isActive && !t.isOverdue).length,
        orElse: () => 0,
      );
});

// ═══════════════════════════════════════════════════════════════
// NOTIFIER (CRUD + FILE UPLOAD)
// ═══════════════════════════════════════════════════════════════

class TugasHarianNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  TugasHarianNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Check if device is online.
  static Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Upload dokumen ke Supabase Storage bucket `tugas-documents`.
  /// Maks 10 MB.
  Future<String?> _uploadDocument(File file, String fileName) async {
    try {
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) return null; // > 10MB

      final ext = fileName.split('.').last;
      final storagePath =
          '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(' ', '_')}';
      final uploadUrl =
          '${ApiConstants.supabaseUrl}/storage/v1/object/tugas-documents/$storagePath';

      final bytes = await file.readAsBytes();
      final dio = Dio();
      await dio.post(
        uploadUrl,
        data: Stream.fromIterable(bytes.map((e) => [e])),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiConstants.supabaseAnonKey}',
            'apikey': ApiConstants.supabaseAnonKey,
            'Content-Type': _getMimeType(ext),
            'x-upsert': 'true',
          },
          contentType: _getMimeType(ext),
        ),
      );

      return '${ApiConstants.supabaseUrl}/storage/v1/object/public/tugas-documents/$storagePath';
    } catch (_) {
      return null;
    }
  }

  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.ms-powerpoint';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  Future<bool> createTugas({
    required String title,
    String? description,
    DateTime? dueDate,
    String? youtubeLink,
    File? documentFile,
    String? documentFileName,
  }) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      final guruStaffId =
          await _ref.read(currentGuruStaffIdProvider.future);
      if (guruStaffId == null) {
        state = AsyncValue.error(
            'Guru staff ID tidak ditemukan', StackTrace.current);
        return false;
      }

      String? docUrl;
      if (documentFile != null && documentFileName != null) {
        docUrl = await _uploadDocument(documentFile, documentFileName);
      }

      final dio = _ref.read(dioClientProvider);
      await dio.post(
        ApiConstants.tugasHarianTable,
        data: {
          'teacher_id': guruStaffId,
          'title': title,
          'description': description,
          'due_date': dueDate?.toIso8601String().split('T').first,
          'youtube_link': youtubeLink,
          'document_url': docUrl,
          'document_name': documentFileName,
          'status': 'active',
        },
      );

      _ref.invalidate(tugasHarianProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateTugas({
    required String id,
    required String title,
    String? description,
    DateTime? dueDate,
    String? youtubeLink,
    File? documentFile,
    String? documentFileName,
    String? existingDocUrl,
    String? existingDocName,
  }) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      String? docUrl = existingDocUrl;
      String? docName = existingDocName;

      if (documentFile != null && documentFileName != null) {
        docUrl = await _uploadDocument(documentFile, documentFileName);
        docName = documentFileName;
      }

      final dio = _ref.read(dioClientProvider);
      await dio.patch(
        ApiConstants.tugasHarianTable,
        queryParameters: {'id': 'eq.$id'},
        data: {
          'title': title,
          'description': description,
          'due_date': dueDate?.toIso8601String().split('T').first,
          'youtube_link': youtubeLink,
          'document_url': docUrl,
          'document_name': docName,
        },
      );

      _ref.invalidate(tugasHarianProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteTugas(String id) async {
    if (!await _isOnline()) {
      state = AsyncValue.error('Anda sedang offline', StackTrace.current);
      return false;
    }
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioClientProvider);
      await dio.delete(
        ApiConstants.tugasHarianTable,
        queryParameters: {'id': 'eq.$id'},
      );

      _ref.invalidate(tugasHarianProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final tugasHarianNotifierProvider =
    StateNotifierProvider<TugasHarianNotifier, AsyncValue<void>>((ref) {
  return TugasHarianNotifier(ref);
});
