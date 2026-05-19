import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../storage/secure_storage_service.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/pages/parent_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/student_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/teacher_dashboard_page.dart';
import '../../features/profile/presentation/pages/about_page.dart';
import '../../features/profile/presentation/pages/help_page.dart';
import '../../features/profile/presentation/pages/notification_settings_page.dart';
import '../../features/profile/presentation/pages/profile_info_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/students/pages/students_list_page.dart';
import '../../features/subjects/presentation/pages/subjects_page.dart';
import '../../features/attendance/presentation/pages/attendance_page.dart';
import '../../features/assignments/presentation/pages/assignments_page.dart';
import '../../features/exams/presentation/pages/exams_page.dart';
import '../../features/exams/presentation/pages/teacher_exams_page.dart';
import '../../features/religious/presentation/pages/religious_activities_page.dart';
import '../../features/announcements/presentation/pages/announcements_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/attendance/class_attendance/presentation/pages/class_attendance_page.dart';
import '../../features/attendance/presentation/pages/teacher_self_attendance_page.dart';
import '../../features/grades/presentation/pages/grade_management_page.dart';
import '../../features/tugas_harian/presentation/pages/tugas_harian_page.dart';
import '../../features/agenda_guru/presentation/pages/agenda_guru_page.dart';
import '../../features/kegiatan_keagamaan/presentation/pages/kegiatan_keagamaan_page.dart';
import '../../shared/widgets/main_scaffold.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

/// Custom page transition — slide up dari bawah + scale + fade.
/// Agresif supaya terasa smooth dan terlihat jelas. Mirip Telegram/WhatsApp.
CustomTransitionPage<void> _buildSmoothPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnim = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInQuart,
      );

      // Slide dari bawah 15% layar.
      final slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(curvedAnim);

      // Scale dari 92% ke 100%.
      final scaleAnim = Tween<double>(
        begin: 0.92,
        end: 1.0,
      ).animate(curvedAnim);

      // Fade in.
      final fadeAnim = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ));

      return FadeTransition(
        opacity: fadeAnim,
        child: SlideTransition(
          position: slideAnim,
          child: ScaleTransition(
            scale: scaleAnim,
            child: child,
          ),
        ),
      );
    },
  );
}

/// Flag bahwa user baru saja sukses login dan butuh splash untuk
/// pre-fetch data sebelum landing ke dashboard.
final pendingPostLoginPrefetchProvider = StateProvider<bool>((ref) => false);

