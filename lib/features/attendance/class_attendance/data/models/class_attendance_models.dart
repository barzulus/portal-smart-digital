/// Enum untuk kolom-kolom `absensi` supaya tidak ada magic string berserakan.
enum TipeAbsensi {
  masuk,
  pulang;

  String get value => name;
  String get label => this == TipeAbsensi.masuk ? 'Masuk' : 'Pulang';

  static TipeAbsensi fromString(String s) {
    return TipeAbsensi.values.firstWhere(
      (e) => e.name == s.toLowerCase(),
      orElse: () => TipeAbsensi.masuk,
    );
  }
}

enum MetodeAbsensi {
  qr,
  rfid,
  manual;

  /// Nilai yang dikirim ke DB — harus match CHECK constraint di kolom
  /// `absensi.metode_absensi`: 'qr_code', 'rfid', 'manual'.
  String get value {
    switch (this) {
      case MetodeAbsensi.qr:
        return 'qr_code';
      case MetodeAbsensi.rfid:
        return 'rfid';
      case MetodeAbsensi.manual:
        return 'manual';
    }
  }

  String get label {
    switch (this) {
      case MetodeAbsensi.qr:
        return 'QR Code';
      case MetodeAbsensi.rfid:
        return 'RFID';
      case MetodeAbsensi.manual:
        return 'Manual';
    }
  }
}

enum StatusAbsensi {
  hadir,
  izin,
  sakit,
  alpha;

  /// Nilai yang dikirim ke DB — harus match CHECK constraint:
  /// 'Hadir', 'Sakit', 'Izin', 'Alpa', 'Terlambat'
  String get value {
    switch (this) {
      case StatusAbsensi.hadir:
        return 'Hadir';
      case StatusAbsensi.izin:
        return 'Izin';
      case StatusAbsensi.sakit:
        return 'Sakit';
      case StatusAbsensi.alpha:
        return 'Alpa';
    }
  }

  String get label {
    switch (this) {
      case StatusAbsensi.hadir:
        return 'Hadir';
      case StatusAbsensi.izin:
        return 'Izin';
      case StatusAbsensi.sakit:
        return 'Sakit';
      case StatusAbsensi.alpha:
        return 'Alpha';
    }
  }

  static StatusAbsensi fromString(String s) {
    final lower = s.toLowerCase();
    if (lower == 'izin') return StatusAbsensi.izin;
    if (lower == 'sakit') return StatusAbsensi.sakit;
    if (lower == 'alpa' || lower == 'alpha') return StatusAbsensi.alpha;
    return StatusAbsensi.hadir;
  }
}

/// Model baris tabel `absensi`.
class AbsensiRecord {
  final String? id;
  final String idJadwal;
  final String idSiswa;
  final String idGuru;
  final String idSekolah;
  final String kelas;
  final String mataPelajaran;
  final String tanggalAbsensi;
  final String jamAbsensi;
  final TipeAbsensi tipeAbsensi;
  final MetodeAbsensi metodeAbsensi;
  final StatusAbsensi statusAbsensi;
  final String? keterangan;
  final String? rfidCode;
  final String? qrcodeData;
  // Hanya untuk UI — nama siswa (hasil JOIN, tidak masuk payload insert)
  final String? namaSiswa;
  final String? nisSiswa;

  const AbsensiRecord({
    this.id,
    required this.idJadwal,
    required this.idSiswa,
    required this.idGuru,
    required this.idSekolah,
    required this.kelas,
    required this.mataPelajaran,
    required this.tanggalAbsensi,
    required this.jamAbsensi,
    required this.tipeAbsensi,
    required this.metodeAbsensi,
    required this.statusAbsensi,
    this.keterangan,
    this.rfidCode,
    this.qrcodeData,
    this.namaSiswa,
    this.nisSiswa,
  });

