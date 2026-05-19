import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../schedule/providers/schedule_provider.dart';
import '../../../students/providers/students_provider.dart';

/// Model for a single student's grade row
class GradeRow {
  final String studentId;
  final String nis;
  final String namaSiswa;
  double? np1;
  double? np2;
  double? sas;
  double? sts;
  double? uh2;
  double? uh1;

  GradeRow({
    required this.studentId,
    required this.nis,
    required this.namaSiswa,
    this.np1,
    this.np2,
    this.sas,
    this.sts,
    this.uh2,
    this.uh1,
  });

  double get average {
    final values = [np1, np2, sas, sts, uh2, uh1].whereType<double>().toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String get grade {
    final avg = average;
    if (avg >= 90) return 'A';
    if (avg >= 80) return 'B';
    if (avg >= 70) return 'C';
    if (avg >= 60) return 'D';
    return 'E';
  }
}

/// Pasangan kelas+mapel yang dipilih guru dari opsi yang dia ajar.
class _ClassSubject {
  final String kelas;
  final String mapel;
  const _ClassSubject({required this.kelas, required this.mapel});

  String get key => '$kelas|$mapel';

  @override
  bool operator ==(Object other) =>
      other is _ClassSubject && other.kelas == kelas && other.mapel == mapel;

  @override
  int get hashCode => Object.hash(kelas, mapel);
}

class GradeManagementPage extends ConsumerStatefulWidget {
  const GradeManagementPage({super.key});

  @override
  ConsumerState<GradeManagementPage> createState() =>
      _GradeManagementPageState();
}

class _GradeManagementPageState extends ConsumerState<GradeManagementPage> {
  _ClassSubject? _selected;
  final List<GradeRow> _grades = [];
  bool _isEditing = false;
  String _gradesKey = ''; // untuk deteksi perlu re-init

  static const List<String> _gradeColumns = [
    'NP-1', 'NP-2', 'SAS', 'STS', 'UH-2', 'UH-1',
  ];

  void _initGrades(List<StudentData> students, String newKey) {
    _grades
      ..clear()
      ..addAll(students.map(
        (s) => GradeRow(studentId: s.id, nis: s.nis, namaSiswa: s.namaSiswa),
      ));
    _gradesKey = newKey;
  }

