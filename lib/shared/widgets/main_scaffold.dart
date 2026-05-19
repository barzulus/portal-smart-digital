import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../features/announcements/presentation/pages/announcements_page.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/pages/parent_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/student_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/teacher_dashboard_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/students/pages/students_list_page.dart';
import '../../features/subjects/presentation/pages/subjects_page.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final items = _getNavItems(role);
    final routes = _getRoutes(role);

    final currentPath = GoRouterState.of(context).uri.path;
    int currentIndex = 0;
    for (int i = 0; i < routes.length; i++) {
      if (currentPath == routes[i]) {
        currentIndex = i;
        break;
      }
    }
    final isTabRoute = routes.contains(currentPath);

    // Sub-pages di /profile/* (info, notifications, help, about) dianggap
    // sebagai bagian dari tab Profil, supaya bottom nav highlight tab
    // Profil dan tidak nyangkut di Home.
    if (!isTabRoute && currentPath.startsWith('/profile/')) {
      final profileIdx = routes.indexOf('/profile');
      if (profileIdx >= 0) currentIndex = profileIdx;
    }

    final isOnHome = currentPath == '/dashboard';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        if (isOnHome) {
          // Di Home → tanya keluar app.
          final shouldPop = await showDialog<bool>(
            context: context,
            barrierColor: Colors.black54,
            builder: (_) => const _ExitDialog(),
          );
          if (shouldPop == true) SystemNavigator.pop();
        } else {
          // Tab/page lain → kembali ke Home.
          context.go('/dashboard');
        }
      },
      child: _ShellScaffold(
        currentIndex: currentIndex,
        routes: routes,
        items: items,
        role: role,
        isTabRoute: isTabRoute,
        child: child,
      ),
    );
  }

  List<BottomNavigationBarItem> _getNavItems(UserRole? role) {
    switch (role) {
      case UserRole.murid:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'Jadwal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_library_outlined),
            activeIcon: Icon(Icons.local_library_rounded),
            label: 'Perpustakaan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ];
      case UserRole.guru:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outlined),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Siswa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign_rounded),
            label: 'Pengumuman',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ];
      case UserRole.orangtua:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.child_care_outlined),
            activeIcon: Icon(Icons.child_care_rounded),
            label: 'Anak Saya',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign_rounded),
            label: 'Pengumuman',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ];
      default:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ];
    }
  }

  List<String> _getRoutes(UserRole? role) {
    switch (role) {
      case UserRole.murid:
        return ['/dashboard', '/subjects', '/library', '/profile'];
      case UserRole.guru:
        return ['/dashboard', '/students', '/announcements', '/profile'];
      case UserRole.orangtua:
        return ['/dashboard', '/students', '/announcements', '/profile'];
      default:
        return ['/dashboard', '/profile'];
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// SHELL SCAFFOLD
//
// Strategi:
// - Kalau route saat ini salah satu dari 4 tab → render Row berisi
//   semua tab pages, drag = translate Row. User lihat halaman tetangga
//   bergerak masuk dari samping (Instagram-style).
// - Kalau route sub-page (mis. /grades, /agenda-guru) → render
//   `widget.child` dari go_router seperti biasa, tanpa swipe.
//   Tab pages tetap di-mount di belakang (pakai Offstage) supaya
//   state-nya preserved saat back ke tab.
// ─────────────────────────────────────────────────────────────────
class _ShellScaffold extends StatefulWidget {
  final int currentIndex;
  final List<String> routes;
  final List<BottomNavigationBarItem> items;
  final UserRole? role;
  final bool isTabRoute;
  final Widget child;

  const _ShellScaffold({
    required this.currentIndex,
    required this.routes,
    required this.items,
    required this.role,
    required this.isTabRoute,
    required this.child,
  });

  @override
  State<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<_ShellScaffold>
    with SingleTickerProviderStateMixin {
  // Live drag offset dalam pixel (0 = posisi normal).
  double _dragOffset = 0;
  bool _isDragging = false;

  late AnimationController _settleController;
  Animation<double>? _settleAnim;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (_settleController.isAnimating) {
      _settleController.stop();
    }
    _isDragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset += details.delta.dx;
      final width = MediaQuery.of(context).size.width;
      // Resistance saat over-scroll di tab pertama / terakhir.
      if (widget.currentIndex == 0 && _dragOffset > 0) {
        _dragOffset = (_dragOffset - details.delta.dx) +
            details.delta.dx * 0.3;
      } else if (widget.currentIndex == widget.routes.length - 1 &&
          _dragOffset < 0) {
        _dragOffset = (_dragOffset - details.delta.dx) +
            details.delta.dx * 0.3;
      }
      _dragOffset = _dragOffset.clamp(-width, width);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final width = MediaQuery.of(context).size.width;
    final velocity = details.primaryVelocity ?? 0;
    final threshold = width * 0.25;

    int? targetIndex;
    if ((_dragOffset < -threshold || velocity < -500) &&
        widget.currentIndex < widget.routes.length - 1) {
      targetIndex = widget.currentIndex + 1;
    } else if ((_dragOffset > threshold || velocity > 500) &&
        widget.currentIndex > 0) {
      targetIndex = widget.currentIndex - 1;
    }

    if (targetIndex != null) {
      // Animasi sisanya: kalau mau next tab, _dragOffset menuju -width;
      // kalau previous, menuju +width. Saat selesai → context.go +
      // reset offset (page baru akan render dari posisi 0).
      final endOffset =
          targetIndex > widget.currentIndex ? -width : width;
      _animateOffset(_dragOffset, endOffset).then((_) {
        if (!mounted) return;
        // Reset offset ke 0 sebelum navigate supaya saat halaman baru
        // jadi current, dia muncul dari posisi normal (bukan dari samping).
        setState(() => _dragOffset = 0);
        context.go(widget.routes[targetIndex!]);
      });
    } else {
      _animateOffset(_dragOffset, 0).then((_) {
        if (!mounted) return;
        setState(() => _dragOffset = 0);
      });
    }
  }

  Future<void> _animateOffset(double from, double to) async {
    _settleController.reset();
    _settleAnim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(
        parent: _settleController,
        curve: Curves.easeOutCubic,
      ),
    )..addListener(() {
        if (mounted) {
          setState(() => _dragOffset = _settleAnim!.value);
        }
      });
    await _settleController.forward();
  }

  /// Build halaman untuk tab tertentu (di-instantiate langsung,
  /// bukan via go_router builder).
  Widget _buildTabPage(int index) {
    final route = widget.routes[index];
    switch (route) {
      case '/dashboard':
        switch (widget.role) {
          case UserRole.murid:
            return const StudentDashboardPage();
          case UserRole.guru:
            return const TeacherDashboardPage();
          case UserRole.orangtua:
            return const ParentDashboardPage();
          default:
            return const StudentDashboardPage();
        }
      case '/subjects':
        return const SubjectsPage();
      case '/library':
        return const LibraryPage();
      case '/students':
        return const StudentsListPage();
      case '/announcements':
        return const AnnouncementsPage();
      case '/profile':
        return const ProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.isTabRoute
          ? _buildSwipeableTabs(context)
          : widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 2),
              child: Row(
                children: List.generate(widget.items.length, (i) {
                  final isActive = i == widget.currentIndex;
                  final item = widget.items[i];
                  return Expanded(
                    child: _NavItem(
                      icon: item.icon as Icon,
                      activeIcon: item.activeIcon as Icon,
                      label: item.label!,
                      isActive: isActive,
                      onTap: () {
                        if (i < widget.routes.length && !isActive) {
                          context.go(widget.routes[i]);
                        }
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeableTabs(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final currentIdx = widget.currentIndex;

    // Tentukan neighbor yang perlu di-render berdasarkan arah drag.
    // - drag > 0 (jari ke kanan) → previous tab muncul dari kiri
    // - drag < 0 (jari ke kiri) → next tab muncul dari kanan
    // Saat tidak sedang drag, hanya render current page.
    int? leftIdx;
    int? rightIdx;
    if (_dragOffset > 0 && currentIdx > 0) {
      leftIdx = currentIdx - 1;
    } else if (_dragOffset < 0 && currentIdx < widget.routes.length - 1) {
      rightIdx = currentIdx + 1;
    }

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Left neighbor — di-render hanya saat user drag ke kanan.
            if (leftIdx != null)
              Positioned(
                left: -width + _dragOffset,
                top: 0,
                bottom: 0,
                width: width,
                child: RepaintBoundary(child: _buildTabPage(leftIdx)),
              ),
            // Current page — selalu di-render.
            Positioned(
              left: _dragOffset,
              top: 0,
              bottom: 0,
              width: width,
              child: RepaintBoundary(child: _buildTabPage(currentIdx)),
            ),
            // Right neighbor — di-render hanya saat user drag ke kiri.
            if (rightIdx != null)
              Positioned(
                left: width + _dragOffset,
                top: 0,
                bottom: 0,
                width: width,
                child: RepaintBoundary(child: _buildTabPage(rightIdx)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Exit Dialog ───
class _ExitDialog extends StatefulWidget {
  const _ExitDialog();

  @override
  State<_ExitDialog> createState() => _ExitDialogState();
}

class _ExitDialogState extends State<_ExitDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.error.withValues(alpha: 0.15),
                            AppColors.error.withValues(alpha: 0.05),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.exit_to_app_rounded,
                        color: AppColors.error,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Keluar Aplikasi?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Apakah Anda yakin ingin\nkeluar dari aplikasi?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Keluar',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Nav item ───
class _NavItem extends StatefulWidget {
  final Icon icon;
  final Icon activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _tapController.forward(),
      onTapUp: (_) {
        _tapController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _tapController.reverse(),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isActive ? 14 : 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: IconTheme(
                    key: ValueKey(widget.isActive),
                    data: IconThemeData(
                      color: widget.isActive
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 22,
                    ),
                    child: widget.isActive ? widget.activeIcon : widget.icon,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: widget.isActive
                      ? Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
