import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../data/models/class_attendance_models.dart';
import '../design/attendance_tokens.dart';

/// Pill tabs untuk memilih metode absensi — light theme, warna primary.
class MetodeTabs extends StatelessWidget {
  const MetodeTabs({
    super.key,
    required this.active,
    required this.onChanged,
  });

  final MetodeAbsensi active;
  final ValueChanged<MetodeAbsensi> onChanged;

  static const _items = [
    (MetodeAbsensi.rfid, Icons.nfc_rounded, 'RFID'),
    (MetodeAbsensi.qr, Icons.qr_code_2_rounded, 'QR'),
    (MetodeAbsensi.manual, Icons.keyboard_rounded, 'Manual'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final totalW = c.maxWidth;
        final itemW = totalW / _items.length;
        final activeIndex = _items
            .indexWhere((e) => e.$1 == active)
            .clamp(0, _items.length - 1);

        return Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.scaffoldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: AttendanceTokens.dNormal,
                curve: AttendanceTokens.easeOutCubic,
                left: itemW * activeIndex + 4,
                top: 4,
                bottom: 4,
                width: itemW - 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: _items.map((e) {
                  final (metode, icon, label) = e;
                  final isActive = metode == active;
                  return Expanded(
                    child: _TabItem(
                      icon: icon,
                      label: label,
                      active: isActive,
                      onTap: () => onChanged(metode),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: AttendanceTokens.dNormal,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: color,
                  height: 1.0,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
