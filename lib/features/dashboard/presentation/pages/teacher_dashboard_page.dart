import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../announcements/presentation/pages/announcements_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/guru_staff_provider.dart';
import '../../../announcements/providers/announcements_provider.dart';
import '../../../students/providers/students_provider.dart';
import '../../../schedule/providers/schedule_provider.dart';
import '../../../tugas_harian/providers/tugas_harian_provider.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/menu_grid_item.dart';
import '../widgets/dashboard_slider.dart';

class TeacherDashboardPage extends ConsumerWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final announcementsAsync = ref.watch(announcementsProvider);
    final myStudents = ref.watch(myStudentsProvider);
    final myClasses = ref.watch(teacherClassesProvider);
    final todayAsync = ref.watch(todayScheduleProvider);
    final weeklyAsync = ref.watch(weeklyScheduleProvider);
    final activeTugas = ref.watch(activeTugasCountProvider);
    final guruPhotoAsync = ref.watch(guruPhotoUrlProvider);
    
    final totalSiswa = myStudents.maybeWhen(
      data: (students) => students.length.toString(),
      orElse: () => '-',
    );

    final totalKelas = myClasses.maybeWhen(
      data: (classes) => classes.length.toString(),
      orElse: () => '-',
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allJadwalProvider);
          ref.invalidate(studentsProvider);
          ref.invalidate(announcementsProvider);
          // Wait a moment for providers to refetch
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardHeader(
                userName: user?.name ?? 'Guru',
                avatarUrl: guruPhotoAsync.maybeWhen(
                  data: (url) => url,
                  orElse: () => user?.avatarUrl,
                ),
                subtitle: '$totalKelas Kelas  •  $totalSiswa Siswa',
                roleColor: AppColors.guruColor,
              ),
              
              const SizedBox(height: 16),
              const DashboardSlider(),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Quick Stats (synced with teacher's data) ──
                    Row(children: [
                      _StatMini(icon: Icons.people, label: 'Siswa Saya', value: totalSiswa, color: AppColors.siswaColor),
                      const SizedBox(width: 10),
                      _StatMini(icon: Icons.class_rounded, label: 'Kelas', value: totalKelas, color: AppColors.kehadiranColor),
                      const SizedBox(width: 10),
                      _StatMini(icon: Icons.assignment, label: 'Tugas Aktif', value: '$activeTugas', color: AppColors.tugasColor),
                    ]),

                  const SizedBox(height: 24),

                  // ── Menu Grid ──
                  Text('Menu Guru', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82,
                    children: [
                      MenuGridItem(icon: Icons.people_rounded, label: 'Data Siswa', gradient: AppColors.pelajaranGradient, onTap: () => context.go('/students')),
                      MenuGridItem(icon: Icons.edit_note_rounded, label: 'Input Nilai', gradient: AppColors.tugasGradient, onTap: () => context.push('/grades')),
                      MenuGridItem(icon: Icons.fact_check_rounded, label: 'Absensi', gradient: AppColors.kehadiranGradient, onTap: () => context.push('/teacher-attendance')),
                      MenuGridItem(icon: Icons.campaign_rounded, label: 'Pengumuman', gradient: AppColors.pengumumanGradient, onTap: () => context.go('/announcements')),
                      MenuGridItem(icon: Icons.assignment_rounded, label: 'Tugas', gradient: AppColors.tugasGradient, onTap: () => context.push('/tugas-harian')),
                      MenuGridItem(icon: Icons.quiz_rounded, label: 'Ujian', gradient: AppColors.ujianGradient, onTap: () => context.push('/teacher-exams')),
                      MenuGridItem(icon: Icons.event_note_rounded, label: 'Agenda', gradient: AppColors.keagamaanGradient, onTap: () => context.push('/agenda-guru')),
                      MenuGridItem(icon: Icons.mosque_rounded, label: 'Keagamaan', gradient: AppColors.perpustakaanGradient, onTap: () => context.push('/kegiatan-keagamaan')),
                      MenuGridItem(icon: Icons.fingerprint_rounded, label: 'Absen Guru', gradient: AppColors.absenGuruGradient, onTap: () => context.push('/teacher-self-attendance')),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Jadwal Mengajar Hari Ini (from Supabase) ──
                  Row(
                    children: [
                      Text('Jadwal Mengajar Hari Ini', style: Theme.of(context).textTheme.headlineSmall),
                      const Spacer(),
                      todayAsync.when(
                        data: (list) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${list.length} Kelas', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                        loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        error: (_, __) => const SizedBox(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  todayAsync.when(
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                    error: (e, _) => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Gagal memuat jadwal: $e', style: const TextStyle(fontSize: 12, color: AppColors.error))),
                        ],
                      ),
                    ),
                    data: (todaySchedule) {
                      if (todaySchedule.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.event_available, size: 32, color: AppColors.textMuted),
                                SizedBox(height: 8),
                                Text('Tidak ada jadwal hari ini', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      }

                      // Determine which class is currently active
                      final now = DateTime.now();
                      final currentMinute = now.hour * 60 + now.minute;

                      return Column(
                        children: todaySchedule.asMap().entries.map((entry) {
                          final s = entry.value;
                          
                          // Parse jam_mulai and jam_selesai to determine if currently active
                          bool isNow = false;
                          try {
                            final startParts = s.jamMulai.split(':');
                            final endParts = s.jamSelesai.split(':');
                            final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
                            final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
                            isNow = currentMinute >= startMin && currentMinute <= endMin;
                          } catch (_) {}

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: isNow ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5) : null,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4, height: 48,
                                  decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: s.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Center(child: Icon(Icons.menu_book_rounded, size: 20, color: s.color)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(child: Text(s.mataPelajaran, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                          if (isNow) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('Sedang Berlangsung', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.success)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('${s.kelas}  •  ${s.ruangan}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
                                    const SizedBox(height: 4),
                                    Text(s.jamRange, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Jadwal Pembelajaran Mingguan (from Supabase) ──
                  Text('Jadwal Pembelajaran Saya', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  weeklyAsync.when(
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                    error: (e, _) => Text('Gagal memuat: $e', style: const TextStyle(color: AppColors.error)),
                    data: (weeklySchedule) {
                      if (weeklySchedule.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(child: Text('Belum ada jadwal', style: TextStyle(color: AppColors.textMuted))),
                        );
                      }

                      return Column(
                        children: weeklySchedule.map((day) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                childrenPadding: const EdgeInsets.only(bottom: 8),
                                leading: Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.headerGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      day.hari.length >= 3 ? day.hari.substring(0, 3) : day.hari,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                                title: Text(day.hari, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                subtitle: Text('${day.jadwalList.length} Mata Pelajaran', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                children: day.jadwalList.map((s) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4, height: 36,
                                          decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${s.mataPelajaran} — ${s.kelas}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 2),
                                              Text('${s.jamRange}  •  ${s.ruangan}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Pengumuman ──
                  Text('Pengumuman Terbaru', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  announcementsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                    data: (list) => Column(
                      children: list.take(3).map((a) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            elevation: 0,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => showAnnouncementDetail(context, a),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a.judul,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            a.timeAgo,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (a.hasAttachment)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: Icon(
                                          Icons.attach_file_rounded,
                                          size: 14,
                                          color: AppColors.info
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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
  final IconData icon; final String label; final String value; final Color color;
  const _StatMini({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ]),
    ));
  }
}
