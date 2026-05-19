import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Provider singleton untuk OfflineCacheService.
final offlineCacheServiceProvider = Provider<OfflineCacheService>((ref) {
  return OfflineCacheService();
});

/// Service untuk offline caching menggunakan sqflite.
///
/// Menggantikan Hive — lebih reliable, SQL-based, dan compatible
/// dengan semua versi AGP/Gradle tanpa masalah namespace.
/// Digunakan untuk menyimpan response API secara lokal agar app
/// tetap bisa menampilkan data saat offline.
class OfflineCacheService {
  static Database? _db;

  static const String _tableName = 'cached_responses';

  /// Initialize database. Panggil di main.dart sebelum runApp().
  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/sekolah_app_cache.db';

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            key TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_cached_at ON $_tableName (cached_at)
        ''');
      },
    );
  }

  Database get _database {
    assert(_db != null, 'OfflineCacheService.init() belum dipanggil');
    return _db!;
  }

  // ═══════════════════════════════════════════════════════════════
  // CACHE OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Simpan response API ke cache lokal.
  Future<void> cacheResponse(String key, String data) async {
    await _database.insert(
      _tableName,
      {
        'key': key,
        'data': data,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ambil cached response berdasarkan key.
  Future<String?> getCachedResponse(String key, {Duration? maxAge}) async {
    final results = await _database.query(
      _tableName,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final row = results.first;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int);

    if (maxAge != null) {
      final age = DateTime.now().difference(cachedAt);
      if (age > maxAge) {
        await invalidateCache(key);
        return null;
      }
    }

    return row['data'] as String?;
  }

  /// Hapus cache untuk key tertentu.
  Future<void> invalidateCache(String key) async {
    await _database.delete(_tableName, where: 'key = ?', whereArgs: [key]);
  }

  /// Hapus semua cache (saat logout).
  Future<void> clearAll() async {
    await _database.delete(_tableName);
  }

  /// Hapus cache yang sudah expired.
  Future<void> pruneExpired(Duration maxAge) async {
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
    await _database.delete(_tableName, where: 'cached_at < ?', whereArgs: [cutoff]);
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER: CACHE-FIRST FETCH
  // ═══════════════════════════════════════════════════════════════

  /// Fetch data dengan strategi cache-first:
  /// 1. Coba fetch dari network (via [fetcher])
  /// 2. Kalau berhasil, simpan ke cache dan return
  /// 3. Kalau gagal (offline/error), return dari cache
  /// 4. Kalau cache juga kosong, throw error
  Future<List<dynamic>> fetchWithCache({
    required String cacheKey,
    required Future<List<dynamic>> Function() fetcher,
    Duration maxAge = const Duration(hours: 24),
  }) async {
    try {
      // Try network first
      final data = await fetcher();
      // Cache the result
      await cacheResponse(cacheKey, jsonEncode(data));
      return data;
    } catch (e) {
      // Network failed — try cache
      final cached = await getCachedResponse(cacheKey, maxAge: maxAge);
      if (cached != null) {
        final decoded = jsonDecode(cached);
        if (decoded is List) return decoded;
      }
      // No cache either — rethrow
      rethrow;
    }
  }
}