final _pendingRestoreRouteProvider = StateProvider<String?>((ref) => null);

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        _loadLastRoute();
      }
      notifyListeners();
    });
  }

  Future<void> _loadLastRoute() async {
    final storage = _ref.read(secureStorageServiceProvider);
    final lastRoute = await storage.getLastRoute();
    if (lastRoute != null &&
        lastRoute != '/dashboard' &&
        lastRoute != '/splash' &&
        lastRoute != '/login') {
      _ref.read(_pendingRestoreRouteProvider.notifier).state = lastRoute;
    }
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  final storage = ref.watch(secureStorageServiceProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final path = state.uri.path;
      final isAuth = authState.status == AuthStatus.authenticated;
      final isInitial = authState.status == AuthStatus.initial;
      final isLoading = authState.status == AuthStatus.loading;

      if (isInitial || (isLoading && path == '/splash')) return null;
      if (!isAuth && path != '/login') return '/login';
      if (isAuth && path == '/login') {
        // Baru saja sukses login → lewat splash dulu untuk pre-fetch
        // data sebelum landing ke dashboard.
        ref.read(pendingPostLoginPrefetchProvider.notifier).state = true;
        return '/splash';
      }
      if (isAuth && path == '/splash') {
        // Splash akan handle pre-fetch sendiri lalu redirect ke
        // dashboard via context.go saat selesai. Tidak perlu force
        // redirect dari sini.
        return null;
      }

      // Role-based access guard — kalau user mencoba akses route yang
      // bukan untuk role-nya (mis. murid akses /students), arahkan
      // kembali ke dashboard.
      if (isAuth &&
          path != '/splash' &&
          path != '/login' &&
          !_isRouteAllowedForRole(path, authState.user?.role)) {
        return '/dashboard';
      }

      if (isAuth && path != '/splash' && path != '/login') {
        storage.saveLastRoute(path);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/teacher-self-attendance',
        builder: (_, __) => const TeacherSelfAttendancePage(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (_, __, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) {
              final role = ref.watch(currentUserRoleProvider);
              switch (role) {
                case UserRole.murid:
                  return const StudentDashboardPage();
                case UserRole.orangtua:
                  return const ParentDashboardPage();
                case UserRole.guru:
                  return const TeacherDashboardPage();
                default:
                  return const StudentDashboardPage();
              }
            },
          ),
          GoRoute(path: '/students', builder: (_, __) => const StudentsListPage()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
          GoRoute(
            path: '/profile/info',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const ProfileInfoPage(),
            ),
          ),
          GoRoute(
            path: '/profile/notifications',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const NotificationSettingsPage(),
            ),
          ),
          GoRoute(
            path: '/profile/help',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const HelpPage(),
            ),
          ),
          GoRoute(
            path: '/profile/about',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const AboutPage(),
            ),
          ),
          GoRoute(
            path: '/subjects',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const SubjectsPage(),
            ),
          ),
          GoRoute(
            path: '/attendance',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const AttendancePage(),
            ),
          ),
          GoRoute(
            path: '/assignments',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const AssignmentsPage(),
            ),
          ),
          GoRoute(
            path: '/exams',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const ExamsPage(),
            ),
          ),
          GoRoute(
            path: '/religious',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const ReligiousActivitiesPage(),
            ),
          ),
          GoRoute(
            path: '/announcements',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const AnnouncementsPage(),
            ),
          ),
          GoRoute(
            path: '/library',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const LibraryPage(),
            ),
          ),
          GoRoute(
            path: '/teacher-attendance',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const ClassAttendancePage(),
            ),
          ),
          GoRoute(
            path: '/grades',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const GradeManagementPage(),
            ),
          ),
          GoRoute(
            path: '/tugas-harian',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const TugasHarianPage(),
            ),
          ),
          GoRoute(
            path: '/agenda-guru',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const AgendaGuruPage(),
            ),
          ),
          GoRoute(
            path: '/kegiatan-keagamaan',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const KegiatanKeagamaanPage(),
            ),
          ),
          GoRoute(
            path: '/teacher-exams',
            pageBuilder: (_, state) => _buildSmoothPage(
              key: state.pageKey,
              child: const TeacherExamsPage(),
            ),
          ),
        ],
      ),
    ],
  );
});

/// Daftar route yang boleh diakses oleh setiap role. Route yang tidak
/// listed di sini dianggap shared (boleh semua) — misalnya `/profile`.
const Set<String> _muridOnlyRoutes = {
  '/subjects',
  '/library',
  '/attendance',
  '/assignments',
  '/exams',
  '/religious',
};

const Set<String> _guruOrtuOnlyRoutes = {
  '/students',
  '/announcements',
};

const Set<String> _guruOnlyRoutes = {
  '/teacher-attendance',
  '/teacher-self-attendance',
  '/grades',
  '/tugas-harian',
  '/agenda-guru',
  '/kegiatan-keagamaan',
  '/teacher-exams',
};

/// Cek apakah `path` boleh diakses oleh `role`. Route yang bersifat
/// universal (mis. /dashboard, /profile, /splash, /login) selalu OK.
bool _isRouteAllowedForRole(String path, UserRole? role) {
  // Universal routes — boleh semua role.
  const universal = {
    '/dashboard',
    '/profile',
    '/splash',
    '/login',
    // Pengumuman shared untuk semua role — semua user butuh lihat
    // pengumuman sekolah.
    '/announcements',
  };
  if (universal.contains(path)) return true;
  // Sub-pages di /profile (info, notifications, help, about) juga
  // universal — semua role boleh akses.
  if (path.startsWith('/profile/')) return true;

  switch (role) {
    case UserRole.murid:
      return _muridOnlyRoutes.contains(path);
    case UserRole.guru:
      return _guruOrtuOnlyRoutes.contains(path) ||
          _guruOnlyRoutes.contains(path);
    case UserRole.orangtua:
      return _guruOrtuOnlyRoutes.contains(path);
    default:
      return false;
  }
}
