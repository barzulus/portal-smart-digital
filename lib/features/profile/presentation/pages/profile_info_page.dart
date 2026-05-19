import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/profile_info_provider.dart';

/// Halaman view-only data lengkap user. Edit hanya bisa dilakukan
/// oleh admin sekolah.
class ProfileInfoPage extends ConsumerWidget {
  const ProfileInfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(profileInfoProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Info Profil'),
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profileInfoProvider);
          await ref.read(profileInfoProvider.future);
        },
        child: infoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildError(context, ref, '$e'),
          data: (info) => _buildContent(context, info),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProfileInfo info) {
    final initial = info.namaLengkap.isNotEmpty
        ? info.namaLengkap[0].toUpperCase()
        : '?';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Hero card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    (info.avatarUrl != null && info.avatarUrl!.isNotEmpty)
                        ? NetworkImage(info.avatarUrl!)
                        : null,
                child: (info.avatarUrl == null || info.avatarUrl!.isEmpty)
                    ? Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.namaLengkap,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        info.role,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.email,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Notice card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.info.withValues(alpha: 0.2),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data ini hanya dapat diubah oleh admin sekolah. '
                  'Hubungi admin jika ada perubahan informasi.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.info,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section: detail
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DETAIL DATA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Nama Lengkap',
                value: info.namaLengkap,
              ),
              _Divider(),
              _DetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: info.email,
              ),
              ...info.details.entries
                  .where(
                    (e) => e.value != null && e.value!.trim().isNotEmpty,
                  )
                  .expand(
                    (e) => [
                      _Divider(),
                      _DetailRow(
                        icon: _iconFor(e.key),
                        label: e.key,
                        value: e.value!,
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconFor(String label) {
    switch (label) {
      case 'NIS':
      case 'NISN':
      case 'NIP':
        return Icons.badge_outlined;
      case 'Kelas':
        return Icons.class_outlined;
      case 'Jenis Kelamin':
        return Icons.wc_outlined;
      case 'Tempat Lahir':
        return Icons.place_outlined;
      case 'Tanggal Lahir':
        return Icons.cake_outlined;
      case 'Alamat':
        return Icons.home_outlined;
      case 'Nama Orang Tua':
        return Icons.family_restroom_outlined;
      case 'No. Telp Orang Tua':
      case 'No. Telp':
        return Icons.phone_outlined;
      case 'Jabatan':
        return Icons.work_outline_rounded;
      case 'Status':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.info_outline;
    }
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
                  'Gagal memuat data profil',
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
                  onPressed: () => ref.invalidate(profileInfoProvider),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 14,
      endIndent: 14,
      color: AppColors.divider,
    );
  }
}
