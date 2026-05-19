import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../data/models/class_attendance_models.dart';
import '../../providers/class_attendance_session.dart';
import '../design/attendance_tokens.dart';
import '../widgets/jadwal_picker.dart';
import '../widgets/manual_scanner_panel.dart';
import '../widgets/metode_tabs.dart';
import '../widgets/qr_scanner_panel.dart';
import '../widgets/result_flash_overlay.dart';
import '../widgets/rfid_scanner_panel.dart';
import '../widgets/session_hero_card.dart';
import '../widgets/session_history_list.dart';
import '../widgets/tipe_chooser.dart';

class ClassAttendancePage extends ConsumerStatefulWidget {
  const ClassAttendancePage({super.key});

  @override
  ConsumerState<ClassAttendancePage> createState() =>
      _ClassAttendancePageState();
}

class _ClassAttendancePageState extends ConsumerState<ClassAttendancePage> {
  bool _cooldown = false;

  Future<void> _handleScan(ScanInput input) async {
    if (_cooldown) return;
    _cooldown = true;
    try {
      final saved = await ref
          .read(classAttendanceSessionProvider.notifier)
          .recordScan(
            input: input,
            status: StatusAbsensi.hadir,
          );
      if (!mounted) return;
      await ResultFlash.show(
        context,
        success: true,
        title: saved.namaSiswa ?? 'Tersimpan',
        subtitle: 'NIS ${saved.nisSiswa ?? '-'} • ${saved.statusAbsensi.label}',
      );
    } on AttendanceException catch (e) {
      if (!mounted) return;
      await ResultFlash.show(
        context,
        success: false,
        title: _titleFor(e.code),
        subtitle: e.message,
      );
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _cooldown = false;
    }
  }

  String _titleFor(AttendanceErrorCode code) {
    switch (code) {
      case AttendanceErrorCode.duplicate:
        return 'Sudah Diabsen';
      case AttendanceErrorCode.studentNotFound:
        return 'Siswa Tidak Ditemukan';
      case AttendanceErrorCode.studentWrongClass:
        return 'Beda Kelas';
      case AttendanceErrorCode.studentWrongSchool:
        return 'Bukan dari Sekolah Anda';
      case AttendanceErrorCode.rfidNotRegistered:
        return 'RFID Tidak Terdaftar';
      case AttendanceErrorCode.qrInvalidFormat:
        return 'QR Tidak Dikenali';
      case AttendanceErrorCode.nisInvalid:
        return 'NIS Tidak Valid';
      case AttendanceErrorCode.notAuthorized:
        return 'Tidak Diizinkan';
      case AttendanceErrorCode.network:
        return 'Jaringan Bermasalah';
      case AttendanceErrorCode.unknown:
        return 'Gagal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(classAttendanceSessionProvider);
    final notifier = ref.read(classAttendanceSessionProvider.notifier);

    // Handle system back: kalau bukan di fase pertama (selectJadwal),
    // kembali ke fase sebelumnya alih-alih keluar halaman.
    return PopScope(
      canPop: state.phase == SessionPhase.selectJadwal,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        notifier.back();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: AnimatedSwitcher(
        duration: AttendanceTokens.dNormal,
        switchInCurve: AttendanceTokens.easeOutCubic,
        switchOutCurve: AttendanceTokens.easeOutCubic,
        transitionBuilder: (child, anim) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          );
        },
        child: _buildPhase(state, notifier),
      ),
      ),
    );
  }

  Widget _buildPhase(ClassAttendanceSessionState state,
      ClassAttendanceSessionNotifier notifier) {
    switch (state.phase) {
      case SessionPhase.selectJadwal:
        return _JadwalPhase(
          key: const ValueKey('phase-jadwal'),
          onSelect: (j) => notifier.selectJadwal(j),
          error: state.lastError,
        );
      case SessionPhase.selectTipe:
        return _TipePhase(
          key: const ValueKey('phase-tipe'),
          jadwal: state.jadwal!,
          onBack: notifier.back,
          onSelect: (t) => notifier.selectTipe(t),
        );
      case SessionPhase.scanning:
        return _ScannerPhase(
          key: const ValueKey('phase-scan'),
          state: state,
          onBack: notifier.back,
          onMetodeChange: notifier.setMetode,
          onScan: _handleScan,
          onUndo: notifier.undoRecord,
        );
    }
  }
}

