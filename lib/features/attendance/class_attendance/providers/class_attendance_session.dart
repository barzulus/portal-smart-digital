import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/guru_staff_provider.dart';
import '../../../schedule/providers/schedule_provider.dart';
import '../data/models/class_attendance_models.dart';
import '../data/repositories/absensi_repository.dart';
import '../data/repositories/student_resolver.dart';

/// Fase UI halaman absensi kelas.
enum SessionPhase {
  selectJadwal,
  selectTipe,
  scanning,
}

/// State untuk sesi absensi yang sedang berjalan.
class ClassAttendanceSessionState {
  final SessionPhase phase;
  final JadwalPelajaran? jadwal;
  final TipeAbsensi? tipe;
  final MetodeAbsensi metode;
  final List<AbsensiRecord> history;
  final bool isSubmitting;
  final AttendanceException? lastError;

  const ClassAttendanceSessionState({
    this.phase = SessionPhase.selectJadwal,
    this.jadwal,
    this.tipe,
    this.metode = MetodeAbsensi.rfid,
    this.history = const [],
    this.isSubmitting = false,
    this.lastError,
  });

  ClassAttendanceSessionState copyWith({
    SessionPhase? phase,
    JadwalPelajaran? jadwal,
    TipeAbsensi? tipe,
    MetodeAbsensi? metode,
    List<AbsensiRecord>? history,
    bool? isSubmitting,
    AttendanceException? lastError,
    bool clearError = false,
    bool clearJadwal = false,
    bool clearTipe = false,
  }) {
    return ClassAttendanceSessionState(
      phase: phase ?? this.phase,
      jadwal: clearJadwal ? null : (jadwal ?? this.jadwal),
      tipe: clearTipe ? null : (tipe ?? this.tipe),
      metode: metode ?? this.metode,
      history: history ?? this.history,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  int get totalTercatat => history.length;
  Set<String> get studentIdsTercatat => history.map((r) => r.idSiswa).toSet();
  bool get hasActiveSession => phase == SessionPhase.scanning && jadwal != null && tipe != null;
}

class ClassAttendanceSessionNotifier
    extends StateNotifier<ClassAttendanceSessionState> {
  ClassAttendanceSessionNotifier({
    required this.ref,
    required this.repository,
    required this.resolver,
  }) : super(const ClassAttendanceSessionState());

  final Ref ref;
  final AbsensiRepository repository;
  final StudentResolver resolver;

  /// Langkah 1: user pilih jadwal. Validasi guru pengampu dilakukan di sini.
  Future<void> selectJadwal(JadwalPelajaran jadwal) async {
    final userId = ref.read(authProvider).user?.id;
    final idSekolah = ref.read(currentIdSekolahProvider);

    if (userId == null || idSekolah == null) {
      state = state.copyWith(
        lastError: const AttendanceException(
          AttendanceErrorCode.notAuthorized,
          'Sesi tidak valid, silakan login ulang.',
        ),
      );
      return;
    }

    if (jadwal.idSekolah != idSekolah) {
      state = state.copyWith(
        lastError: const AttendanceException(
          AttendanceErrorCode.notAuthorized,
          'Jadwal bukan dari sekolah Anda.',
        ),
      );
      return;
    }

    // Guru pengampu: pakai provider STRICT (level 1 = guru_id, level 2 = nama).
    // Fallback by-mapel sengaja tidak dipakai untuk write action ini supaya
    // guru tidak bisa absensi kelas guru lain yang kebetulan ngajar mapel sama.
    //
    // Kalau provider belum data (loading/error), kita lempar error yang
    // user-friendly daripada false-negative "bukan pengampu".
    final myJadwalAsync = ref.read(myJadwalForAttendanceProvider);
    if (myJadwalAsync.isLoading) {
      state = state.copyWith(
        lastError: const AttendanceException(
          AttendanceErrorCode.unknown,
          'Sedang memuat jadwal Anda. Coba lagi sebentar.',
        ),
      );
      return;
    }
    final myList = myJadwalAsync.maybeWhen(
      data: (l) => l,
      orElse: () => const <JadwalPelajaran>[],
    );
    final isOwner = myList.any((j) => j.id == jadwal.id);

    if (!isOwner) {
      state = state.copyWith(
        lastError: const AttendanceException(
          AttendanceErrorCode.notAuthorized,
          'Anda bukan guru pengampu jadwal ini.',
        ),
      );
      return;
    }

    state = state.copyWith(
      phase: SessionPhase.selectTipe,
      jadwal: jadwal,
      history: const [],
      clearTipe: true,
      clearError: true,
    );
  }

  /// Langkah 2: user pilih tipe absensi (masuk/pulang).
  Future<void> selectTipe(TipeAbsensi tipe) async {
    final jadwal = state.jadwal;
    final idSekolah = ref.read(currentIdSekolahProvider);
    if (jadwal == null || idSekolah == null) return;

    // Muat history yang sudah ada untuk sesi (jadwal + tipe + tanggal hari ini).
    final tanggal = _today();
    try {
      final existing = await repository.getSessionRecords(
        idSekolah: idSekolah,
        idJadwal: jadwal.id,
        tanggal: tanggal,
        tipe: tipe,
      );
      state = state.copyWith(
        phase: SessionPhase.scanning,
        tipe: tipe,
        history: existing,
        clearError: true,
      );
    } on AttendanceException catch (e) {
      // Masih bisa masuk ke scanner walau history gagal fetch.
      state = state.copyWith(
        phase: SessionPhase.scanning,
        tipe: tipe,
        history: const [],
        lastError: e,
      );
    }
  }

  /// Ganti metode scan tanpa reset history.
  void setMetode(MetodeAbsensi metode) {
    state = state.copyWith(metode: metode, clearError: true);
  }

  /// Kembali ke fase sebelumnya.
  void back() {
    switch (state.phase) {
      case SessionPhase.selectJadwal:
        break;
      case SessionPhase.selectTipe:
        state = state.copyWith(
          phase: SessionPhase.selectJadwal,
          clearJadwal: true,
          clearTipe: true,
          history: const [],
          clearError: true,
        );
        break;
      case SessionPhase.scanning:
        state = state.copyWith(
          phase: SessionPhase.selectTipe,
          clearTipe: true,
          history: const [],
          clearError: true,
        );
        break;
    }
  }

  /// Reset total (misal keluar dari halaman).
  void reset() {
    state = const ClassAttendanceSessionState();
  }

  /// Satu "scan" — resolve identitas, validasi, simpan, update history.
  /// Return record yang tersimpan supaya UI bisa animasikan flash success.
  Future<AbsensiRecord> recordScan({
    required ScanInput input,
    required StatusAbsensi status,
    String? keterangan,
  }) async {
    final jadwal = state.jadwal;
    final tipe = state.tipe;
    final userId = ref.read(authProvider).user?.id;
    final idSekolah = ref.read(currentIdSekolahProvider);

    // `absensi.id_guru` FK ke `guru_staff(id)`, bukan ke `users(id)`.
    // Harus lookup dulu sebelum insert.
    final guruStaffId = await ref.read(currentGuruStaffIdProvider.future);

    if (!state.hasActiveSession ||
        jadwal == null ||
        tipe == null ||
        userId == null ||
        idSekolah == null ||
        guruStaffId == null) {
      throw const AttendanceException(
        AttendanceErrorCode.notAuthorized,
        'Sesi tidak aktif atau akun guru belum terhubung ke guru_staff.',
      );
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      // 1. Resolve ke StudentLite
      final student = await input.resolve(resolver, idSekolah);

      // 2. Validasi kelas + sekolah
      if (student.idSekolah != idSekolah) {
        throw const AttendanceException(
          AttendanceErrorCode.studentWrongSchool,
          'Siswa bukan dari sekolah Anda.',
        );
      }
      if (student.kelas != jadwal.kelas) {
        throw AttendanceException(
          AttendanceErrorCode.studentWrongClass,
          '${student.namaSiswa} terdaftar di kelas ${student.kelas}, bukan ${jadwal.kelas}.',
        );
      }

      // 3. Cek duplikat lokal (cepat sebelum hit server)
      if (state.studentIdsTercatat.contains(student.id)) {
        throw AttendanceException(
          AttendanceErrorCode.duplicate,
          '${student.namaSiswa} sudah diabsen pada sesi ini.',
        );
      }

      // 4. Build record + insert
      final now = DateTime.now();
      final record = AbsensiRecord(
        idJadwal: jadwal.id,
        idSiswa: student.id,
        idGuru: guruStaffId,
        idSekolah: idSekolah,
        kelas: jadwal.kelas,
        mataPelajaran: jadwal.mataPelajaran,
        tanggalAbsensi: _formatDate(now),
        jamAbsensi: _formatTime(now),
        tipeAbsensi: tipe,
        metodeAbsensi: state.metode,
        statusAbsensi: status,
        keterangan: keterangan,
        rfidCode: input.rfidCodeForRecord,
        qrcodeData: input.qrcodeDataForRecord,
        namaSiswa: student.namaSiswa,
        nisSiswa: student.nis,
      );

      final saved = await repository.createRecord(record);
      state = state.copyWith(
        history: [saved, ...state.history],
        isSubmitting: false,
        clearError: true,
      );
      return saved;
    } on AttendanceException catch (e) {
      state = state.copyWith(isSubmitting: false, lastError: e);
      rethrow;
    } catch (e) {
      final err = AttendanceException(
        AttendanceErrorCode.unknown,
        e.toString(),
      );
      state = state.copyWith(isSubmitting: false, lastError: err);
      throw err;
    }
  }

  /// Batalkan salah satu record (swipe-to-dismiss).
  Future<void> undoRecord(AbsensiRecord record) async {
    final idSekolah = ref.read(currentIdSekolahProvider);
    if (idSekolah == null || record.id == null) return;
    try {
      await repository.deleteRecord(id: record.id!, idSekolah: idSekolah);
      state = state.copyWith(
        history: state.history.where((r) => r.id != record.id).toList(),
      );
    } on AttendanceException catch (e) {
      state = state.copyWith(lastError: e);
    }
  }

  String _today() {
    final now = DateTime.now();
    return _formatDate(now);
  }

  String _formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  String _formatTime(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}

/// Nilai yang dikirim UI ke notifier setiap kali scan berhasil.
/// Dibungkus class supaya kita bisa bawa metadata seperti qrPayload / rfidCode
/// untuk diisi ke kolom absensi.
abstract class ScanInput {
  Future<StudentLite> resolve(StudentResolver resolver, String idSekolah);
  String? get rfidCodeForRecord => null;
  String? get qrcodeDataForRecord => null;
}

class QrScanInput extends ScanInput {
  QrScanInput(this.payload);
  final String payload;

  @override
  Future<StudentLite> resolve(StudentResolver resolver, String idSekolah) {
    return resolver.resolveQr(payload: payload, idSekolah: idSekolah);
  }

  @override
  String? get qrcodeDataForRecord => payload;
}

class RfidScanInput extends ScanInput {
  RfidScanInput(this.code);
  final String code;

  @override
  Future<StudentLite> resolve(StudentResolver resolver, String idSekolah) {
    return resolver.resolveRfid(rfidCode: code, idSekolah: idSekolah);
  }

  @override
  String? get rfidCodeForRecord => code;
}

class ManualScanInput extends ScanInput {
  ManualScanInput(this.nis);
  final String nis;

  @override
  Future<StudentLite> resolve(StudentResolver resolver, String idSekolah) {
    return resolver.resolveNis(nis: nis, idSekolah: idSekolah);
  }
}

final classAttendanceSessionProvider = StateNotifierProvider.autoDispose<
    ClassAttendanceSessionNotifier, ClassAttendanceSessionState>((ref) {
  return ClassAttendanceSessionNotifier(
    ref: ref,
    repository: ref.watch(absensiRepositoryProvider),
    resolver: ref.watch(studentResolverProvider),
  );
});
