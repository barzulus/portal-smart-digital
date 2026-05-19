import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../announcements/providers/announcements_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/guru_staff_provider.dart';
import '../../../schedule/providers/schedule_provider.dart';
import '../../../students/providers/students_provider.dart';
import '../../domain/entities/user_entity.dart';

/// Splash page dengan background putih + loading asli sampai data
/// critical selesai di-fetch dari Supabase.
///
/// Alur:
/// 1. First launch (initial) → cek auth status dari secure storage.
///    Kalau authenticated → pre-fetch data lalu navigate ke dashboard.
///    Kalau belum → navigate ke /login.
/// 2. Setelah login sukses dari halaman /login → router redirect ke
///    /splash, splash run pre-fetch flow yang sama lalu navigate ke
///    dashboard (atau last route kalau ada).
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  String _statusText = 'Memeriksa sesi...';
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_runStartupFlow);
  }

  Future<void> _runStartupFlow() async {
    final authBefore = ref.read(authProvider);

    // Hanya checkAuthStatus kalau belum authenticated. Kalau user baru
    // saja sukses login, status sudah authenticated dan kita langsung
    // pre-fetch.
    if (authBefore.status != AuthStatus.authenticated) {
      await ref.read(authProvider.notifier).checkAuthStatus();
    }
    if (!mounted) return;

    final auth = ref.read(authProvider);
    if (auth.status != AuthStatus.authenticated) {
      // Belum login → ke /login.
      _navigateTo('/login');
      return;
    }

    await _prefetchData(auth.user?.role);
    if (!mounted) return;

    // Selalu ke Home setelah prefetch — baik post-login maupun app restart.
    // User mau selalu landing di dashboard, bukan last route.
    ref.read(pendingPostLoginPrefetchProvider.notifier).state = false;
    if (!mounted) return;
    _navigateTo('/dashboard');
  }

  /// Pre-fetch data sesuai role supaya dashboard langsung ter-render
  /// tanpa loading state per-section.
  Future<void> _prefetchData(UserRole? role) async {
    if (!mounted) return;
    setState(() => _statusText = 'Memuat data sekolah...');

    final futures = <Future<void>>[
      _safe(() => ref.read(announcementsProvider.future)),
    ];

    switch (role) {
      case UserRole.guru:
        futures.addAll([
          _safe(() => ref.read(allJadwalProvider.future)),
          _safe(() => ref.read(currentGuruStaffIdProvider.future)),
          _safe(() => ref.read(studentsProvider.future)),
          _safe(() => ref.read(guruPhotoUrlProvider.future)),
          _safe(() => ref.read(teacherMapelNamesProvider.future)),
        ]);
        break;
      case UserRole.murid:
        futures.add(_safe(() => ref.read(allJadwalProvider.future)));
        break;
      case UserRole.orangtua:
        futures.add(_safe(() => ref.read(studentsProvider.future)));
        break;
      default:
        break;
    }

    await Future.wait(futures);
  }

  Future<void> _safe(Future Function() f) async {
    try {
      await f();
    } catch (_) {
      // Biar UI handle error per fitur sendiri saat user sampai di halaman.
    }
  }

  void _navigateTo(String path) {
    if (_navigated || !mounted) return;
    _navigated = true;
    // Pakai go agar history bersih (splash tidak boleh ada di stack).
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo card dengan soft shadow.
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Portal Smart Digital',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manajemen Sekolah Digital',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _statusText,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
