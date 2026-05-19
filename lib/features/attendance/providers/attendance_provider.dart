import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AttendanceStatus { hadir, izin, sakit, alpha }

class MeetingAttendance {
  final String id;
  final String meetingName;
  final DateTime date;
  final AttendanceStatus status;
  final String? note;

  const MeetingAttendance({
    required this.id,
    required this.meetingName,
    required this.date,
    required this.status,
    this.note,
  });
}

class SubjectAttendanceSummary {
  final String subjectId;
  final String subjectName;
  final String teacherName;
  final List<MeetingAttendance> meetings;

  const SubjectAttendanceSummary({
    required this.subjectId,
    required this.subjectName,
    required this.teacherName,
    required this.meetings,
  });

  int get hadirCount => meetings.where((m) => m.status == AttendanceStatus.hadir).length;
  int get izinCount => meetings.where((m) => m.status == AttendanceStatus.izin).length;
  int get sakitCount => meetings.where((m) => m.status == AttendanceStatus.sakit).length;
  int get alphaCount => meetings.where((m) => m.status == AttendanceStatus.alpha).length;

  double get percentage =>
      meetings.isEmpty ? 0 : (hadirCount / meetings.length) * 100;
}

class OverallAttendanceSummary {
  final int totalMeetings;
  final int hadir;
  final int izin;
  final int sakit;
  final int alpha;

  const OverallAttendanceSummary({
    required this.totalMeetings,
    required this.hadir,
    required this.izin,
    required this.sakit,
    required this.alpha,
  });

  double get percentage => totalMeetings > 0 ? (hadir / totalMeetings) * 100 : 0;
}

/// TODO: Wire ke Supabase — query tabel `absensi` group by mata_pelajaran,
/// filter by id_siswa = user yang login.
final attendanceProvider =
    FutureProvider<List<SubjectAttendanceSummary>>((ref) async {
  return const <SubjectAttendanceSummary>[];
});

final attendanceSummaryProvider = Provider<OverallAttendanceSummary>((ref) {
  final recordsAsync = ref.watch(attendanceProvider);
  return recordsAsync.when(
    data: (subjects) {
      int h = 0, i = 0, s = 0, a = 0;
      int total = 0;
      for (final subj in subjects) {
        total += subj.meetings.length;
        h += subj.hadirCount;
        i += subj.izinCount;
        s += subj.sakitCount;
        a += subj.alphaCount;
      }
      return OverallAttendanceSummary(
          totalMeetings: total, hadir: h, izin: i, sakit: s, alpha: a);
    },
    loading: () => const OverallAttendanceSummary(
        totalMeetings: 0, hadir: 0, izin: 0, sakit: 0, alpha: 0),
    error: (_, __) => const OverallAttendanceSummary(
        totalMeetings: 0, hadir: 0, izin: 0, sakit: 0, alpha: 0),
  );
});
