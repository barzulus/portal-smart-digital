import 'package:flutter/material.dart';

/// Design tokens — durasi, curve, warna khusus modul absensi kelas.
/// Warna utama tetap mengikuti AppColors supaya visual konsisten dengan
/// halaman lain di aplikasi.
class AttendanceTokens {
  AttendanceTokens._();

  // Durations
  static const Duration dFast = Duration(milliseconds: 160);
  static const Duration dNormal = Duration(milliseconds: 280);
  static const Duration dSlow = Duration(milliseconds: 420);

  static const Duration flashSuccess = Duration(milliseconds: 220);
  static const Duration flashError = Duration(milliseconds: 320);
  static const Duration flashHold = Duration(milliseconds: 420);

  static const Duration scanLineCycle = Duration(milliseconds: 1600);
  static const Duration radarCycle = Duration(milliseconds: 1800);

  // Curves
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve spring = Curves.easeOutBack;

  // Feedback colors — hanya untuk overlay flash, tidak untuk surface.
  static const Color successGlow = Color(0xFF2E7D32);
  static const Color errorGlow = Color(0xFFC62828);
  static const Color warningGlow = Color(0xFFF59E0B);

  // Sizes
  static const double cornerRadius = 18;
  static const double corner = 24;
  static const double largeCorner = 28;
  static const double tapTarget = 48;
}
