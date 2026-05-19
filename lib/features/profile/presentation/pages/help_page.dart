import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Halaman Bantuan — FAQ singkat + kontak admin sekolah.
/// FAQ disusun dari pertanyaan yang biasa muncul dari pengalaman
/// menggunakan modul-modul utama (login, absensi, tugas, profil).
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _faqs = <_FaqItem>[
    _FaqItem(
      icon: Icons.login_rounded,
      question: 'Bagaimana cara login pertama kali?',
      answer:
          'Masukkan kode sekolah, email, dan password yang diberikan oleh '
          'admin sekolah. Jika belum punya akun, hubungi admin sekolah Anda.',
    ),
    _FaqItem(
      icon: Icons.lock_reset_rounded,
      question: 'Saya lupa password, apa yang harus dilakukan?',
      answer:
          'Silakan hubungi admin sekolah Anda untuk reset password. '
          'Karena alasan keamanan, perubahan password tidak bisa dilakukan '
          'sendiri di aplikasi.',
    ),
    _FaqItem(
      icon: Icons.edit_outlined,
      question: 'Kenapa data profil saya tidak bisa diubah?',
      answer:
          'Untuk menjaga konsistensi data sekolah, perubahan info profil '
          '(nama, NIS, alamat, dll.) hanya dapat dilakukan oleh admin '
          'sekolah. Sampaikan permintaan perubahan ke admin.',
    ),
    _FaqItem(
      icon: Icons.qr_code_scanner_rounded,
      question: 'Cara absensi siswa untuk guru?',
      answer:
          'Buka menu Absensi → pilih jadwal mengajar Anda → pilih tipe '
          '(Masuk/Pulang) → scan QR/RFID kartu siswa atau input NIS '
          'manual. Riwayat sesi tampil di bawah scanner.',
    ),
    _FaqItem(
      icon: Icons.fingerprint_rounded,
      question: 'Cara absensi guru untuk diri sendiri?',
      answer:
          'Buka menu Absen Guru. Pastikan GPS aktif dan Anda berada di '
          'lokasi sekolah. Ambil foto selfie sebagai bukti, lalu pilih '
          'tipe (Masuk/Pulang).',
    ),
    _FaqItem(
      icon: Icons.assignment_outlined,
      question: 'Cara menambahkan tugas untuk siswa?',
      answer:
          'Masuk ke menu Tugas → tap tombol "+" → isi judul, deskripsi, '
          'tenggat waktu, dan lampiran (opsional). Tugas akan langsung '
          'terlihat oleh siswa di kelas yang relevan.',
    ),
    _FaqItem(
      icon: Icons.notifications_active_rounded,
      question: 'Notifikasi tidak muncul, kenapa?',
      answer:
          'Pastikan notifikasi sudah diaktifkan di Profil → Notifikasi. '
          'Jika izin sistem ditolak, buka pengaturan aplikasi dan izinkan '
          'notifikasi secara manual.',
    ),
    _FaqItem(
      icon: Icons.wifi_off_rounded,
      question: 'Aplikasi error saat tidak ada internet?',
      answer:
          'Sebagian besar fitur membutuhkan internet karena terhubung ke '
          'server sekolah. Beberapa data akan ter-cache otomatis sehingga '
          'masih bisa dilihat saat offline.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Bantuan'),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pusat Bantuan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Pertanyaan umum & cara menggunakan aplikasi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section title
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'PERTANYAAN UMUM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),

          // FAQ list
          ..._faqs.map((f) => _FaqCard(item: f)),

          const SizedBox(height: 20),

          // Contact card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.info,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Masih butuh bantuan?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hubungi admin sekolah Anda untuk masalah akun, '
                  'reset password, atau pertanyaan lainnya.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
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

class _FaqItem {
  final IconData icon;
  final String question;
  final String answer;
  const _FaqItem({
    required this.icon,
    required this.question,
    required this.answer,
  });
}

class _FaqCard extends StatefulWidget {
  const _FaqCard({required this.item});
  final _FaqItem item;

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    widget.item.icon,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Container(
              width: double.infinity,
              color: AppColors.scaffoldBg,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text(
                widget.item.answer,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
