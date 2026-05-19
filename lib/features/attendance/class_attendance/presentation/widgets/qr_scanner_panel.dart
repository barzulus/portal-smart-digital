import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../../core/theme/app_colors.dart';
import '../design/attendance_tokens.dart';

/// Panel QR scanner: kamera live + overlay frame dengan scan line animated.
/// Parent bertanggung jawab cooldown (di-disable saat submit / flash error).
class QrScannerPanel extends StatefulWidget {
  const QrScannerPanel({
    super.key,
    required this.onScan,
    required this.enabled,
  });

  final Future<void> Function(String payload) onScan;
  final bool enabled;

  @override
  State<QrScannerPanel> createState() => _QrScannerPanelState();
}

class _QrScannerPanelState extends State<QrScannerPanel>
    with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  late final AnimationController _scanLine;
  DateTime _lastHit = DateTime.fromMillisecondsSinceEpoch(0);
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    _scanLine = AnimationController(
      vsync: this,
      duration: AttendanceTokens.scanLineCycle,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLine.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!widget.enabled) return;
    final now = DateTime.now();
    if (now.difference(_lastHit).inMilliseconds < 1200) return;

    final code = capture.barcodes.firstWhere(
      (b) => (b.rawValue ?? '').isNotEmpty,
      orElse: () => const Barcode(rawValue: null),
    );
    final payload = code.rawValue;
    if (payload == null || payload.isEmpty) return;

    _lastHit = now;
    HapticFeedback.selectionClick();
    await widget.onScan(payload);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AttendanceTokens.cornerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, _) => _ErrorState(error: error),
            ),
            const _ScrimVignette(),
            Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: _ScanFrame(animation: _scanLine),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: _TorchButton(
                on: _torch,
                onTap: () async {
                  await _controller.toggleTorch();
                  if (mounted) setState(() => _torch = !_torch);
                },
              ),
            ),
            const Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: _Caption(
                  text: 'Arahkan kamera ke QR di kartu siswa',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => CustomPaint(
        painter: _ScanFramePainter(progress: animation.value),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AttendanceTokens.corner),
    );

    // Dim layer dipotong bolongan
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.transparent);
    canvas.restore();

    // Corner markers
    const cornerLen = 26.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    // TL
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLen), cornerPaint);
    // TR
    canvas.drawLine(Offset(size.width, 0),
        Offset(size.width - cornerLen, 0), cornerPaint);
    canvas.drawLine(Offset(size.width, 0),
        Offset(size.width, cornerLen), cornerPaint);
    // BL
    canvas.drawLine(Offset(0, size.height),
        Offset(cornerLen, size.height), cornerPaint);
    canvas.drawLine(Offset(0, size.height),
        Offset(0, size.height - cornerLen), cornerPaint);
    // BR
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - cornerLen, size.height), cornerPaint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - cornerLen), cornerPaint);

    // Scan line gradient
    final y = size.height * progress;
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF60A5FA).withValues(alpha: 0.55),
          Colors.white,
          const Color(0xFF60A5FA).withValues(alpha: 0.55),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 8, size.width, 16));
    canvas.drawRect(
      Rect.fromLTWH(6, y - 1, size.width - 12, 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ScrimVignette extends StatelessWidget {
  const _ScrimVignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.55),
            ],
            stops: const [0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? Colors.white : Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            color: on ? Colors.black : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    String label;
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        label = 'Izin kamera ditolak. Buka pengaturan aplikasi untuk mengaktifkan.';
        break;
      case MobileScannerErrorCode.unsupported:
        label = 'Perangkat tidak mendukung kamera.';
        break;
      default:
        label = 'Kamera tidak tersedia: ${error.errorCode.name}';
    }
    return Container(
      color: AppColors.scaffoldBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_rounded,
              color: AppColors.textMuted, size: 44),
          const SizedBox(height: 12),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
