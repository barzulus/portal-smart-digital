import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/storage_keys.dart';

/// Provider for SecureStorageService
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Wrapper around flutter_secure_storage for JWT and user data persistence
class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Token Management ──

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: StorageKeys.accessToken, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: StorageKeys.accessToken);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: StorageKeys.refreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: StorageKeys.refreshToken);
  }

  Future<void> deleteTokens() async {
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
  }

  // ── User Data ──

  Future<void> saveUserRole(String role) async {
    await _storage.write(key: StorageKeys.userRole, value: role);
  }

  Future<String?> getUserRole() async {
    return await _storage.read(key: StorageKeys.userRole);
  }

  Future<void> saveUserId(String id) async {
    await _storage.write(key: StorageKeys.userId, value: id);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: StorageKeys.userId);
  }

  Future<void> saveUserEmail(String email) async {
    await _storage.write(key: StorageKeys.userEmail, value: email);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: StorageKeys.userEmail);
  }

  Future<void> saveUserName(String name) async {
    await _storage.write(key: StorageKeys.userName, value: name);
  }

  Future<String?> getUserName() async {
    return await _storage.read(key: StorageKeys.userName);
  }

  // ── School ID ──

  Future<void> saveIdSekolah(String id) async {
    await _storage.write(key: StorageKeys.idSekolah, value: id);
  }

  Future<String?> getIdSekolah() async {
    return await _storage.read(key: StorageKeys.idSekolah);
  }

  // ── Remember Me ──

  Future<void> saveRememberMe(bool value) async {
    await _storage.write(
      key: StorageKeys.rememberMe,
      value: value.toString(),
    );
  }

  Future<bool> getRememberMe() async {
    final value = await _storage.read(key: StorageKeys.rememberMe);
    return value == 'true';
  }

  // ── FCM Token ──

  Future<void> saveFcmToken(String token) async {
    await _storage.write(key: StorageKeys.fcmToken, value: token);
  }

  Future<String?> getFcmToken() async {
    return await _storage.read(key: StorageKeys.fcmToken);
  }

  // ── Last Route (untuk restore state saat app restart) ──

  Future<void> saveLastRoute(String route) async {
    await _storage.write(key: StorageKeys.lastRoute, value: route);
  }

  Future<String?> getLastRoute() async {
    return await _storage.read(key: StorageKeys.lastRoute);
  }

  // ── Clear All ──

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Clear session data but keep remember-me preferences (email + flag).
  ///
  /// Penting: `lastRoute` dan `userRole` JUGA dihapus supaya saat user
  /// lain login (atau user yang sama dengan role berbeda), tidak ada
  /// kebocoran route lintas-sesi.
  Future<void> clearSession() async {
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
    await _storage.delete(key: StorageKeys.userId);
    await _storage.delete(key: StorageKeys.userName);
    await _storage.delete(key: StorageKeys.userRole);
    await _storage.delete(key: StorageKeys.idSekolah);
    await _storage.delete(key: StorageKeys.lastRoute);
  }
}
