import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Custom storage untuk Supabase PKCE flow.
/// Menyimpan token JWT di Keychain (iOS) / EncryptedSharedPreferences (Android)
/// — bukan SharedPreferences biasa yang tidak terenkripsi.

class SecureStorageService extends GotrueAsyncStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _prefix = 'whimsify_';

  // Ambil value tersimpan berdasarkan key (return null kalau gagal/tidak ada)
  @override
  Future<String?> getItem({required String key}) async {
    try {
      return await _storage.read(key: '$_prefix$key');
    } catch (e) {
      return null;
    }
  }

  // Simpan value baru ke secure storage
  @override
  Future<void> setItem({required String key, required String value}) async {
    try {
      await _storage.write(key: '$_prefix$key', value: value);
    } catch (e) {
      // Gagal tulis tidak boleh crash app
    }
  }

  // Hapus satu item berdasarkan key
  @override
  Future<void> removeItem({required String key}) async {
    try {
      await _storage.delete(key: '$_prefix$key');
    } catch (e) {
      // Tetap lanjut meski gagal hapus
    }
  }

  /// Hapus semua token Whimsify dari secure storage saat logout
  static Future<void> clearAll() async {
    try {
      final allKeys = await _storage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith(_prefix)) {
          await _storage.delete(key: key);
        }
      }
    } catch (e) {
      // ignore
    }
  }
}