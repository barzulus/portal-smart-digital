import 'package:flutter/material.dart';

/// Professional color palette — clean, modern, education-themed
class AppColors {
  AppColors._();

  // ── Primary — Deep Blue (professional, trustworthy) ──
  static const Color primary = Color(0xFF0056D2); // Google Blue / Deeper Blue
  static const Color primaryLight = Color(0xFF1A73E8);
  static const Color primaryDark = Color(0xFF003C8F);

  // ── Secondary — Teal (fresh, modern) ──
  static const Color secondary = Color(0xFF0288D1); // Light Blue
  static const Color secondaryLight = Color(0xFF4DB6AC);
  static const Color secondaryDark = Color(0xFF00695C);

  // ── Accent — Warm Orange ──
  static const Color accent = Color(0xFFE65100);
  static const Color accentLight = Color(0xFFFF8A65);

  // ── Background (Light Theme) ──
  static const Color scaffoldBg = Color(0xFFF4F6F9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color surfaceBg = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE8ECF0);

  // ── Glassmorphism ──
  static final Color glassWhite = Colors.white.withOpacity(0.85);
  static final Color glassBorder = Colors.white.withOpacity(0.25);

  // ── Text ──
  static const Color textPrimary = Color(0xFF1A2030);
  static const Color textSecondary = Color(0xFF5A6478);
  static const Color textMuted = Color(0xFF9AA4B8);
  static const Color textOnPrimary = Colors.white;

  // ── Status ──
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  // ── Role Colors ──
  static const Color siswaColor = Color(0xFF1565C0);
  static const Color orangtuaColor = Color(0xFF00897B);
  static const Color guruColor = Color(0xFF0056D2);

  // ── Feature Menu Colors ──
  static const Color pelajaranColor = Color(0xFF5C6BC0);
  static const Color kehadiranColor = Color(0xFF26A69A);
  static const Color tugasColor = Color(0xFFFF7043);
  static const Color ujianColor = Color(0xFFAB47BC);
  static const Color keagamaanColor = Color(0xFF66BB6A);
  static const Color pengumumanColor = Color(0xFF42A5F5);
  static const Color perpustakaanColor = Color(0xFF8D6E63);

  // ── Gradient ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1B4965), Color(0xFF2E6F95)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF0056D2), Color(0xFF1A73E8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Feature Gradients ──
  static const LinearGradient pelajaranGradient = LinearGradient(
    colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient kehadiranGradient = LinearGradient(
    colors: [Color(0xFF26A69A), Color(0xFF4DB6AC)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient tugasGradient = LinearGradient(
    colors: [Color(0xFFFF7043), Color(0xFFFF8A65)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient ujianGradient = LinearGradient(
    colors: [Color(0xFFAB47BC), Color(0xFFCE93D8)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient keagamaanGradient = LinearGradient(
    colors: [Color(0xFF66BB6A), Color(0xFF81C784)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient pengumumanGradient = LinearGradient(
    colors: [Color(0xFF42A5F5), Color(0xFF64B5F6)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient perpustakaanGradient = LinearGradient(
    colors: [Color(0xFF8D6E63), Color(0xFFA1887F)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient absenGuruGradient = LinearGradient(
    colors: [Color(0xFF00897B), Color(0xFF4DB6AC)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}
