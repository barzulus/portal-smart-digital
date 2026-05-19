import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../schedule/providers/schedule_provider.dart';
import '../../providers/agenda_guru_provider.dart';

/// Halaman Agenda Guru — list per hari dengan day-strip horizontal
/// di header. Layout dibuat sesimpel mungkin: card datar dengan kolom
/// jam-ke di sebelah kiri.
class AgendaGuruPage extends ConsumerWidget {
  const AgendaGuruPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agendaAsync = ref.watch(agendaGuruProvider);
    final filterDate = ref.watch(agendaDateFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Agenda Guru'),
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Tambah Agenda',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          _WeekHeader(
            selectedDate: filterDate,
            onPrev: () => ref.read(agendaDateFilterProvider.notifier).state =
                filterDate.subtract(const Duration(days: 7)),
            onNext: () => ref.read(agendaDateFilterProvider.notifier).state =
                filterDate.add(const Duration(days: 7)),
            onToday: () => ref.read(agendaDateFilterProvider.notifier).state =
                DateTime.now(),
            onSelectDay: (d) =>
                ref.read(agendaDateFilterProvider.notifier).state = d,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(agendaGuruProvider);
                await ref.read(agendaGuruProvider.future);
              },
              child: agendaAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _buildError(context, ref, '$e'),
                data: (list) => _buildContent(list, filterDate),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<AgendaGuru> all, DateTime selected) {
    final today = all.where((a) => _isSameDay(a.tanggal, selected)).toList()
      ..sort((a, b) => a.jamKe.compareTo(b.jamKe));

    if (today.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: constraints.maxHeight * 0.15),
            _EmptyState(isToday: _isSameDay(selected, DateTime.now())),
          ],
        ),
      );
    }

    // Tanggal sebagai sub-header di list
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id').format(selected);
    final isToday = _isSameDay(selected, DateTime.now());

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: today.length + 1, // +1 untuk header tanggal
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 12),
            child: Row(
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Hari Ini',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${today.length} agenda',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final agenda = today[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AgendaCard(agenda: agenda),
        );
      },
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String msg) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
                  'Gagal memuat agenda',
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
                  onPressed: () => ref.invalidate(agendaGuruProvider),
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showFormSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AgendaFormSheet(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WEEK HEADER (compact)
// ═══════════════════════════════════════════════════════════════

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.selectedDate,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onSelectDay,
  });

  final DateTime selectedDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final weekday = selectedDate.weekday;
    final startOfWeek =
        selectedDate.subtract(Duration(days: weekday - 1));
    final monthLabel =
        DateFormat('MMMM yyyy', 'id').format(selectedDate);
    final now = DateTime.now();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: Column(
            children: [
              // Month + nav
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    onPressed: onPrev,
                    splashRadius: 20,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        monthLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    onPressed: onNext,
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Day strip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: List.generate(7, (i) {
                    final day = startOfWeek.add(Duration(days: i));
                    final isSelected = _isSameDay(day, selectedDate);
                    final isToday = _isSameDay(day, now);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onSelectDay(day),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isToday
                                    ? AppColors.primary
                                        .withValues(alpha: 0.06)
                                    : Colors.transparent),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _shortDayName(day),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white70
                                      : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : (isToday
                                          ? AppColors.primary
                                          : AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (!_isSameDay(selectedDate, now))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onToday,
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.today_rounded, size: 14),
                    label: const Text(
                      'Kembali ke Hari Ini',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortDayName(DateTime d) {
    const names = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return names[d.weekday - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ═══════════════════════════════════════════════════════════════
// AGENDA CARD — clean & flat
// ═══════════════════════════════════════════════════════════════

class _AgendaCard extends ConsumerWidget {
  const _AgendaCard({required this.agenda});
  final AgendaGuru agenda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOptions(context, ref),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Jam ke kolom kiri
                Container(
                  width: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'JAM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${agenda.jamKe}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Body kanan
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          agenda.materi,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _MetaItem(
                              icon: Icons.class_rounded,
                              text: agenda.kelas,
                            ),
                            _MetaItem(
                              icon: Icons.code_rounded,
                              text: agenda.kodeAjar,
                            ),
                          ],
                        ),
                        if (agenda.keterangan != null &&
                            agenda.keterangan!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            agenda.keterangan!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: AppColors.textMuted.withValues(alpha: 0.7),
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
                title: const Text('Edit Agenda'),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _AgendaFormSheet(existing: agenda),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_rounded, color: AppColors.error),
                title: const Text(
                  'Hapus Agenda',
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
        title: const Text('Hapus Agenda'),
        content: Text('Yakin ingin menghapus agenda "${agenda.materi}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(agendaGuruNotifierProvider.notifier)
                  .deleteAgenda(agenda.id);
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

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});
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
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isToday});
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_note_rounded,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isToday
                ? 'Belum ada agenda hari ini'
                : 'Belum ada agenda di tanggal ini',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap tombol + untuk menambah agenda mengajar',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FORM SHEET
// ═══════════════════════════════════════════════════════════════

class _AgendaFormSheet extends ConsumerStatefulWidget {
  final AgendaGuru? existing;
  const _AgendaFormSheet({this.existing});

  @override
  ConsumerState<_AgendaFormSheet> createState() => _AgendaFormSheetState();
}

class _AgendaFormSheetState extends ConsumerState<_AgendaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _materiCtrl;
  late final TextEditingController _kodeAjarCtrl;
  late final TextEditingController _keteranganCtrl;
  late DateTime _tanggal;
  late int _jamKe;
  String? _selectedKelas;
  bool _isLoading = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _materiCtrl = TextEditingController(text: widget.existing?.materi ?? '');
    _kodeAjarCtrl =
        TextEditingController(text: widget.existing?.kodeAjar ?? '');
    _keteranganCtrl =
        TextEditingController(text: widget.existing?.keterangan ?? '');
    _tanggal = widget.existing?.tanggal ?? DateTime.now();
    _jamKe = widget.existing?.jamKe ?? 1;
    _selectedKelas = widget.existing?.kelas;
  }

  @override
  void dispose() {
    _materiCtrl.dispose();
    _kodeAjarCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(teacherClassesProvider);
    final classesList =
        classesAsync.maybeWhen(data: (c) => c, orElse: () => <String>[]);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
                  isEdit ? 'Edit Agenda' : 'Tambah Agenda Baru',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: _inputDeco(
                        DateFormat('EEEE, d MMMM yyyy', 'id').format(_tanggal),
                        Icons.calendar_today_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: _jamKe,
                  decoration: _inputDeco('Jam Ke', Icons.access_time_rounded),
                  isExpanded: true,
                  items: List.generate(12, (i) => i + 1)
                      .map((j) => DropdownMenuItem(
                            value: j,
                            child: Text('Jam ke-$j'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _jamKe = v ?? 1),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _materiCtrl,
                  decoration:
                      _inputDeco('Materi Ajar *', Icons.menu_book_rounded),
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Materi wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _kodeAjarCtrl,
                  decoration: _inputDeco('Kode Ajar *', Icons.code_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Kode ajar wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),
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
                  onChanged: (v) => setState(() => _selectedKelas = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Kelas wajib dipilih' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _keteranganCtrl,
                  decoration:
                      _inputDeco('Keterangan (Opsional)', Icons.note_rounded),
                  maxLines: 2,
                ),
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
                            isEdit ? 'Simpan Perubahan' : 'Simpan Agenda',
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final notifier = ref.read(agendaGuruNotifierProvider.notifier);
    bool success;

    if (isEdit) {
      success = await notifier.updateAgenda(
        id: widget.existing!.id,
        tanggal: _tanggal,
        jamKe: _jamKe,
        materi: _materiCtrl.text.trim(),
        kodeAjar: _kodeAjarCtrl.text.trim(),
        kelas: _selectedKelas ?? '',
        keterangan: _keteranganCtrl.text.trim().isEmpty
            ? null
            : _keteranganCtrl.text.trim(),
      );
    } else {
      success = await notifier.createAgenda(
        tanggal: _tanggal,
        jamKe: _jamKe,
        materi: _materiCtrl.text.trim(),
        kodeAjar: _kodeAjarCtrl.text.trim(),
        kelas: _selectedKelas ?? '',
        keterangan: _keteranganCtrl.text.trim().isEmpty
            ? null
            : _keteranganCtrl.text.trim(),
      );
    }

    setState(() => _isLoading = false);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Agenda berhasil diperbarui'
                : 'Agenda berhasil ditambahkan',
          ),
        ),
      );
    }
  }
}
