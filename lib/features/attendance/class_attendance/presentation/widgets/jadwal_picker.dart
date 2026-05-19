import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../schedule/providers/schedule_provider.dart';
import '../design/attendance_tokens.dart';

class JadwalPicker extends ConsumerWidget {
  const JadwalPicker({
    super.key,
    required this.onSelected,
  });

  final void Function(JadwalPelajaran jadwal) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayScheduleProvider);
    final allAsync = ref.watch(myJadwalProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allJadwalProvider);
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _SectionHeader(
            icon: Icons.event_available_rounded,
            title: 'Jadwal Hari Ini',
          ),
          const SizedBox(height: 12),
          todayAsync.when(
            loading: () => _shimmer(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (list) {
              if (list.isEmpty) {
                return _EmptyCard(
                  title: 'Tidak ada kelas hari ini',
                  subtitle:
                      'Pilih jadwal lain di bawah jika ingin absen di luar hari ini.',
                );
              }
              return Column(
                children: list
                    .map((j) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _JadwalCard(
                            jadwal: j,
                            highlight: true,
                            onTap: () => onSelected(j),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.view_list_rounded,
            title: 'Semua Jadwal Saya',
          ),
          const SizedBox(height: 12),
          allAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (list) {
              if (list.isEmpty) {
                return _EmptyCard(
                  title: 'Belum ada jadwal',
                  subtitle:
                      'Hubungi admin sekolah untuk menambahkan jadwal mengajar Anda.',
                );
              }
              return Column(
                children: list
                    .map((j) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _JadwalCard(
                            jadwal: j,
                            highlight: false,
                            onTap: () => onSelected(j),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _shimmer() {
    return Column(
      children: List.generate(
        2,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius:
                BorderRadius.circular(AttendanceTokens.cornerRadius),
          ),
        ),
      ),
    );
  }
}

class _JadwalCard extends StatelessWidget {
  const _JadwalCard({
    required this.jadwal,
    required this.highlight,
    required this.onTap,
  });
  final JadwalPelajaran jadwal;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AttendanceTokens.cornerRadius),
      elevation: highlight ? 2 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(AttendanceTokens.cornerRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 54,
                decoration: BoxDecoration(
                  color: jadwal.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: jadwal.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book_rounded,
                    color: jadwal.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jadwal.mataPelajaran,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${jadwal.kelas} • ${jadwal.jamRange} • ${jadwal.ruangan}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (highlight)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: jadwal.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    jadwal.hari,
                    style: TextStyle(
                      color: jadwal.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AttendanceTokens.cornerRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_rounded,
              size: 34, color: AppColors.textMuted.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AttendanceTokens.cornerRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
