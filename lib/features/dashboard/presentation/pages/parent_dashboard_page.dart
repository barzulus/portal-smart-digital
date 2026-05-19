import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../announcements/providers/announcements_provider.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/menu_grid_item.dart';

class ParentDashboardPage extends ConsumerWidget {
  const ParentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final announcementsAsync = ref.watch(announcementsProvider);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardHeader(
              userName: user?.name ?? 'Orang Tua',
              subtitle: 'Pantau perkembangan anak Anda',
              roleColor: AppColors.orangtuaColor,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Child info card — TODO: fetch data anak dari relasi parent→student
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                    child: Row(children: [
                      CircleAvatar(radius: 22, backgroundColor: AppColors.siswaColor.withOpacity(0.1),
                        child: Icon(Icons.child_care_rounded, color: AppColors.siswaColor, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Data anak belum tersedia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 3),
                        Text('Hubungi admin untuk menghubungkan akun', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Text('Menu Orang Tua', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82,
                    children: [
                      MenuGridItem(icon: Icons.child_care_rounded, label: 'Data Anak', gradient: AppColors.pelajaranGradient, onTap: () {}),
                      MenuGridItem(icon: Icons.school_rounded, label: 'Nilai', gradient: AppColors.tugasGradient, onTap: () {}),
                      MenuGridItem(icon: Icons.fact_check_rounded, label: 'Kehadiran', gradient: AppColors.kehadiranGradient, onTap: () => context.push('/attendance')),
                      MenuGridItem(icon: Icons.campaign_rounded, label: 'Pengumuman', gradient: AppColors.pengumumanGradient, onTap: () => context.push('/announcements')),
                      MenuGridItem(icon: Icons.assignment_rounded, label: 'Tugas', gradient: AppColors.ujianGradient, onTap: () => context.push('/assignments')),
                      MenuGridItem(icon: Icons.quiz_rounded, label: 'Ujian', gradient: AppColors.keagamaanGradient, onTap: () => context.push('/exams')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Pengumuman Terbaru', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  announcementsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                    data: (list) => Column(
                      children: list.take(3).map((a) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
                          child: Row(children: [
                            Container(width: 4, height: 40, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a.judul, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(a.timeAgo, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ])),
                          ]),
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
    );
  }
}
