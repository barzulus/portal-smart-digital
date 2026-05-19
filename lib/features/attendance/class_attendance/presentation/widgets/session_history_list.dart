import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../data/models/class_attendance_models.dart';
import '../design/attendance_tokens.dart';

class SessionHistoryList extends StatelessWidget {
  const SessionHistoryList({
    super.key,
    required this.records,
    required this.onUndo,
  });

  final List<AbsensiRecord> records;
  final Future<void> Function(AbsensiRecord record) onUndo;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.how_to_reg_rounded,
                color: AppColors.primary.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Belum ada siswa tercatat',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Mulai scan untuk menambahkan.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: records.length,
      itemBuilder: (context, i) {
        final r = records[i];
        return _HistoryTile(
          key: ValueKey('rec-${r.id ?? '${r.idSiswa}-${r.jamAbsensi}'}'),
          record: r,
          onUndo: () => onUndo(r),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({super.key, required this.record, required this.onUndo});
  final AbsensiRecord record;
  final Future<void> Function() onUndo;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(record.statusAbsensi);

    return Dismissible(
      key: ValueKey('dis-${record.id ?? record.idSiswa}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Batalkan absensi?'),
                content: Text(
                  '${record.namaSiswa ?? 'Siswa'} akan dihapus dari sesi ini.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Hapus'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async => await onUndo(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AttendanceTokens.cornerRadius),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.error),
            SizedBox(width: 6),
            Text('Batalkan',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(AttendanceTokens.cornerRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: 0.12),
              ),
              child: Icon(_metodeIcon(record.metodeAbsensi),
                  color: statusColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.namaSiswa ?? '(siswa)',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'NIS ${record.nisSiswa ?? '-'}  •  ${record.jamAbsensi}',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            _StatusPill(label: record.statusAbsensi.label, color: statusColor),
          ],
        ),
      ),
    );
  }

  IconData _metodeIcon(MetodeAbsensi m) {
    switch (m) {
      case MetodeAbsensi.qr:
        return Icons.qr_code_2_rounded;
      case MetodeAbsensi.rfid:
        return Icons.nfc_rounded;
      case MetodeAbsensi.manual:
        return Icons.keyboard_rounded;
    }
  }

  Color _statusColor(StatusAbsensi s) {
    switch (s) {
      case StatusAbsensi.hadir:
        return AppColors.success;
      case StatusAbsensi.izin:
        return AppColors.info;
      case StatusAbsensi.sakit:
        return AppColors.warning;
      case StatusAbsensi.alpha:
        return AppColors.error;
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
