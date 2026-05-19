import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/agenda_guru/providers/agenda_guru_provider.dart';
import '../../features/announcements/providers/announcements_provider.dart';
import '../../features/assignments/providers/assignments_provider.dart';
import '../../features/exams/providers/exams_provider.dart';
import '../../features/kegiatan_keagamaan/providers/kegiatan_keagamaan_provider.dart';
import '../../features/religious/providers/religious_provider.dart';
import '../../features/schedule/providers/schedule_provider.dart';
import '../../features/students/providers/students_provider.dart';
import '../../features/subjects/providers/subjects_provider.dart';
import '../../features/tugas_harian/providers/tugas_harian_provider.dart';

// ═══════════════════════════════════════════════════════════════
// CONNECTIVITY CHECK
// ═══════════════════════════════════════════════════════════════

/// Check internet connectivity using DNS lookup.
Future<bool> isOnline() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

// ═══════════════════════════════════════════════════════════════
// CONNECTIVITY NOTIFIER
// ═══════════════════════════════════════════════════════════════

class ConnectivityNotifier extends StateNotifier<bool> {
  final Ref _ref;
  Timer? _timer;
  bool _previousState = true;

  ConnectivityNotifier(this._ref) : super(true) {
    _startMonitoring();
  }

  void _startMonitoring() {
    _checkConnectivity();
    _scheduleNextCheck();
  }

  void _scheduleNextCheck() {
    _timer?.cancel();
    // Check every 5 seconds when offline, every 30 seconds when online
    final interval = state ? const Duration(seconds: 30) : const Duration(seconds: 5);
    _timer = Timer(interval, () {
      _checkConnectivity();
      _scheduleNextCheck();
    });
  }

  Future<void> _checkConnectivity() async {
    final online = await isOnline();
    _previousState = state;
    state = online;

    // Auto-refresh when connectivity is restored (offline → online)
    if (!_previousState && online) {
      _invalidateProviders();
    }
  }

  void _invalidateProviders() {
    _ref.invalidate(allJadwalProvider);
    _ref.invalidate(announcementsProvider);
    _ref.invalidate(studentsProvider);
    _ref.invalidate(tugasHarianProvider);
    _ref.invalidate(agendaGuruProvider);
    _ref.invalidate(kegiatanKeagamaanSiswaProvider);
    _ref.invalidate(subjectsProvider);
    _ref.invalidate(examsProvider);
    _ref.invalidate(assignmentsProvider);
    _ref.invalidate(religiousActivitiesProvider);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Provider that tracks online/offline status.
/// `true` = online, `false` = offline.
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier(ref);
});

// ═══════════════════════════════════════════════════════════════
// OFFLINE WARNING HELPER
// ═══════════════════════════════════════════════════════════════

/// Shows a SnackBar warning when the user is offline.
void showOfflineWarning(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Anda sedang offline. Hubungkan internet untuk menyimpan data.'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 3),
    ),
  );
}
