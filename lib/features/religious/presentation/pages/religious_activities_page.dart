import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/religious_provider.dart';

class ReligiousActivitiesPage extends ConsumerWidget {
  const ReligiousActivitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(religiousActivitiesProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Kegiatan Keagamaan'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(religiousActivitiesProvider);
          await ref.read(religiousActivitiesProvider.future);
        },
        child: activitiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  const Text('Gagal memuat kegiatan'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(religiousActivitiesProvider),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
          data: (activities) {
            if (activities.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.mosque_rounded, size: 64, color: AppColors.textMuted.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        const Text('Belum ada kegiatan keagamaan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Hero card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.keagamaanGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: AppColors.keagamaanColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.mosque_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Program Keagamaan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${activities.length} kegiatan tersedia', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 20),
                ...activities.map((a) => _ActivityCard(activity: a)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ReligiousActivity activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppColors.keagamaanColor.withOpacity(0.1), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.mosque_rounded, color: AppColors.keagamaanColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(activity.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (activity.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(activity.description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 4),
            Row(children: [
              if (activity.time != null && activity.time!.isNotEmpty) ...[
                const Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(activity.time!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 10),
              ],
              const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Flexible(child: Text(activity.location, style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.keagamaanColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(activity.status, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.keagamaanColor)),
          ),
        ]),
      ),
    );
  }
}
