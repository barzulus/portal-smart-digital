import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../schedule/providers/schedule_provider.dart';
import '../../../students/providers/students_provider.dart';
import '../../providers/kegiatan_keagamaan_provider.dart';

/// Halaman Kegiatan Keagamaan — list dikelompokkan supaya tidak ratusan
/// baris flat. Hierarchy: Kelas → Siswa → Record kegiatan.
///
/// Filter chip di atas: All, dan tombol expand/collapse semua untuk
/// QoL kalau data banyak.
class KegiatanKeagamaanPage extends ConsumerStatefulWidget {
  const KegiatanKeagamaanPage({super.key});

  @override
  ConsumerState<KegiatanKeagamaanPage> createState() =>
      _KegiatanKeagamaanPageState();
}

class _KegiatanKeagamaanPageState extends ConsumerState<KegiatanKeagamaanPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  String? _statusFilter; // null = all
  // Track kelas yang sedang di-expand (supaya state stabil saat refresh).
  final Set<String> _expandedKelas = <String>{};
  bool _expandAllOverride = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(kegiatanKeagamaanSiswaProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Kegiatan Keagamaan'),
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Tambah Data',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(kegiatanKeagamaanSiswaProvider);
          await ref.read(kegiatanKeagamaanSiswaProvider.future);
        },
        child: recordsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildError(context, ref, '$e'),
          data: (records) {
            if (records.isEmpty) {
              return ListView(
                children: const [SizedBox(height: 120), _EmptyState()],
              );
            }
            return _buildContent(records);
          },
        ),
      ),
    );
  }

  Widget _buildContent(List<KegiatanKeagamaanSiswa> all) {
    // Filter berdasarkan search + status.
    final filtered = all.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return (r.namaSiswa ?? '').toLowerCase().contains(q) ||
            (r.namaKegiatan ?? '').toLowerCase().contains(q) ||
            (r.namaSurah ?? '').toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // Group: kelas → siswa → list record.
    final byKelas = <String, Map<String, List<KegiatanKeagamaanSiswa>>>{};
    for (final r in filtered) {
      final kelas = (r.namaKelas?.trim().isNotEmpty == true)
          ? r.namaKelas!
          : 'Tanpa Kelas';
      final siswa = r.namaSiswa ?? 'Siswa';
      byKelas.putIfAbsent(kelas, () => {}).putIfAbsent(siswa, () => []).add(r);
    }

    final kelasKeys = byKelas.keys.toList()..sort();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(filtered.length, all.length)),
        if (filtered.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _NoMatchState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList.separated(
              itemCount: kelasKeys.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final kelas = kelasKeys[i];
                final perSiswa = byKelas[kelas]!;
                final siswaKeys = perSiswa.keys.toList()..sort();
                final totalRecords =
                    perSiswa.values.fold<int>(0, (a, b) => a + b.length);
                return _KelasGroup(
                  kelas: kelas,
                  totalSiswa: siswaKeys.length,
                  totalRecords: totalRecords,
                  expanded: _expandAllOverride ||
                      _expandedKelas.contains(kelas),
                  onToggle: () => setState(() {
                    if (_expandAllOverride) {
                      // Saat user toggle individual setelah "Buka Semua",
                      // keluar dari mode global dan jadi list eksplisit.
                      _expandAllOverride = false;
                      _expandedKelas
                        ..clear()
                        ..addAll(byKelas.keys);
                    }
                    if (!_expandedKelas.add(kelas)) {
                      _expandedKelas.remove(kelas);
                    }
                  }),
                  perSiswa: perSiswa,
                  siswaKeys: siswaKeys,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(int filteredCount, int totalCount) {
    final statusOptions = <String?>[null, ...statusKeagamaanOptions];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          Container(
            decoration: BoxDecoration(
              color: AppColors.scaffoldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v.trim()),
              decoration: InputDecoration(
                hintText: 'Cari nama siswa, kegiatan, atau surah...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Status filter chips
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statusOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = statusOptions[i];
                final isActive = _statusFilter == s;
                return GestureDetector(
                  onTap: () => setState(() => _statusFilter = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      s ?? 'Semua',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Count + expand-all toggle
          Row(
            children: [
              Text(
                '$filteredCount dari $totalCount data',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    final allClosed = !_expandAllOverride &&
                        _expandedKelas.isEmpty;
                    if (allClosed) {
                      _expandAllOverride = true;
                    } else {
                      _expandAllOverride = false;
                      _expandedKelas.clear();
                    }
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  (_expandAllOverride || _expandedKelas.isNotEmpty)
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  size: 14,
                ),
                label: Text(
                  (_expandAllOverride || _expandedKelas.isNotEmpty)
                      ? 'Tutup Semua'
                      : 'Buka Semua',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String msg) {
    return ListView(
      children: [
        const SizedBox(height: 60),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  msg,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.invalidate(kegiatanKeagamaanSiswaProvider),
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
      builder: (_) => const _KegiatanFormSheet(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// KELAS GROUP — level 1 expansion
// ═══════════════════════════════════════════════════════════════

class _KelasGroup extends ConsumerWidget {
  const _KelasGroup({
    required this.kelas,
    required this.totalSiswa,
    required this.totalRecords,
    required this.expanded,
    required this.onToggle,
    required this.perSiswa,
    required this.siswaKeys,
  });

  final String kelas;
  final int totalSiswa;
  final int totalRecords;
  final bool expanded;
  final VoidCallback onToggle;
  final Map<String, List<KegiatanKeagamaanSiswa>> perSiswa;
  final List<String> siswaKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.headerGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.class_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kelas,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalSiswa siswa  •  $totalRecords data',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: AppColors.divider),
                ...siswaKeys.map((siswa) {
                  final records = perSiswa[siswa]!;
                  return _SiswaTile(siswa: siswa, records: records);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SISWA TILE — level 2 expansion
// ═══════════════════════════════════════════════════════════════

class _SiswaTile extends ConsumerStatefulWidget {
  const _SiswaTile({required this.siswa, required this.records});
  final String siswa;
  final List<KegiatanKeagamaanSiswa> records;

  @override
  ConsumerState<_SiswaTile> createState() => _SiswaTileState();
}

class _SiswaTileState extends ConsumerState<_SiswaTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Hitung ringkasan progress per siswa.
    final selesai = widget.records
        .where((r) => r.status == 'Selesai' || r.status == 'Lulus')
        .length;
    final progress =
        widget.records.isEmpty ? 0.0 : selesai / widget.records.length;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.keagamaanColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: AppColors.keagamaanColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.siswa,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$selesai/${widget.records.length} selesai',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: AppColors.divider,
                                color: progress >= 1
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.records.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Container(
            color: AppColors.scaffoldBg.withValues(alpha: 0.5),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Column(
              children: widget.records
                  .map((r) => _RecordRow(record: r))
                  .toList(),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RECORD ROW — leaf
// ═══════════════════════════════════════════════════════════════

class _RecordRow extends ConsumerWidget {
  const _RecordRow({required this.record});
  final KegiatanKeagamaanSiswa record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showOptions(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: record.statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.namaKegiatan ?? '-',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (record.namaSurah != null &&
                          record.namaSurah!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${record.namaSurah}'
                          '${record.nomorAyat != null ? ' : Ayat ${record.nomorAyat}' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: record.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record.status,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: record.statusColor,
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
                title: const Text('Edit Record'),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _KegiatanFormSheet(existing: record),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_rounded, color: AppColors.error),
                title: const Text(
                  'Hapus Record',
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
        title: const Text('Hapus Record'),
        content: const Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(kegiatanKeagamaanSiswaNotifierProvider.notifier)
                  .deleteRecord(record.id);
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

// ═══════════════════════════════════════════════════════════════
// EMPTY / NO MATCH STATES
// ═══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.mosque_rounded,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada data kegiatan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap tombol + untuk menambah data',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _NoMatchState extends StatelessWidget {
  const _NoMatchState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tidak ada hasil yang cocok',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Coba ubah kata kunci pencarian atau filter status.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FORM SHEET — sama seperti versi sebelumnya, dipakai ulang
// ═══════════════════════════════════════════════════════════════

class _KegiatanFormSheet extends ConsumerStatefulWidget {
  final KegiatanKeagamaanSiswa? existing;
  const _KegiatanFormSheet({this.existing});

  @override
  ConsumerState<_KegiatanFormSheet> createState() =>
      _KegiatanFormSheetState();
}

class _KegiatanFormSheetState extends ConsumerState<_KegiatanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _surahCtrl;
  late final TextEditingController _ayatCtrl;

  String? _selectedKelas;
  String? _selectedSiswaId;
  String? _selectedKegiatan;
  String? _selectedKegiatanNama;
  String _status = 'Belum Selesai';
  bool _isLoading = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _surahCtrl = TextEditingController(text: widget.existing?.namaSurah ?? '');
    _ayatCtrl = TextEditingController(
      text: widget.existing?.nomorAyat?.toString() ?? '',
    );
    _selectedSiswaId = widget.existing?.idSiswa;
    _selectedKegiatan = widget.existing?.idKegiatanKeagamaan;
    _selectedKegiatanNama = widget.existing?.namaKegiatan;
    _selectedKelas = widget.existing?.namaKelas;
    _status = widget.existing?.status ?? 'Belum Selesai';
  }

  @override
  void dispose() {
    _surahCtrl.dispose();
    _ayatCtrl.dispose();
    super.dispose();
  }

  bool get _showSurahFields =>
      _selectedKegiatanNama?.toLowerCase().contains('tahsin') == true;

  @override
  Widget build(BuildContext context) {
    final kegiatanListAsync = ref.watch(kegiatanKeagamaanListProvider);
    final classesAsync = ref.watch(teacherClassesProvider);
    final studentsAsync = ref.watch(studentsProvider);

    final classesList =
        classesAsync.maybeWhen(data: (c) => c, orElse: () => <String>[]);

    final filteredStudents = studentsAsync.maybeWhen(
      data: (students) {
        if (_selectedKelas == null || _selectedKelas!.isEmpty) return students;
        return students
            .where((s) =>
                s.kelas.trim().toLowerCase() ==
                _selectedKelas!.trim().toLowerCase())
            .toList();
      },
      orElse: () => <StudentData>[],
    );

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                  isEdit
                      ? 'Edit Data Kegiatan'
                      : 'Tambah Data Kegiatan Keagamaan',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Catat partisipasi siswa dalam kegiatan keagamaan',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                if (!isEdit) ...[
                  DropdownButtonFormField<String>(
                    value: classesList.contains(_selectedKelas)
                        ? _selectedKelas
                        : null,
                    decoration: _inputDeco('Kelas *', Icons.class_rounded),
                    isExpanded: true,
                    items: classesList
                        .map((k) =>
                            DropdownMenuItem(value: k, child: Text(k)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedKelas = v;
                      _selectedSiswaId = null;
                    }),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Kelas wajib dipilih'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedSiswaId,
                    decoration:
                        _inputDeco('Nama Siswa *', Icons.person_rounded),
                    isExpanded: true,
                    items: filteredStudents
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                s.namaSiswa,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSiswaId = v),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Siswa wajib dipilih'
                        : null,
                  ),
                  const SizedBox(height: 14),
                ],
                kegiatanListAsync.when(
                  data: (list) => DropdownButtonFormField<String>(
                    value: _selectedKegiatan,
                    decoration:
                        _inputDeco('Kegiatan Keagamaan *', Icons.mosque_rounded),
                    isExpanded: true,
                    items: list
                        .map((k) => DropdownMenuItem(
                              value: k.id,
                              child: Text(
                                k.namaKegiatan,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: isEdit
                        ? null
                        : (v) {
                            final selected =
                                list.where((k) => k.id == v).firstOrNull;
                            setState(() {
                              _selectedKegiatan = v;
                              _selectedKegiatanNama = selected?.namaKegiatan;
                            });
                          },
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Kegiatan wajib dipilih'
                        : null,
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, __) => const Text(
                    'Gagal memuat kegiatan',
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: _inputDeco('Status *', Icons.flag_rounded),
                  isExpanded: true,
                  items: statusKeagamaanOptions
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _status = v ?? 'Belum Selesai'),
                ),
                const SizedBox(height: 14),
                if (_showSurahFields) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          AppColors.keagamaanColor.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.keagamaanColor
                            .withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 16,
                              color: AppColors.keagamaanColor,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Detail Tahsin Quran',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.keagamaanColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _surahCtrl,
                          decoration:
                              _inputDeco('Nama Surah *', Icons.book_rounded),
                          validator: _showSurahFields
                              ? (v) => (v == null || v.trim().isEmpty)
                                  ? 'Nama surah wajib diisi'
                                  : null
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _ayatCtrl,
                          decoration: _inputDeco(
                            'Nomor Ayat *',
                            Icons.format_list_numbered_rounded,
                          ),
                          keyboardType: TextInputType.number,
                          validator: _showSurahFields
                              ? (v) => (v == null || v.trim().isEmpty)
                                  ? 'Nomor ayat wajib diisi'
                                  : null
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 10),
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
                            isEdit ? 'Simpan Perubahan' : 'Simpan Data',
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final notifier =
        ref.read(kegiatanKeagamaanSiswaNotifierProvider.notifier);
    final ayat = int.tryParse(_ayatCtrl.text.trim());
    bool success;

    if (isEdit) {
      success = await notifier.updateRecord(
        id: widget.existing!.id,
        namaSurah: _showSurahFields ? _surahCtrl.text.trim() : null,
        nomorAyat: _showSurahFields ? ayat : null,
        status: _status,
      );
    } else {
      final kelasListAsync = ref.read(kelasListProvider);
      String? idKelas;
      kelasListAsync.whenData((kelasList) {
        final match = kelasList
            .where((k) =>
                k.namaKelas.trim().toLowerCase() ==
                (_selectedKelas ?? '').trim().toLowerCase())
            .firstOrNull;
        idKelas = match?.id;
      });

      success = await notifier.createRecord(
        idSiswa: _selectedSiswaId!,
        idKegiatanKeagamaan: _selectedKegiatan!,
        idKelas: idKelas,
        namaSurah: _showSurahFields ? _surahCtrl.text.trim() : null,
        nomorAyat: _showSurahFields ? ayat : null,
        status: _status,
      );
    }

    setState(() => _isLoading = false);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Data berhasil diperbarui'
                : 'Data berhasil ditambahkan',
          ),
        ),
      );
    }
  }
}
