import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/exams_provider.dart';

/// Halaman daftar ujian — pure jadwal, sesuai dengan data yang tersedia
/// di DB (`ujian_quiz`). Tabel tidak menyimpan nilai/skor maupun status
/// pengerjaan, jadi UI fokus ke jadwal: kapan, di mana, jenis apa,
/// pengampu siapa.
class ExamsPage extends ConsumerWidget {
  const ExamsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Ujian'),
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(examsProvider);
          await ref.read(examsProvider.future);
        },
        child: examsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildError(context, ref, '$e'),
          data: (exams) {
            if (exams.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  _EmptyState(),
                ],
              );
            }

            // Pisah ujian akan datang & yang sudah lewat.
            final upcoming = exams.where((e) => !e.isPast).toList()
              ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
            final past = exams.where((e) => e.isPast).toList()
              ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (upcoming.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.event_rounded,
                    title: 'Akan Datang',
                    count: upcoming.length,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  ...upcoming.map((e) => _ExamCard(exam: e)),
                ],
                if (past.isNotEmpty) ...[
                  if (upcoming.isNotEmpty) const SizedBox(height: 16),
                  _SectionHeader(
                    icon: Icons.history_rounded,
                    title: 'Sudah Berlalu',
                    count: past.length,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 10),
                  ...past.map((e) => _ExamCard(exam: e, isPast: true)),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String msg) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gagal memuat ujian',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(examsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, this.isPast = false});
  final ExamData exam;
  final bool isPast;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  Color get _typeColor {
    switch (exam.type) {
      case ExamType.uts:
        return AppColors.ujianColor;
      case ExamType.uas:
        return AppColors.error;
      case ExamType.quiz:
        return AppColors.info;
      case ExamType.dailyTest:
        return AppColors.kehadiranColor;
      case ExamType.other:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor;
    // Saat ujian sudah lewat, semua warna dilemahkan supaya jelas
    // ter-de-prioritize.
    final accentColor = isPast ? AppColors.textMuted : color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date box
            Container(
              width: 56,
              height: 64,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${exam.tanggal.day}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _months[exam.tanggal.month - 1],
                    style: TextStyle(
                      fontSize: 11,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Chip(
                        text: exam.typeLabel,
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      _StatusBadge(exam: exam, isPast: isPast),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    exam.namaUjian,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isPast
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _Meta(
                        icon: Icons.access_time_rounded,
                        text: exam.jamRange,
                      ),
                      _Meta(
                        icon: Icons.room_outlined,
                        text: exam.ruangan,
                      ),
                      if (exam.durasiMenit > 0)
                        _Meta(
                          icon: Icons.timer_outlined,
                          text: '${exam.durasiMenit} menit',
                        ),
                      if (exam.guruNama != null && exam.guruNama!.isNotEmpty)
                        _Meta(
                          icon: Icons.person_outline_rounded,
                          text: exam.guruNama!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.exam, required this.isPast});
  final ExamData exam;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    if (isPast) {
      label = 'Selesai';
      color = AppColors.textMuted;
    } else if (exam.isToday) {
      label = 'Hari Ini';
      color = AppColors.warning;
    } else if (exam.daysLeft == 1) {
      label = 'Besok';
      color = AppColors.warning;
    } else {
      label = '${exam.daysLeft} hari lagi';
      color = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded,
              size: 38,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum ada jadwal ujian',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Jadwal ujian akan muncul di sini saat ditambahkan oleh sekolah.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
