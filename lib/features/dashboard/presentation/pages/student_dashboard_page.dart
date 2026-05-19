import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../assignments/providers/assignments_provider.dart';
import '../../../exams/providers/exams_provider.dart';
import '../../../attendance/providers/attendance_provider.dart';
import '../../../announcements/presentation/pages/announcements_page.dart';
import '../../../announcements/providers/announcements_provider.dart';
import '../../../subjects/providers/subjects_provider.dart';
import '../../../library/providers/library_provider.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/menu_grid_item.dart';
import '../widgets/dashboard_slider.dart';

class StudentDashboardPage extends ConsumerWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final pendingTasks = ref.watch(pendingAssignmentsCountProvider);
    final upcomingExams = ref.watch(upcomingExamsCountProvider);
    final summary = ref.watch(attendanceSummaryProvider);
    final todaySchedule = ref.watch(todayScheduleProvider);
    final announcementsAsync = ref.watch(announcementsProvider);
    final activeLoans = ref.watch(activeLoanCountProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(subjectsProvider);
          ref.invalidate(announcementsProvider);
          ref.invalidate(assignmentsProvider);
          ref.invalidate(examsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // ── Header ──
            DashboardHeader(
              userName: user?.name ?? 'Siswa',
              avatarUrl: user?.avatarUrl ?? (user?.id != null ? '${ApiConstants.supabaseUrl}/storage/v1/object/public/student-photos/${user!.id}.jpg' : null),
              subtitle: user?.role.displayName ?? 'Siswa',
              roleColor: AppColors.primary,
            ),

            const SizedBox(height: 16),
            const DashboardSlider(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Quick Stats ──
                  Row(
                    children: [
                      _StatMini(
                        icon: Icons.check_circle_outline,
                        label: 'Kehadiran',
                        value: '${summary.percentage.toStringAsFixed(0)}%',
                        color: AppColors.kehadiranColor,
                      ),
                      const SizedBox(width: 10),
                      _StatMini(
                        icon: Icons.assignment_outlined,
                        label: 'Tugas',
                        value: '$pendingTasks pending',
                        color: AppColors.tugasColor,
                      ),
                      const SizedBox(width: 10),
                      _StatMini(
                        icon: Icons.quiz_outlined,
                        label: 'Ujian',
                        value: '$upcomingExams akan datang',
                        color: AppColors.ujianColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Menu Grid ──
                  Text('Menu Siswa', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                    children: [
                      MenuGridItem(
                        icon: Icons.menu_book_rounded,
                        label: 'Pelajaran',
                        gradient: AppColors.pelajaranGradient,
                        onTap: () => context.push('/subjects'),
                      ),
                      MenuGridItem(
                        icon: Icons.fact_check_rounded,
                        label: 'Kehadiran',
                        gradient: AppColors.kehadiranGradient,
                        onTap: () => context.push('/attendance'),
                      ),
                      MenuGridItem(
                        icon: Icons.assignment_rounded,
                        label: 'Tugas',
                        gradient: AppColors.tugasGradient,
                        onTap: () => context.push('/assignments'),
                        badgeCount: pendingTasks > 0 ? pendingTasks : null,
                      ),
                      MenuGridItem(
                        icon: Icons.quiz_rounded,
                        label: 'Ujian',
                        gradient: AppColors.ujianGradient,
                        onTap: () => context.push('/exams'),
                        badgeCount: upcomingExams > 0 ? upcomingExams : null,
                      ),
                      MenuGridItem(
                        icon: Icons.mosque_rounded,
                        label: 'Keagamaan',
                        gradient: AppColors.keagamaanGradient,
                        onTap: () => context.push('/religious'),
                      ),
                      MenuGridItem(
                        icon: Icons.campaign_rounded,
                        label: 'Pengumuman',
                        gradient: AppColors.pengumumanGradient,
                        onTap: () => context.push('/announcements'),
                      ),
                      MenuGridItem(
                        icon: Icons.local_library_rounded,
                        label: 'Perpustakaan',
                        gradient: AppColors.perpustakaanGradient,
                        onTap: () => context.push('/library'),
                        badgeCount: activeLoans > 0 ? activeLoans : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Today's Schedule ──
                  Row(
                    children: [
                      Text('Jadwal Hari Ini', style: Theme.of(context).textTheme.headlineSmall),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.push('/subjects'),
                        child: Text('Lihat Semua', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (todaySchedule.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.event_available, size: 36, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          Text('Tidak ada jadwal hari ini', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: todaySchedule.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final s = todaySchedule[i];
                          return Container(
                            width: 180,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: s.color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: s.color.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(s.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: s.color)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Icon(Icons.access_time, size: 12, color: s.color.withOpacity(0.7)),
                                    const SizedBox(width: 4),
                                    Text(s.time, style: TextStyle(fontSize: 11, color: s.color.withOpacity(0.8))),
                                  ]),
                                ]),
                                Row(children: [
                                  Icon(Icons.room_outlined, size: 12, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(s.room, style: TextStyle(fontSize: 11, color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
                                ]),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ── Recent Announcements ──
                  Row(
                    children: [
                      Text('Pengumuman Terbaru', style: Theme.of(context).textTheme.headlineSmall),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.push('/announcements'),
                        child: Text('Lihat Semua', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  announcementsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                    data: (announcements) {
                      final recent = announcements.take(2).toList();
                      return Column(
                        children: recent.map((a) {
                          return GestureDetector(
                            onTap: () => showAnnouncementDetail(context, a),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                              ),
                              child: Row(children: [
                                Container(
                                  width: 4, height: 40,
                                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(a.judul, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Text(a.timeAgo, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ])),
                                Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                              ]),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatMini({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}