class _JadwalPhase extends StatelessWidget {
  const _JadwalPhase({
    super.key,
    required this.onSelect,
    this.error,
  });
  final void Function(dynamic jadwal) onSelect;
  final AttendanceException? error;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Absensi Kelas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(error!.message,
                          style:
                              const TextStyle(color: AppColors.error, fontSize: 12))),
                ],
              ),
            ),
          Expanded(child: JadwalPicker(onSelected: onSelect)),
        ],
      ),
    );
  }
}

class _TipePhase extends StatelessWidget {
  const _TipePhase({
    super.key,
    required this.jadwal,
    required this.onSelect,
    required this.onBack,
  });
  final dynamic jadwal;
  final void Function(TipeAbsensi tipe) onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return TipeChooser(
      jadwal: jadwal,
      onSelected: onSelect,
      onBack: onBack,
    );
  }
}

class _ScannerPhase extends StatelessWidget {
  const _ScannerPhase({
    super.key,
    required this.state,
    required this.onBack,
    required this.onMetodeChange,
    required this.onScan,
    required this.onUndo,
  });

  final ClassAttendanceSessionState state;
  final VoidCallback onBack;
  final void Function(MetodeAbsensi) onMetodeChange;
  final Future<void> Function(ScanInput) onScan;
  final Future<void> Function(AbsensiRecord) onUndo;

  @override
  Widget build(BuildContext context) {
    final jadwal = state.jadwal!;
    final tipe = state.tipe!;
    final enabled = !state.isSubmitting;

    return Container(
      color: AppColors.scaffoldBg,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Height budget: sisa setelah hero + tabs + paddings = total.
            // Scanner minimal 280, history minimal 160. Ambil proporsi 60/40.
            final availableH = constraints.maxHeight;
            final scannerH = (availableH * 0.6).clamp(280.0, 520.0);
            final historyH =
                (availableH - scannerH - 140).clamp(140.0, 260.0);

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  SessionHeroCard(
                    jadwal: jadwal,
                    tipe: tipe,
                    totalTercatat: state.totalTercatat,
                    onBack: onBack,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MetodeTabs(
                      active: state.metode,
                      onChanged: onMetodeChange,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: scannerH,
                      child: _ScannerSurface(
                        metode: state.metode,
                        enabled: enabled,
                        onScan: onScan,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: historyH,
                    child: _HistorySheet(
                      records: state.history,
                      onUndo: onUndo,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScannerSurface extends StatelessWidget {
  const _ScannerSurface({
    required this.metode,
    required this.enabled,
    required this.onScan,
  });
  final MetodeAbsensi metode;
  final bool enabled;
  final Future<void> Function(ScanInput) onScan;

  @override
  Widget build(BuildContext context) {
    final child = switch (metode) {
      MetodeAbsensi.qr => QrScannerPanel(
          enabled: enabled,
          onScan: (p) => onScan(QrScanInput(p)),
        ),
      MetodeAbsensi.rfid => RfidScannerPanel(
          enabled: enabled,
          onScan: (c) => onScan(RfidScanInput(c)),
        ),
      MetodeAbsensi.manual => ManualScannerPanel(
          enabled: enabled,
          onSubmit: (n) => onScan(ManualScanInput(n)),
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(AttendanceTokens.cornerRadius),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AttendanceTokens.cornerRadius),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: AttendanceTokens.dNormal,
          transitionBuilder: (c, a) =>
              FadeTransition(opacity: a, child: c),
          child: SizedBox(
            key: ValueKey(metode),
            width: double.infinity,
            height: double.infinity,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({
    required this.records,
    required this.onUndo,
  });
  final List<AbsensiRecord> records;
  final Future<void> Function(AbsensiRecord) onUndo;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AttendanceTokens.cornerRadius),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Riwayat Sesi',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${records.length}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: SessionHistoryList(
              records: records,
              onUndo: onUndo,
            ),
          ),
        ],
      ),
    );
  }
}
