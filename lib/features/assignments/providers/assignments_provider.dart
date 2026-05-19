import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/presentation/providers/auth_provider.dart';

enum AssignmentStatus { pending, submitted, graded }

class AssignmentData {
  final String id;
  final String title;
  final String subject;
  final String description;
  final DateTime deadline;
  final AssignmentStatus status;
  final double? grade;
  final String teacher;
  final String? youtubeLink;
  final String? documentUrl;
  final String? documentName;

  const AssignmentData({
    required this.id,
    required this.title,
    required this.subject,
    required this.description,
    required this.deadline,
    required this.status,
    this.grade,
    required this.teacher,
    this.youtubeLink,
    this.documentUrl,
    this.documentName,
  });

  factory AssignmentData.fromJson(Map<String, dynamic> json, {bool isCompleted = false}) {
    return AssignmentData(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subject: '', // tugas_harian doesn't have subject field
      description: json['description']?.toString() ?? '',
      deadline: DateTime.tryParse(json['due_date']?.toString() ?? '') ?? DateTime.now(),
      status: isCompleted ? AssignmentStatus.submitted : AssignmentStatus.pending,
      teacher: '', // Could join with guru_staff if needed
      youtubeLink: json['youtube_link']?.toString(),
      documentUrl: json['document_url']?.toString(),
      documentName: json['document_name']?.toString(),
    );
  }

  String get statusLabel {
    switch (status) {
      case AssignmentStatus.pending:
        return 'Belum Dikerjakan';
      case AssignmentStatus.submitted:
        return 'Sudah Dikumpulkan';
      case AssignmentStatus.graded:
        return 'Sudah Dinilai';
    }
  }

  bool get isOverdue =>
      status == AssignmentStatus.pending && DateTime.now().isAfter(deadline);

  int get daysLeft => deadline.difference(DateTime.now()).inDays;
}

/// Fetch tugas harian yang aktif (untuk siswa).
/// Tabel: tugas_harian (status = 'active').
/// Siswa melihat semua tugas aktif dari guru di sekolahnya.
final assignmentsProvider = FutureProvider<List<AssignmentData>>((ref) async {
  final idSekolah = ref.watch(currentIdSekolahProvider);
  final user = ref.watch(authProvider).user;
  if (idSekolah == null || user == null) return const [];

  try {
    final dio = ref.watch(dioClientProvider);

    // Fetch tugas aktif — join dengan guru_staff untuk nama guru
    final res = await dio.get(
      ApiConstants.tugasHarianTable,
      queryParameters: {
        'status': 'eq.active',
        'select': '*,guru_staff:teacher_id(nama,id_sekolah)',
        'order': 'due_date.asc.nullslast,created_at.desc',
      },
    );

    final List data = res.data is List ? res.data : [];

    // Filter hanya tugas dari guru di sekolah yang sama
    final assignments = <AssignmentData>[];
    for (final json in data) {
      final map = json as Map<String, dynamic>;
      final guruStaff = map['guru_staff'];
      if (guruStaff is Map && guruStaff['id_sekolah'] == idSekolah) {
        assignments.add(AssignmentData(
          id: map['id']?.toString() ?? '',
          title: map['title']?.toString() ?? '',
          subject: '',
          description: map['description']?.toString() ?? '',
          deadline: DateTime.tryParse(map['due_date']?.toString() ?? '') ?? DateTime.now(),
          status: AssignmentStatus.pending,
          teacher: guruStaff['nama']?.toString() ?? '',
          youtubeLink: map['youtube_link']?.toString(),
          documentUrl: map['document_url']?.toString(),
          documentName: map['document_name']?.toString(),
        ));
      }
    }

    return assignments;
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return const [];
    throw Exception('Gagal memuat tugas: ${e.message ?? 'tidak diketahui'}');
  }
});

final pendingAssignmentsCountProvider = Provider<int>((ref) {
  final assignmentsAsync = ref.watch(assignmentsProvider);
  return assignmentsAsync.when(
    // Hanya hitung tugas pending yang BELUM lewat deadline.
    // Tugas yang lewat deadline tetap muncul di daftar (dengan badge
    // "Terlambat") tapi tidak dihitung sebagai "pending" di dashboard.
    data: (list) => list
        .where(
          (a) => a.status == AssignmentStatus.pending && !a.isOverdue,
        )
        .length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
