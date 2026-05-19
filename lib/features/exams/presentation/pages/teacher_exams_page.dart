import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../kegiatan_keagamaan/providers/kegiatan_keagamaan_provider.dart'
    show kelasListProvider;
import '../../../schedule/providers/schedule_provider.dart';
import '../../providers/exams_provider.dart';

/// Halaman guru untuk mengelola ujian yang dia buat.
/// Filter: ujian_quiz.guru_id = current guru.
class TeacherExamsPage extends ConsumerWidget {
  const TeacherExamsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(myExamsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Ujian & Quiz'),
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Buat Ujian',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myExamsProvider);
          await ref.read(myExamsProvider.future);
        },
        child: examsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildError(context, ref, '$e'),
          data: (exams) {
            if (exams.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 100), _EmptyState()],
              );
            }

            final upcoming = exams.where((e) => !e.isPast).toList()
              ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
            final past = exams.where((e) => e.isPast).toList()
              ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                if (upcoming.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.event_rounded,
                    title: 'Akan Datang',
                    count: upcoming.length,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  ...upcoming.map((e) => _ExamRow(exam: e)),
                ],
                if (past.isNotEmpty) ...[
                  if (upcoming.isNotEmpty) const SizedBox(height: 16),
                  _SectionHeader(
                    icon: Icons.history_rounded,
                    title: 'Sudah Berlalu',
                    count: past.length,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 10),
                  ...past.map((e) => _ExamRow(exam: e, isPast: true)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String msg) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gagal memuat ujian',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(myExamsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFormSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ExamFormSheet(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExamRow extends ConsumerWidget {
  const _ExamRow({required this.exam, this.isPast = false});
  final ExamData exam;
  final bool isPast;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  Color _typeColor() {
    switch (exam.type) {
      case ExamType.uts:
        return AppColors.ujianColor;
      case ExamType.uas:
        return AppColors.error;
      case ExamType.quiz:
        return AppColors.info;
      case ExamType.dailyTest:
        return AppColors.kehadiranColor;
      case ExamType.other:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = isPast ? AppColors.textMuted : _typeColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showOptions(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${exam.tanggal.day}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _months[exam.tanggal.month - 1],
                        style: TextStyle(
                          fontSize: 11,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          exam.typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        exam.namaUjian,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isPast
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _Meta(
                            icon: Icons.access_time_rounded,
                            text: exam.jamRange,
                          ),
                          _Meta(
                            icon: Icons.room_outlined,
                            text: exam.ruangan,
                          ),
                          if (exam.durasiMenit > 0)
                            _Meta(
                              icon: Icons.timer_outlined,
                              text: '${exam.durasiMenit} menit',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.edit_rounded, color: AppColors.primary),
                title: const Text('Edit Ujian'),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _ExamFormSheet(existing: exam),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_rounded, color: AppColors.error),
                title: const Text(
                  'Hapus Ujian',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Ujian'),
        content: Text('Yakin ingin menghapus ujian "${exam.namaUjian}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(examNotifierProvider.notifier).deleteExam(exam.id);
            },
            child: const Text(
              'Hapus',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.quiz_rounded,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum ada ujian dibuat',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap tombol + untuk membuat jadwal ujian baru',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FORM SHEET (CREATE / EDIT)
// ═══════════════════════════════════════════════════════════════

class _ExamFormSheet extends ConsumerStatefulWidget {
  const _ExamFormSheet({this.existing});
  final ExamData? existing;

  @override
  ConsumerState<_ExamFormSheet> createState() => _ExamFormSheetState();
}

class _ExamFormSheetState extends ConsumerState<_ExamFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaCtrl;
  late final TextEditingController _ruanganCtrl;
  late final TextEditingController _durasiCtrl;
  String? _selectedJenisId;
  late DateTime _tanggal;
  TimeOfDay? _jamMulai;
  TimeOfDay? _jamSelesai;
  // Set kelas yang dipilih untuk peserta ujian (di-insert ke
  // ujian_peserta saat create). Hanya dipakai saat create — saat
  // edit, list peserta sudah tetap dan tidak diubah dari sini.
  final Set<String> _selectedKelasIds = <String>{};
  bool _isLoading = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _namaCtrl = TextEditingController(text: ex?.namaUjian ?? '');
    _ruanganCtrl = TextEditingController(text: ex?.ruangan ?? '');
    _durasiCtrl = TextEditingController(
      text: ex != null && ex.durasiMenit > 0
          ? ex.durasiMenit.toString()
          : '60',
    );
    _tanggal = ex?.tanggal ?? DateTime.now().add(const Duration(days: 1));
    if (ex != null && ex.jamRange.contains(' - ')) {
      final parts = ex.jamRange.split(' - ');
      _jamMulai = _parseTime(parts.first);
      _jamSelesai = _parseTime(parts.last);
    } else {
      _jamMulai = const TimeOfDay(hour: 8, minute: 0);
      _jamSelesai = const TimeOfDay(hour: 9, minute: 30);
    }
  }

  TimeOfDay? _parseTime(String s) {
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _namaCtrl.dispose();
    _ruanganCtrl.dispose();
    _durasiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jenisAsync = ref.watch(jenisPenilaianListProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEdit ? 'Edit Ujian' : 'Buat Ujian Baru',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tentukan jadwal pelaksanaan ujian',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _namaCtrl,
                  decoration:
                      _inputDeco('Nama Ujian *', Icons.title_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                jenisAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, __) => const Text(
                    'Gagal memuat jenis penilaian',
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                  data: (list) {
                    // Default ke value existing kalau edit, atau item pertama.
                    if (_selectedJenisId == null) {
                      if (isEdit) {
                        // Match by jenis_ujian_id dari raw exam data tidak
                        // tersimpan di model. Sebagai fallback, kita
                        // biarkan kosong supaya user pilih lagi saat edit.
                      } else if (list.isNotEmpty) {
                        _selectedJenisId = list.first.id;
                      }
                    }
                    if (list.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              AppColors.warning.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Belum ada jenis penilaian terdaftar. Hubungi admin sekolah.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: list.any((j) => j.id == _selectedJenisId)
                          ? _selectedJenisId
                          : null,
                      decoration: _inputDeco(
                        'Jenis Ujian *',
                        Icons.category_rounded,
                      ),
                      isExpanded: true,
                      items: list
                          .map(
                            (j) => DropdownMenuItem(
                              value: j.id,
                              child: Text(
                                j.nama,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedJenisId = v),
                      validator: (v) =>
                          (v == null || v.isEmpty)
                              ? 'Jenis wajib dipilih'
                              : null,
                    );
                  },
                ),
                const SizedBox(height: 14),

                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: TextEditingController(
                        text: DateFormat('EEEE, d MMMM yyyy', 'id')
                            .format(_tanggal),
                      ),
                      decoration: _inputDeco(
                        'Tanggal Ujian',
                        Icons.calendar_today_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(true),
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: TextEditingController(
                              text: _jamMulai != null
                                  ? _formatTime(_jamMulai!)
                                  : '',
                            ),
                            decoration: _inputDeco(
                              'Jam Mulai',
                              Icons.access_time_rounded,
                            ),
                            validator: (_) => _jamMulai == null
                                ? 'Wajib diisi'
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(false),
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: TextEditingController(
                              text: _jamSelesai != null
                                  ? _formatTime(_jamSelesai!)
                                  : '',
                            ),
                            decoration: _inputDeco(
                              'Jam Selesai',
                              Icons.access_time_filled_rounded,
                            ),
                            validator: (_) => _jamSelesai == null
                                ? 'Wajib diisi'
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durasiCtrl,
                        decoration: _inputDeco(
                          'Durasi (menit) *',
                          Icons.timer_outlined,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) {
                            return 'Durasi tidak valid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _ruanganCtrl,
                        decoration: _inputDeco(
                          'Ruangan *',
                          Icons.room_outlined,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Wajib diisi'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Pilih kelas peserta — hanya saat create. Edit tidak
                // mengubah peserta dari sini.
                if (!isEdit) _buildKelasSelector(),

                const SizedBox(height: 24),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEdit ? 'Simpan Perubahan' : 'Buat Ujian',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.scaffoldBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  /// Multi-select chip untuk pilih kelas peserta. Daftar kelas
  /// di-filter ke kelas yang sedang diajar oleh guru saat ini
  /// (dari `teacherClassesProvider` yang berbasis jadwal_pembelajaran_v2).
  Widget _buildKelasSelector() {
    final kelasAsync = ref.watch(kelasListProvider);
    final teacherClassesAsync = ref.watch(teacherClassesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.class_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            const Text(
              'Kelas Peserta',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            if (_selectedKelasIds.isNotEmpty)
              Text(
                '${_selectedKelasIds.length} dipilih',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilih kelas yang akan ikut ujian ini. Bisa pilih lebih dari satu.',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        kelasAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Gagal memuat daftar kelas',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
          data: (allKelas) {
            // Filter ke kelas yang guru ajar.
            // teacherClassesProvider return list nama kelas (string).
            // kelasListProvider return list KelasData (id + nama).
            // Match by nama_kelas (normalize lowercase + trim).
            final teacherClasses = teacherClassesAsync.maybeWhen(
              data: (c) => c,
              orElse: () => const <String>[],
            );
            final taughtNormalized = teacherClasses
                .map((n) => n.trim().toLowerCase())
                .toSet();
            final filteredKelas = allKelas
                .where(
                  (k) => taughtNormalized
                      .contains(k.namaKelas.trim().toLowerCase()),
                )
                .toList();

            if (filteredKelas.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Anda belum mengajar kelas mana pun. Hubungi admin untuk menambahkan jadwal mengajar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    height: 1.4,
                  ),
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filteredKelas.map((k) {
                final isSelected = _selectedKelasIds.contains(k.id);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedKelasIds.remove(k.id);
                    } else {
                      _selectedKelasIds.add(k.id);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.scaffoldBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.divider,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          k.namaKelas,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_jamMulai ?? const TimeOfDay(hour: 8, minute: 0))
          : (_jamSelesai ?? const TimeOfDay(hour: 9, minute: 30)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _jamMulai = picked;
        } else {
          _jamSelesai = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_jamMulai == null || _jamSelesai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam mulai & selesai wajib diisi')),
      );
      return;
    }
    // Validasi jam selesai harus setelah jam mulai.
    final startMin = _jamMulai!.hour * 60 + _jamMulai!.minute;
    final endMin = _jamSelesai!.hour * 60 + _jamSelesai!.minute;
    if (endMin <= startMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jam selesai harus setelah jam mulai'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final notifier = ref.read(examNotifierProvider.notifier);
    final durasi = int.tryParse(_durasiCtrl.text.trim()) ?? 60;
    bool success;

    if (isEdit) {
      success = await notifier.updateExam(
        id: widget.existing!.id,
        namaUjian: _namaCtrl.text.trim(),
        jenisUjianId: _selectedJenisId!,
        tanggal: _tanggal,
        jamMulai: _formatTime(_jamMulai!),
        jamSelesai: _formatTime(_jamSelesai!),
        durasi: durasi,
        ruangan: _ruanganCtrl.text.trim(),
      );
    } else {
      success = await notifier.createExam(
        namaUjian: _namaCtrl.text.trim(),
        jenisUjianId: _selectedJenisId!,
        tanggal: _tanggal,
        jamMulai: _formatTime(_jamMulai!),
        jamSelesai: _formatTime(_jamSelesai!),
        durasi: durasi,
        ruangan: _ruanganCtrl.text.trim(),
        kelasIds: _selectedKelasIds.toList(),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? 'Ujian berhasil diperbarui' : 'Ujian berhasil dibuat',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan ujian. Coba lagi.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