  factory AbsensiRecord.fromJson(Map<String, dynamic> json) {
    // Embed `students:id_siswa(nama_siswa,nis)` dari PostgREST → konsumsi
    // di sini supaya semua call site (read/insert returning) konsisten.
    String? namaSiswa;
    String? nisSiswa;
    final student = json['students'];
    if (student is Map<String, dynamic>) {
      namaSiswa = student['nama_siswa']?.toString();
      nisSiswa = student['nis']?.toString();
    }

    return AbsensiRecord(
      id: json['id']?.toString(),
      idJadwal: json['id_jadwal']?.toString() ?? '',
      idSiswa: json['id_siswa']?.toString() ?? '',
      idGuru: json['id_guru']?.toString() ?? '',
      idSekolah: json['id_sekolah']?.toString() ?? '',
      kelas: json['kelas']?.toString() ?? '',
      mataPelajaran: json['mata_pelajaran']?.toString() ?? '',
      tanggalAbsensi: json['tanggal_absensi']?.toString() ?? '',
      jamAbsensi: json['jam_absensi']?.toString() ?? '',
      tipeAbsensi: TipeAbsensi.fromString(json['tipe_absensi']?.toString() ?? 'masuk'),
      metodeAbsensi: _parseMetode(json['metode_absensi']?.toString()),
      statusAbsensi: StatusAbsensi.fromString(json['status_absensi']?.toString() ?? 'hadir'),
      keterangan: json['keterangan']?.toString(),
      rfidCode: json['rfid_code']?.toString(),
      qrcodeData: json['qrcode_data']?.toString(),
      namaSiswa: namaSiswa,
      nisSiswa: nisSiswa,
    );
  }

  static MetodeAbsensi _parseMetode(String? s) {
    if (s == null) return MetodeAbsensi.manual;
    final lower = s.toLowerCase();
    // 'qr_code' (DB), 'qr' (legacy/enum name), atau apapun yang mulai 'qr'.
    if (lower == 'qr_code' || lower == 'qr' || lower.startsWith('qr')) {
      return MetodeAbsensi.qr;
    }
    if (lower == 'rfid') return MetodeAbsensi.rfid;
    return MetodeAbsensi.manual;
  }

  Map<String, dynamic> toInsertJson() {
    return {
      if (idJadwal.isNotEmpty) 'id_jadwal': idJadwal,
      'id_siswa': idSiswa,
      if (idGuru.isNotEmpty) 'id_guru': idGuru,
      'id_sekolah': idSekolah,
      'kelas': kelas,
      'mata_pelajaran': mataPelajaran,
      'tanggal_absensi': tanggalAbsensi,
      'jam_absensi': jamAbsensi,
      'tipe_absensi': tipeAbsensi.value,
      'metode_absensi': metodeAbsensi.value,
      'status_absensi': statusAbsensi.value,
      if (keterangan != null && keterangan!.isNotEmpty) 'keterangan': keterangan,
      if (rfidCode != null) 'rfid_code': rfidCode,
      if (qrcodeData != null) 'qrcode_data': qrcodeData,
    };
  }

  AbsensiRecord copyWith({
    String? id,
    String? namaSiswa,
    String? nisSiswa,
  }) {
    return AbsensiRecord(
      id: id ?? this.id,
      idJadwal: idJadwal,
      idSiswa: idSiswa,
      idGuru: idGuru,
      idSekolah: idSekolah,
      kelas: kelas,
      mataPelajaran: mataPelajaran,
      tanggalAbsensi: tanggalAbsensi,
      jamAbsensi: jamAbsensi,
      tipeAbsensi: tipeAbsensi,
      metodeAbsensi: metodeAbsensi,
      statusAbsensi: statusAbsensi,
      keterangan: keterangan,
      rfidCode: rfidCode,
      qrcodeData: qrcodeData,
      namaSiswa: namaSiswa ?? this.namaSiswa,
      nisSiswa: nisSiswa ?? this.nisSiswa,
    );
  }
}

/// Data siswa minimal yang dibutuhkan flow absensi (dari tabel `students`).
class StudentLite {
  final String id;
  final String nis;
  final String namaSiswa;
  final String kelas;
  final String idSekolah;

  const StudentLite({
    required this.id,
    required this.nis,
    required this.namaSiswa,
    required this.kelas,
    required this.idSekolah,
  });

  factory StudentLite.fromJson(Map<String, dynamic> json) {
    return StudentLite(
      id: json['id']?.toString() ?? '',
      nis: json['nis']?.toString() ?? '',
      namaSiswa: json['nama_siswa']?.toString() ?? '',
      kelas: json['kelas']?.toString() ?? '',
      idSekolah: json['id_sekolah']?.toString() ?? '',
    );
  }
}

/// Error code enum supaya UI bisa map ke pesan yang tepat.
enum AttendanceErrorCode {
  studentNotFound,
  studentWrongClass,
  studentWrongSchool,
  rfidNotRegistered,
  qrInvalidFormat,
  nisInvalid,
  duplicate,
  notAuthorized,
  network,
  unknown,
}

class AttendanceException implements Exception {
  final AttendanceErrorCode code;
  final String message;

  const AttendanceException(this.code, this.message);

  @override
  String toString() => 'AttendanceException($code): $message';
}
