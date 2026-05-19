import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/guru_staff_provider.dart';
import '../../providers/teacher_self_attendance_provider.dart';

class TeacherSelfAttendancePage extends ConsumerStatefulWidget {
  const TeacherSelfAttendancePage({super.key});

  @override
  ConsumerState<TeacherSelfAttendancePage> createState() =>
      _TeacherSelfAttendancePageState();
}

class _TeacherSelfAttendancePageState
    extends ConsumerState<TeacherSelfAttendancePage> {
  bool _isLoading = false;
  Position? _currentPosition;
  double? _distance;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      final pos = await getCurrentPosition();
      if (!mounted) return;
      final schoolLoc = await ref.read(schoolLocationProvider.future);
      double? dist;
      if (schoolLoc != null) {
        dist = calculateDistance(
            pos.latitude, pos.longitude, schoolLoc.latitude, schoolLoc.longitude);
      }
      setState(() {
        _currentPosition = pos;
        _distance = dist;
        _errorMsg = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _doAttendance(String tipeAbsen) async {
    if (_isLoading) return;

    final schoolLoc = await ref.read(schoolLocationProvider.future);
    final radius = schoolLoc?.radiusMeter ?? 200.0;

    if (_distance != null && _distance! > radius) {
      _showSnackBar(
        'Anda di luar radius absensi (${_distance!.toStringAsFixed(0)} m). Maks ${radius.toInt()} m.',
        AppColors.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Refresh GPS dulu supaya posisi akurat saat submit.
      final pos = await getCurrentPosition();
      final latest = await ref.read(schoolLocationProvider.future);
      double dist = 0;
      if (latest != null) {
        dist = calculateDistance(
            pos.latitude, pos.longitude, latest.latitude, latest.longitude);
      }
      if (latest != null && dist > latest.radiusMeter) {
        if (mounted) {
          _showSnackBar(
            'Lokasi di luar radius ${latest.radiusMeter.toInt()} m.',
            AppColors.error,
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;
      // Tampilkan dialog konfirmasi tanpa foto. User bisa pilih
      // ambil selfie via tombol di dialog (opsional).
      final result = await _showConfirmDialog(pos, dist, tipeAbsen);
      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }

      final guruStaffId = await ref.read(currentGuruStaffIdProvider.future);
      final idSekolah = ref.read(currentIdSekolahProvider);
      if (guruStaffId == null || idSekolah == null) {
        if (mounted) {
          _showSnackBar(
              'Akun guru belum terhubung dengan guru_staff. Hubungi admin.',
              AppColors.error);
        }
        setState(() => _isLoading = false);
        return;
      }

      // Foto opsional — kalau user pilih ambil foto, baru di-upload.
      final photoFile = result['_photo'] as File?;
      String? fotoUrl;
      if (photoFile != null) {
        final service = ref.read(teacherSelfAttendanceServiceProvider);
        fotoUrl = await service.uploadSelfiePhoto(
          photoFile: photoFile,
          idGuru: guruStaffId,
          idSekolah: idSekolah,
          tipeAbsen: tipeAbsen,
        );
      }

      final service = ref.read(teacherSelfAttendanceServiceProvider);
      await service.submitAttendance(
        idGuru: guruStaffId,
        idSekolah: idSekolah,
        tipeAbsen: tipeAbsen,
        latitude: pos.latitude,
        longitude: pos.longitude,
        fotoUrl: fotoUrl,
        statusKehadiran: result['status'] as String? ?? 'Hadir',
        keterangan: result['keterangan'] as String? ?? '',
      );

      ref.invalidate(teacherTodayAttendanceProvider);
      await _fetchLocation();

      if (mounted) {
        _showSnackBar(
          'Absen ${tipeAbsen == 'masuk' ? 'Masuk' : 'Pulang'} berhasil dicatat.',
          AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Gagal: ${e.toString().replaceAll('Exception: ', '')}',
          AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _showConfirmDialog(
      Position pos, double dist, String tipeAbsen) async {
    TeacherAttendanceStatus selectedStatus = TeacherAttendanceStatus.hadir;
    final keteranganCtrl = TextEditingController();
    File? photoFile; // null = no foto

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx2).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Konfirmasi Absen ${tipeAbsen == 'masuk' ? 'Masuk' : 'Pulang'}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.location_on_rounded,
                      label: 'Jarak ke Sekolah',
                      value: '${dist.toStringAsFixed(0)} meter',
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.access_time_rounded,
                      label: 'Waktu',
                      value:
                          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.my_location_rounded,
                      label: 'Koordinat',
                      value:
                          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
                      color: AppColors.info,
                    ),
                    const SizedBox(height: 20),

                    // Foto selfie — OPSIONAL.
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Foto Selfie (Opsional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (photoFile != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          photoFile!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final f = await pickSelfiePhoto();
                                if (f != null) {
                                  setModalState(() => photoFile = f);
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Ganti Foto'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                setModalState(() => photoFile = null),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Hapus'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      OutlinedButton.icon(
                        onPressed: () async {
                          final f = await pickSelfiePhoto();
                          if (f != null) {
                            setModalState(() => photoFile = f);
                          }
                        },
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        label: const Text('Ambil Selfie'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: AppColors.primary
                                .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Status Kehadiran',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: TeacherAttendanceStatus.values.map((s) {
                        final isActive = selectedStatus == s;
                        Color c;
                        switch (s) {
                          case TeacherAttendanceStatus.hadir:
                            c = AppColors.success;
                            break;
                          case TeacherAttendanceStatus.terlambat:
                            c = AppColors.warning;
                            break;
                          case TeacherAttendanceStatus.sakit:
                            c = AppColors.error;
                            break;
                          case TeacherAttendanceStatus.izin:
                            c = AppColors.info;
                            break;
                        }
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setModalState(() => selectedStatus = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(
                                  right: s != TeacherAttendanceStatus.izin
                                      ? 6
                                      : 0),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? c
                                    : c.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: isActive
                                    ? null
                                    : Border.all(
                                        color: c.withValues(alpha: 0.2),
                                      ),
                              ),
                              child: Center(
                                child: Text(
                                  s.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isActive ? Colors.white : c,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: keteranganCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Keterangan (opsional)',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx2).pop({
                            'status': selectedStatus.value,
                            'keterangan': keteranganCtrl.text.trim(),
                            '_photo': photoFile,
                          });
                        },
                        icon:
                            const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text(
                          'Konfirmasi & Simpan',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(teacherTodayAttendanceProvider);
    final schoolLocAsync = ref.watch(schoolLocationProvider);
    final user = ref.watch(authProvider).user;

    final now = DateTime.now();
    const days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dateStr =
        '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Absen Guru'),
        centerTitle: false,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teacherTodayAttendanceProvider);
          ref.invalidate(schoolLocationProvider);
          await _fetchLocation();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero card — light theme, konsisten
              _HeroCard(
                userName: user?.name ?? 'Guru',
                dateStr: dateStr,
                timeStr: timeStr,
              ),
              const SizedBox(height: 14),

              // Location card
              _LocationCard(
                errorMsg: _errorMsg,
                currentPosition: _currentPosition,
                schoolLocAsync: schoolLocAsync,
                distance: _distance,
                onRefresh: _fetchLocation,
              ),
              const SizedBox(height: 14),

              // Action buttons — 1 row/hari (masuk + pulang)
              todayAsync.when(
                loading: () => const _LoadingActions(),
                error: (e, _) => _ErrorCard(message: '$e'),
                data: (record) {
                  final hasMasuk = record?.hasMasuk ?? false;
                  final hasPulang = record?.hasPulang ?? false;
                  final canAbsen = _currentPosition != null &&
                      _errorMsg == null &&
                      (_distance == null ||
                          _distance! <=
                              (schoolLocAsync.valueOrNull?.radiusMeter ??
                                  200.0));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ActionButton(
                        title: hasMasuk ? 'Sudah Absen Masuk' : 'Absen Masuk',
                        subtitle: hasMasuk
                            ? 'Tercatat pada ${record!.jamMasuk}'
                            : 'Catat kehadiran di awal hari',
                        icon: hasMasuk
                            ? Icons.check_circle_rounded
                            : Icons.login_rounded,
                        color: hasMasuk ? AppColors.success : AppColors.primary,
                        isDone: hasMasuk,
                        disabled: !canAbsen || _isLoading,
                        onPressed: () => _doAttendance('masuk'),
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        title: hasPulang
                            ? 'Sudah Absen Pulang'
                            : (!hasMasuk
                                ? 'Absen Masuk Terlebih Dahulu'
                                : 'Absen Pulang'),
                        subtitle: hasPulang
                            ? 'Tercatat pada ${record!.jamKeluar}'
                            : 'Catat kepulangan di akhir hari',
                        icon: hasPulang
                            ? Icons.check_circle_rounded
                            : Icons.logout_rounded,
                        color: hasPulang
                            ? AppColors.success
                            : AppColors.accent,
                        isDone: hasPulang,
                        disabled: !hasMasuk ||
                            hasPulang ||
                            _isLoading ||
                            !canAbsen,
                        onPressed: () => _doAttendance('pulang'),
                      ),
                      if (record != null) ...[
                        const SizedBox(height: 16),
                        _TodayRecordSummary(record: record),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.userName,
    required this.dateStr,
    required this.timeStr,
  });
  final String userName;
  final String dateStr;
  final String timeStr;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fingerprint_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Absensi Guru',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          color: Colors.white.withValues(alpha: 0.7), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.errorMsg,
    required this.currentPosition,
    required this.schoolLocAsync,
    required this.distance,
    required this.onRefresh,
  });
  final String? errorMsg;
  final Position? currentPosition;
  final AsyncValue<SchoolLocation?> schoolLocAsync;
  final double? distance;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.map_rounded,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Text(
                'Informasi Lokasi',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: AppColors.textSecondary,
                onPressed: onRefresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (errorMsg != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMsg!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (currentPosition == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _InfoRow(
              icon: Icons.my_location_rounded,
              label: 'Lokasi Anda',
              value:
                  '${currentPosition!.latitude.toStringAsFixed(5)}, ${currentPosition!.longitude.toStringAsFixed(5)}',
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            schoolLocAsync.when(
              data: (loc) {
                if (loc == null) {
                  return const _InfoRow(
                    icon: Icons.school_rounded,
                    label: 'Lokasi Sekolah',
                    value: 'Belum diatur admin',
                    color: AppColors.warning,
                  );
                }
                return _InfoRow(
                  icon: Icons.school_rounded,
                  label: loc.namaSekolah ?? 'Sekolah',
                  value:
                      '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
                  color: AppColors.info,
                );
              },
              loading: () => const SizedBox(
                height: 42,
                child: Center(
                  child:
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
              error: (_, __) => const _InfoRow(
                icon: Icons.school_rounded,
                label: 'Lokasi Sekolah',
                value: 'Gagal memuat',
                color: AppColors.error,
              ),
            ),
            if (distance != null) ...[
              const SizedBox(height: 10),
              _DistanceChip(
                distance: distance!,
                radius: schoolLocAsync.valueOrNull?.radiusMeter ?? 200.0,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  const _DistanceChip({required this.distance, required this.radius});
  final double distance;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final withinRadius = distance <= radius;
    final color = withinRadius ? AppColors.success : AppColors.error;
    final label = distance < 1000
        ? '${distance.toStringAsFixed(0)} m'
        : '${(distance / 1000).toStringAsFixed(1)} km';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            withinRadius
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jarak: $label',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  withinRadius
                      ? 'Dalam radius absensi (${radius.toInt()} m).'
                      : 'Di luar radius ${radius.toInt()} m.',
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDone,
    required this.disabled,
    required this.onPressed,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDone;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: disabled ? AppColors.divider.withValues(alpha: 0.4) : color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isDone
                    ? Icons.check_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: isDone ? 20 : 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayRecordSummary extends StatelessWidget {
  const _TodayRecordSummary({required this.record});
  final GuruAbsensiRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Text(
                'Rekap Hari Ini',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record.statusAbsensi.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeStat(
                  label: 'Masuk',
                  value: record.jamMasuk ?? '-',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeStat(
                  label: 'Pulang',
                  value: record.jamKeluar ?? '-',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          if (record.keterangan != null && record.keterangan!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.keterangan!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeStat extends StatelessWidget {
  const _TimeStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingActions extends StatelessWidget {
  const _LoadingActions();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (i) => Container(
          margin: EdgeInsets.only(bottom: i == 0 ? 10 : 0),
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.divider.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
