import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/attendance_tokens.dart';

/// Overlay layar penuh yang muncul sebentar saat scan sukses/gagal.
/// Dipicu lewat [ResultFlashController], tidak perlu state parent.
class ResultFlash {
  ResultFlash._();

  static OverlayEntry? _entry;

  static Future<void> show(
    BuildContext context, {
    required bool success,
    required String title,
    String? subtitle,
  }) async {
    // Haptik — aman kalau device tidak mendukung.
    try {
      if (success) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {}

    _entry?.remove();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _FlashWidget(
        success: success,
        title: title,
        subtitle: subtitle,
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    final totalMs = (success
            ? AttendanceTokens.flashSuccess
            : AttendanceTokens.flashError)
        .inMilliseconds +
        AttendanceTokens.flashHold.inMilliseconds +
        180;
    await Future.delayed(Duration(milliseconds: totalMs));
    if (_entry == entry) {
      entry.remove();
      _entry = null;
    }
  }
}

class _FlashWidget extends StatefulWidget {
  const _FlashWidget({
    required this.success,
    required this.title,
    this.subtitle,
  });

  final bool success;
  final String title;
  final String? subtitle;

  @override
  State<_FlashWidget> createState() => _FlashWidgetState();
}

class _FlashWidgetState extends State<_FlashWidget>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _exit;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: widget.success
          ? AttendanceTokens.flashSuccess
          : AttendanceTokens.flashError,
    )..forward();
    _exit = AnimationController(
      vsync: this,
      duration: AttendanceTokens.dFast,
    );
    Future.delayed(
      Duration(
        milliseconds: (widget.success
                ? AttendanceTokens.flashSuccess
                : AttendanceTokens.flashError)
            .inMilliseconds +
            AttendanceTokens.flashHold.inMilliseconds,
      ),
      () {
        if (mounted) _exit.forward();
      },
    );
  }

  @override
  void dispose() {
    _enter.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.success
        ? AttendanceTokens.successGlow
        : AttendanceTokens.errorGlow;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _exit]),
        builder: (_, __) {
          final t = Curves.easeOut.transform(_enter.value);
          final te = Curves.easeIn.transform(_exit.value);
          final fade = (t - te).clamp(0.0, 1.0);
          return Opacity(
            opacity: fade,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: color.withValues(alpha: 0.18),
                  ),
                ),
                Center(
                  child: Transform.scale(
                    scale: 0.6 + fade * 0.4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AttendanceTokens.largeCorner),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.15),
                            ),
                            child: Icon(
                              widget.success
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              size: 28,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (widget.subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.subtitle!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
