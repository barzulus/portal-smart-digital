import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

const _kNotifEnabledKey = 'notif_enabled';

class NotificationSettingsState {
  /// Effective state — true kalau user aktifin DAN OS izin.
  final bool enabled;

  /// State izin OS terakhir yang kita tahu.
  final bool osPermissionGranted;

  /// True kalau user pernah aktifin tapi izin OS ditolak permanen,
  /// supaya UI bisa kasih tombol "Buka Pengaturan Sistem".
  final bool needsSystemSettings;

  final bool isLoading;

  const NotificationSettingsState({
    required this.enabled,
    required this.osPermissionGranted,
    this.needsSystemSettings = false,
    this.isLoading = false,
  });

  NotificationSettingsState copyWith({
    bool? enabled,
    bool? osPermissionGranted,
    bool? needsSystemSettings,
    bool? isLoading,
  }) {
    return NotificationSettingsState(
      enabled: enabled ?? this.enabled,
      osPermissionGranted: osPermissionGranted ?? this.osPermissionGranted,
      needsSystemSettings: needsSystemSettings ?? this.needsSystemSettings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettingsState> {
  NotificationSettingsNotifier()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ),
        super(const NotificationSettingsState(
          enabled: false,
          osPermissionGranted: false,
          isLoading: true,
        )) {
    _load();
  }

  final FlutterSecureStorage _storage;

  Future<void> _load() async {
    final stored = (await _storage.read(key: _kNotifEnabledKey)) == 'true';
    final osGranted = await _isOsPermissionGranted();
    state = NotificationSettingsState(
      enabled: stored && osGranted,
      osPermissionGranted: osGranted,
      isLoading: false,
    );
  }

  Future<bool> _isOsPermissionGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Toggle notifikasi. Kalau user mau aktifin → minta izin OS.
  /// Kalau ditolak permanen → set flag needsSystemSettings supaya UI
  /// bisa kasih tombol untuk buka pengaturan.
  Future<void> toggle(bool value) async {
    state = state.copyWith(isLoading: true, needsSystemSettings: false);

    if (value) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        await _storage.write(key: _kNotifEnabledKey, value: 'true');
        state = const NotificationSettingsState(
          enabled: true,
          osPermissionGranted: true,
          isLoading: false,
        );
      } else if (status.isPermanentlyDenied) {
        await _storage.write(key: _kNotifEnabledKey, value: 'false');
        state = const NotificationSettingsState(
          enabled: false,
          osPermissionGranted: false,
          needsSystemSettings: true,
          isLoading: false,
        );
      } else {
        // denied (sekali ditolak, tapi masih bisa diminta lagi).
        await _storage.write(key: _kNotifEnabledKey, value: 'false');
        state = const NotificationSettingsState(
          enabled: false,
          osPermissionGranted: false,
          isLoading: false,
        );
      }
    } else {
      await _storage.write(key: _kNotifEnabledKey, value: 'false');
      state = state.copyWith(
        enabled: false,
        isLoading: false,
        needsSystemSettings: false,
      );
    }
  }

  /// Buka pengaturan aplikasi di OS.
  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  /// Re-cek permission, biasanya dipanggil saat user balik dari settings.
  Future<void> refresh() => _load();
}

final notificationSettingsProvider = StateNotifierProvider<
    NotificationSettingsNotifier, NotificationSettingsState>((ref) {
  return NotificationSettingsNotifier();
});