  @override
  Widget build(BuildContext context) {
    final classSubjectsAsync = ref.watch(teacherClassSubjectsProvider);
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Pengolahan Nilai'),
        centerTitle: true,
        actions: [
          if (_selected != null && _grades.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'Cetak',
              onPressed: _handlePrint,
            ),
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Ekspor',
              onPressed: _handleExportExcel,
            ),
          ],
        ],
      ),
      body: classSubjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (jadwalList) {
          // Unique kombinasi kelas+mapel yang diajar guru.
          final pairs = <_ClassSubject>[];
          final seen = <String>{};
          for (final j in jadwalList) {
            final cs = _ClassSubject(kelas: j.kelas, mapel: j.mataPelajaran);
            if (seen.add(cs.key)) pairs.add(cs);
          }
          pairs.sort((a, b) {
            final c = a.kelas.compareTo(b.kelas);
            return c != 0 ? c : a.mapel.compareTo(b.mapel);
          });

          if (pairs.isEmpty) {
            return _buildNoSchedule();
          }

          // Auto-pilih pertama kalau belum ada / pilihan sudah hilang
          // (mis. jadwal ke-update). Ini menghindari state kosong.
          if (_selected == null || !pairs.contains(_selected)) {
            _selected = pairs.first;
            _grades.clear();
            _gradesKey = '';
          }

          return Column(
            children: [
              _buildSelectors(pairs),
              Expanded(
                child: studentsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Gagal memuat siswa: $e'),
                  ),
                  data: (students) {
                    final filtered = students
                        .where((s) =>
                            s.kelas.trim().toLowerCase() ==
                            _selected!.kelas.trim().toLowerCase())
                        .toList();
                    return _buildGradeTable(filtered);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoSchedule() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                size: 48,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada jadwal mengajar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hubungi admin sekolah untuk menambahkan kelas dan mata pelajaran yang Anda ajar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectors(List<_ClassSubject> pairs) {
    // Kelas unik yang diajar guru (dari pasangan kelas+mapel).
    final kelasList = pairs.map((p) => p.kelas).toSet().toList()..sort();
    // Mapel yang tersedia untuk kelas yang sedang dipilih.
    final mapelList = pairs
        .where((p) => p.kelas == _selected?.kelas)
        .map((p) => p.mapel)
        .toSet()
        .toList()
      ..sort();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class chips
          const Text(
            'Pilih Kelas',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kelasList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final kelas = kelasList[index];
                final isSelected = kelas == _selected?.kelas;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      // Saat ganti kelas, ambil mapel pertama untuk kelas itu.
                      final firstMapel = pairs
                          .firstWhere((p) => p.kelas == kelas)
                          .mapel;
                      _selected = _ClassSubject(
                        kelas: kelas,
                        mapel: firstMapel,
                      );
                      _isEditing = false;
                      _gradesKey = '';
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppColors.headerGradient : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? null
                          : Border.all(color: AppColors.divider),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        kelas,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // Subject dropdown — hanya mapel yang diajar di kelas terpilih.
          const Text(
            'Mata Pelajaran',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: mapelList.contains(_selected?.mapel)
                    ? _selected?.mapel
                    : null,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                hint: const Text(
                  'Pilih mata pelajaran',
                  style: TextStyle(fontSize: 14),
                ),
                items: mapelList
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m, style: const TextStyle(fontSize: 14)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null || _selected == null) return;
                  setState(() {
                    _selected = _ClassSubject(
                      kelas: _selected!.kelas,
                      mapel: v,
                    );
                    _isEditing = false;
                    _gradesKey = '';
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeTable(List<StudentData> students) {
    if (_selected == null) return const SizedBox.shrink();

    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_search_rounded,
                size: 48,
                color: AppColors.textMuted.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tidak ada siswa di kelas ini',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pastikan data siswa sudah terdaftar di kelas tersebut.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    // Re-init grades hanya saat key berubah (kelas/mapel ganti) supaya
    // input user tidak ke-reset tiap rebuild.
    final newKey = '${_selected!.key}|${students.length}';
    if (_gradesKey != newKey) {
      _initGrades(students, newKey);
    }

    return Column(
      children: [
        // Table header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.school_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_selected!.mapel}  •  Kelas ${_selected!.kelas}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _isEditing = !_isEditing),
                icon: Icon(_isEditing ? Icons.check : Icons.edit, size: 16),
                label: Text(
                  _isEditing ? 'Selesai' : 'Edit Nilai',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppColors.primary.withValues(alpha: 0.06),
                ),
                headingTextStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                columnSpacing: 18,
                horizontalMargin: 16,
                columns: [
                  const DataColumn(label: Text('No')),
                  const DataColumn(label: Text('NIS')),
                  const DataColumn(label: Text('Nama Siswa')),
                  ..._gradeColumns
                      .map((c) => DataColumn(label: Text(c), numeric: true)),
                  const DataColumn(label: Text('Rata²'), numeric: true),
                  const DataColumn(label: Text('Grade')),
                ],
                rows: List.generate(_grades.length, (i) {
                  final g = _grades[i];
                  return DataRow(
                    color: WidgetStateProperty.all(
                      i.isEven ? Colors.white : AppColors.scaffoldBg,
                    ),
                    cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(Text(g.nis)),
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Text(
                            g.namaSiswa,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(_gradeCell(g, 0)),
                      DataCell(_gradeCell(g, 1)),
                      DataCell(_gradeCell(g, 2)),
                      DataCell(_gradeCell(g, 3)),
                      DataCell(_gradeCell(g, 4)),
                      DataCell(_gradeCell(g, 5)),
                      DataCell(
                        Text(
                          g.average > 0 ? g.average.toStringAsFixed(1) : '-',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: g.average >= 70
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                      DataCell(_gradeLabel(g.grade, g.average)),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),

        // Bottom summary bar
        if (_grades.any((g) => g.average > 0))
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  _reportStat(
                    'Rata-rata Kelas',
                    _classAverage.toStringAsFixed(1),
                    AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  _reportStat(
                    'Tertinggi',
                    _highestScore.toStringAsFixed(1),
                    AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  _reportStat(
                    'Terendah',
                    _lowestScore.toStringAsFixed(1),
                    AppColors.error,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  double get _classAverage {
    final filled = _grades.where((g) => g.average > 0).toList();
    if (filled.isEmpty) return 0;
    return filled.map((g) => g.average).reduce((a, b) => a + b) /
        filled.length;
  }

  double get _highestScore {
    final filled = _grades.where((g) => g.average > 0).toList();
    if (filled.isEmpty) return 0;
    return filled.map((g) => g.average).reduce((a, b) => a > b ? a : b);
  }

  double get _lowestScore {
    final filled = _grades.where((g) => g.average > 0).toList();
    if (filled.isEmpty) return 0;
    return filled.map((g) => g.average).reduce((a, b) => a < b ? a : b);
  }

  Widget _gradeCell(GradeRow g, int colIndex) {
    double? value;
    switch (colIndex) {
      case 0:
        value = g.np1;
        break;
      case 1:
        value = g.np2;
        break;
      case 2:
        value = g.sas;
        break;
      case 3:
        value = g.sts;
        break;
      case 4:
        value = g.uh2;
        break;
      case 5:
        value = g.uh1;
        break;
    }

    if (!_isEditing) {
      return Text(
        value != null ? value.toStringAsFixed(0) : '-',
        style: TextStyle(
          color: value != null
              ? (value >= 70 ? AppColors.textPrimary : AppColors.error)
              : AppColors.textMuted,
        ),
      );
    }

    return SizedBox(
      width: 50,
      child: TextFormField(
        initialValue: value?.toStringAsFixed(0) ?? '',
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.5,
            ),
          ),
        ),
        onChanged: (v) {
          final parsed = double.tryParse(v);
          setState(() {
            switch (colIndex) {
              case 0:
                g.np1 = parsed;
                break;
              case 1:
                g.np2 = parsed;
                break;
              case 2:
                g.sas = parsed;
                break;
              case 3:
                g.sts = parsed;
                break;
              case 4:
                g.uh2 = parsed;
                break;
              case 5:
                g.uh1 = parsed;
                break;
            }
          });
        },
      ),
    );
  }

  Widget _gradeLabel(String grade, double avg) {
    if (avg <= 0) {
      return const Text('-', style: TextStyle(color: AppColors.textMuted));
    }
    Color c;
    switch (grade) {
      case 'A':
        c = AppColors.success;
        break;
      case 'B':
        c = AppColors.info;
        break;
      case 'C':
        c = AppColors.warning;
        break;
      default:
        c = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        grade,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: c,
        ),
      ),
    );
  }

  Widget _reportStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleExportExcel() {
    if (_selected == null) return;
    final buffer = StringBuffer();
    buffer.writeln(
      'No,NIS,Nama Siswa,${_gradeColumns.join(",")},Rata-rata,Grade',
    );
    for (int i = 0; i < _grades.length; i++) {
      final g = _grades[i];
      buffer.writeln(
        '${i + 1},${g.nis},${g.namaSiswa},'
        '${g.np1?.toStringAsFixed(0) ?? ""},'
        '${g.np2?.toStringAsFixed(0) ?? ""},'
        '${g.sas?.toStringAsFixed(0) ?? ""},'
        '${g.sts?.toStringAsFixed(0) ?? ""},'
        '${g.uh2?.toStringAsFixed(0) ?? ""},'
        '${g.uh1?.toStringAsFixed(0) ?? ""},'
        '${g.average > 0 ? g.average.toStringAsFixed(1) : ""},'
        '${g.average > 0 ? g.grade : ""}',
      );
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Data nilai berhasil disalin ke clipboard.\nPaste ke Excel atau Google Sheets.',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handlePrint() {
    if (_selected == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.print_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Cetak Laporan Nilai'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _printInfoRow('Mata Pelajaran', _selected!.mapel),
            _printInfoRow('Kelas', _selected!.kelas),
            _printInfoRow('Jumlah Siswa', '${_grades.length}'),
            _printInfoRow(
              'Rata-rata Kelas',
              _classAverage.toStringAsFixed(1),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.info),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pastikan printer sudah terhubung ke perangkat Anda.',
                      style: TextStyle(fontSize: 12, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Mengirim ke printer...'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Cetak Sekarang'),
          ),
        ],
      ),
    );
  }

  Widget _printInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
