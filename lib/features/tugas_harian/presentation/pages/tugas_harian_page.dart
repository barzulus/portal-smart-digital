import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/tugas_harian_provider.dart';

class TugasHarianPage extends ConsumerWidget {
  const TugasHarianPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tugasAsync = ref.watch(tugasHarianProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Tugas Harian'),
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Tambah Tugas', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tugasHarianProvider);
          await ref.read(tugasHarianProvider.future);
        },
        child: tugasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: '$e', onRetry: () => ref.invalidate(tugasHarianProvider)),
          data: (tugasList) {
            if (tugasList.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  _EmptyState(),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: tugasList.length,
              itemBuilder: (_, i) => _TugasCard(tugas: tugasList[i]),
            );
          },
        ),
      ),
    );
  }

  void _showFormSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TugasFormSheet(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: AppColors.textMuted.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('Belum ada tugas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Tap tombol + untuk menambah tugas baru',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ERROR VIEW
// ═══════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Gagal memuat tugas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message, style: const TextStyle(fontSize: 12, color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TUGAS CARD
// ═══════════════════════════════════════════════════════════════

class _TugasCard extends ConsumerWidget {
  final TugasHarian tugas;
  const _TugasCard({required this.tugas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: tugas.isOverdue
            ? Border.all(color: AppColors.error.withOpacity(0.25))
            : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDetail(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.tugasColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_rounded, size: 20, color: AppColors.tugasColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tugas.title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (tugas.description != null && tugas.description!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(tugas.description!,
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    if (tugas.isOverdue)
                      _StatusChip(label: 'Terlambat', color: AppColors.error)
                    else if (!tugas.isActive)
                      _StatusChip(label: 'Nonaktif', color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 10),
                // Footer row
                Row(
                  children: [
                    if (tugas.dueDate != null) ...[
                      Icon(Icons.schedule_rounded, size: 13,
                          color: tugas.isOverdue ? AppColors.error : AppColors.textMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tugas.dueDateFormatted,
                          style: TextStyle(fontSize: 11,
                              color: tugas.isOverdue ? AppColors.error : AppColors.textSecondary,
                              fontWeight: tugas.isOverdue ? FontWeight.w600 : FontWeight.normal),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (tugas.hasDocument)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.attach_file_rounded, size: 15, color: AppColors.primary.withOpacity(0.7)),
                      ),
                    if (tugas.hasYoutube)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.play_circle_outline_rounded, size: 15, color: Colors.red),
                      ),
                    if (tugas.isActive && tugas.dueDate != null && tugas.daysLeft >= 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (tugas.daysLeft <= 2 ? AppColors.warning : AppColors.success).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tugas.daysLeft == 0 ? 'Hari ini' : '${tugas.daysLeft} hari lagi',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                              color: tugas.daysLeft <= 2 ? AppColors.warning : AppColors.success),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TugasDetailSheet(tugas: tugas),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DETAIL SHEET
// ═══════════════════════════════════════════════════════════════

class _TugasDetailSheet extends ConsumerWidget {
  final TugasHarian tugas;
  const _TugasDetailSheet({required this.tugas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            // Title + actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(tugas.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                  onSelected: (val) => _handleAction(context, ref, val),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Tugas')),
                    const PopupMenuItem(value: 'delete',
                        child: Text('Hapus Tugas', style: TextStyle(color: AppColors.error))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info rows
            if (tugas.dueDate != null)
              _DetailRow(icon: Icons.calendar_today_rounded, label: 'Tenggat Waktu', value: tugas.dueDateFormatted),
            if (tugas.description != null && tugas.description!.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Deskripsi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(tugas.description!, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary)),
            ],
            if (tugas.hasYoutube) ...[
              const SizedBox(height: 14),
              _DetailRow(icon: Icons.play_circle_outline_rounded, label: 'Link YouTube', value: tugas.youtubeLink!, iconColor: Colors.red),
            ],
            if (tugas.hasDocument) ...[
              const SizedBox(height: 14),
              _DetailRow(icon: Icons.attach_file_rounded, label: 'Lampiran', value: tugas.documentName ?? 'Dokumen'),
            ],
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    Navigator.pop(context);
    if (action == 'edit') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TugasFormSheet(existing: tugas),
      );
    } else if (action == 'delete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus Tugas'),
          content: Text('Yakin ingin menghapus "${tugas.title}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(tugasHarianNotifierProvider.notifier).deleteTugas(tugas.id);
              },
              child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  const _DetailRow({required this.icon, required this.label, required this.value, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor ?? AppColors.textMuted),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FORM SHEET (CREATE / EDIT)
// ═══════════════════════════════════════════════════════════════

class _TugasFormSheet extends ConsumerStatefulWidget {
  final TugasHarian? existing;
  const _TugasFormSheet({this.existing});

  @override
  ConsumerState<_TugasFormSheet> createState() => _TugasFormSheetState();
}

class _TugasFormSheetState extends ConsumerState<_TugasFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _youtubeCtrl;
  DateTime? _dueDate;
  File? _pickedFile;
  String? _pickedFileName;
  bool _isLoading = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _youtubeCtrl = TextEditingController(text: widget.existing?.youtubeLink ?? '');
    _dueDate = widget.existing?.dueDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _youtubeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(isEdit ? 'Edit Tugas' : 'Tambah Tugas Baru',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                // Judul
                TextFormField(
                  controller: _titleCtrl,
                  decoration: _inputDeco('Judul Tugas *', Icons.title_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                // Deskripsi
                TextFormField(
                  controller: _descCtrl,
                  decoration: _inputDeco('Deskripsi (opsional)', Icons.description_rounded),
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                // Tenggat Waktu
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: _inputDeco(
                        _dueDate != null
                            ? 'Tenggat: ${DateFormat('d MMMM yyyy', 'id').format(_dueDate!)}'
                            : 'Pilih Tenggat Waktu (opsional)',
                        Icons.calendar_today_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Link YouTube
                TextFormField(
                  controller: _youtubeCtrl,
                  decoration: _inputDeco('Link YouTube (opsional)', Icons.play_circle_outline_rounded),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 14),

                // Lampiran Dokumen
                _buildDocumentPicker(),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Simpan Perubahan' : 'Simpan Tugas',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentPicker() {
    final hasExisting = isEdit && widget.existing!.hasDocument && _pickedFile == null;
    final hasNew = _pickedFile != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickDocument,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file_rounded, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasNew
                        ? _pickedFileName ?? 'Dokumen dipilih'
                        : hasExisting
                            ? widget.existing!.documentName ?? 'Dokumen terlampir'
                            : 'Lampiran Dokumen (maks 10 MB)',
                    style: TextStyle(
                      fontSize: 14,
                      color: (hasNew || hasExisting) ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasNew || hasExisting)
                  GestureDetector(
                    onTap: () => setState(() {
                      _pickedFile = null;
                      _pickedFileName = null;
                    }),
                    child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text('Format: PDF, DOC, PPT, XLS, JPG, PNG (maks 10 MB)',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.scaffoldBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'],
      withData: false,
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final size = await file.length();
      if (size > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ukuran file melebihi 10 MB'), backgroundColor: AppColors.error),
          );
        }
        return;
      }
      setState(() {
        _pickedFile = file;
        _pickedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final notifier = ref.read(tugasHarianNotifierProvider.notifier);
    bool success;

    if (isEdit) {
      success = await notifier.updateTugas(
        id: widget.existing!.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        dueDate: _dueDate,
        youtubeLink: _youtubeCtrl.text.trim().isEmpty ? null : _youtubeCtrl.text.trim(),
        documentFile: _pickedFile,
        documentFileName: _pickedFileName,
        existingDocUrl: _pickedFile == null ? widget.existing?.documentUrl : null,
        existingDocName: _pickedFile == null ? widget.existing?.documentName : null,
      );
    } else {
      success = await notifier.createTugas(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        dueDate: _dueDate,
        youtubeLink: _youtubeCtrl.text.trim().isEmpty ? null : _youtubeCtrl.text.trim(),
        documentFile: _pickedFile,
        documentFileName: _pickedFileName,
      );
    }

    setState(() => _isLoading = false);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Tugas berhasil diperbarui' : 'Tugas berhasil ditambahkan')),
      );
    }
  }
}
