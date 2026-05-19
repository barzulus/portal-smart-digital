import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import '../../../../../core/theme/app_colors.dart';
import '../design/attendance_tokens.dart';

/// Panel RFID (nfc_manager 4.x) — light theme, auto re-check saat
/// user kembali ke app setelah mengaktifkan NFC.
class RfidScannerPanel extends StatefulWidget {
  const RfidScannerPanel({
    super.key,
    required this.onScan,
    required this.enabled,
  });

  final Future<void> Function(String rfidCode) onScan;
  final bool enabled;

  @override
  State<RfidScannerPanel> createState() => _RfidScannerPanelState();
}

class _RfidScannerPanelState extends State<RfidScannerPanel>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ripple;
  NfcAvailability _availability = NfcAvailability.unsupported;
  bool _sessionRunning = false;
  bool _checking = true;
  Timer? _autoPoller;
  String? _lastUidDebug;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(
      vsync: this,
      duration: AttendanceTokens.radarCycle,
    )..repeat();
    WidgetsBinding.instance.addObserver(this);
    _checkAvailability();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      // OS Android bisa pause/invalidate NFC session saat app di-background,
      // sementara flag `_sessionRunning` di Dart tetap true. Paksa stop dulu
      // supaya `_checkAvailability` bisa start session yang fresh.
      _forceStopSession();
      _checkAvailability();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _forceStopSession();
    }
  }

  Future<void> _forceStopSession() async {
    if (!_sessionRunning) return;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
    _sessionRunning = false;
  }

  void _ensureAutoPoller() {
    // Polling tiap 2 detik saat NFC disabled — untuk nangkap perubahan
    // state tanpa butuh user interaction (toolbar, quick tile, settings).
    _autoPoller?.cancel();
    if (_availability == NfcAvailability.disabled) {
      _autoPoller = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) _checkAvailability(silent: true);
      });
    } else {
      _autoPoller = null;
    }
  }

  Future<void> _checkAvailability({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _checking = true);

    NfcAvailability result;
    try {
      result = await NfcManager.instance.checkAvailability();
    } catch (_) {
      result = NfcAvailability.unsupported;
    }
    if (!mounted) return;

    final wasEnabled = _availability == NfcAvailability.enabled;
    final isEnabled = result == NfcAvailability.enabled;

    // Hanya setState kalau ada perubahan state atau memang tidak silent.
    if (!silent || _availability != result) {
      setState(() {
        _availability = result;
        _checking = false;
      });
    }

    _ensureAutoPoller();

    if (isEnabled && !_sessionRunning) {
      _startSession();
    } else if (!isEnabled && wasEnabled && _sessionRunning) {
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
      _sessionRunning = false;
    }
  }

  Future<void> _startSession() async {
    if (_sessionRunning) return;
    _sessionRunning = true;
    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        alertMessageIos: 'Dekatkan kartu RFID',
        invalidateAfterFirstReadIos: false,
        onDiscovered: _handleDiscovered,
      );
    } catch (_) {
      _sessionRunning = false;
    }
  }

  Future<void> _handleDiscovered(NfcTag tag) async {
    if (!widget.enabled || !mounted) return;
    final code = _extractIdentifier(tag);
    if (code == null || code.isEmpty) return;

    if (mounted) setState(() => _lastUidDebug = code);

    HapticFeedback.selectionClick();
    await widget.onScan(code);

    // Restart session (iOS session invalidate setelah first read).
    try {
      await NfcManager.instance.stopSession(alertMessageIos: 'Tersimpan');
    } catch (_) {}
    _sessionRunning = false;
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted && widget.enabled && _availability == NfcAvailability.enabled) {
      _startSession();
    }
  }

  String? _extractIdentifier(NfcTag tag) {
    final android = NfcTagAndroid.from(tag);
    if (android != null) return _bytesToHex(android.id);

    final mifare = MiFareIos.from(tag);
    if (mifare != null) return _bytesToHex(mifare.identifier);
    final iso15 = Iso15693Ios.from(tag);
    if (iso15 != null) return _bytesToHex(iso15.identifier);
    final felica = FeliCaIos.from(tag);
    if (felica != null) return _bytesToHex(felica.currentIDm);
    return null;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoPoller?.cancel();
    _ripple.dispose();
    if (_sessionRunning) {
      NfcManager.instance.stopSession().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: _checking
              ? const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_availability) {
      case NfcAvailability.enabled:
        return _buildWaitingTag();
      case NfcAvailability.disabled:
        return _buildNfcDisabled();
      case NfcAvailability.unsupported:
        return _buildNfcUnsupported();
    }
  }

  Widget _buildWaitingTag() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple radar
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ripple,
                  builder: (_, __) => CustomPaint(
                    painter: _RadarPainter(progress: _ripple.value),
                  ),
                ),
              ),
              // Center icon
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.nfc_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Menunggu kartu RFID',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dekatkan kartu RFID ke belakang ponsel.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
        if (_lastUidDebug != null) ...[
          const SizedBox(height: 14),
          _UidDebugChip(uid: _lastUidDebug!),
        ],
      ],
    );
  }

  Widget _buildNfcDisabled() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.warning.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.nfc_rounded,
            color: AppColors.warning,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'NFC belum aktif',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Aktifkan NFC dari panel cepat (swipe dari atas) atau pengaturan sistem.\nHalaman ini akan otomatis terhubung begitu NFC aktif.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _StatusPulse(),
      ],
    );
  }

  Widget _buildNfcUnsupported() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textMuted.withValues(alpha: 0.12),
          ),
          child: Icon(
            Icons.nfc_rounded,
            color: AppColors.textMuted,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Perangkat tidak mendukung NFC',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Gunakan metode QR atau Manual untuk mengabsen siswa.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Indikator kecil "sedang memantau NFC…" dengan titik animated supaya
/// user tahu halaman aktif menunggu, bukan nge-freeze.
class _StatusPulse extends StatefulWidget {
  const _StatusPulse();

  @override
  State<_StatusPulse> createState() => _StatusPulseState();
}

class _StatusPulseState extends State<_StatusPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              height: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (i) {
                  final t = ((_ctrl.value + i / 3) % 1.0);
                  final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.2, 1.0);
                  return Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Memantau NFC…',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.48;

    for (int i = 0; i < 3; i++) {
      final offset = (progress + i / 3) % 1.0;
      final r = maxR * offset;
      final opacity = (1 - offset).clamp(0.0, 1.0) * 0.35;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.primary.withValues(alpha: opacity);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Chip kecil yang menampilkan UID terakhir yang terbaca — berguna buat
/// debug mismatch format dengan reader hardware. Bisa disembunyikan
/// nanti setelah data production stabil.
class _UidDebugChip extends StatelessWidget {
  const _UidDebugChip({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fingerprint_rounded,
              size: 14, color: AppColors.info),
          const SizedBox(width: 6),
          SelectableText(
            'UID terbaca: $uid',
            style: const TextStyle(
              color: AppColors.info,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
