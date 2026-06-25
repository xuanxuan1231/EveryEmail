import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 密钥安全存储封装（Android Keystore 支持）。
///
/// 仅存放敏感凭据：OAuth refresh token、IMAP/SMTP 密码。
/// 账户元数据存 Drift，通过 `secretRef`（= 这里的 key）间接引用。
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // v10+ 默认使用自定义密码（基于 Android Keystore），
            // 旧的 EncryptedSharedPreferences 已弃用，无需再配置。
            aOptions: AndroidOptions(),
          );

  final FlutterSecureStorage _storage;

  static final Random _secureRandom = Random.secure();

  static String _refreshKey(String secretRef) => 'refresh_token::$secretRef';
  static String _passwordKey(String secretRef) => 'password::$secretRef';
  static String _pushSecretKey(String accountId) =>
      'push_account_secret::$accountId';

  Future<void> writeRefreshToken(String secretRef, String token) {
    return _storage.write(key: _refreshKey(secretRef), value: token);
  }

  Future<String?> readRefreshToken(String secretRef) {
    return _storage.read(key: _refreshKey(secretRef));
  }

  Future<void> writePassword(String secretRef, String password) {
    return _storage.write(key: _passwordKey(secretRef), value: password);
  }

  Future<String?> readPassword(String secretRef) {
    return _storage.read(key: _passwordKey(secretRef));
  }

  Future<void> deleteRefreshToken(String secretRef) {
    return _storage.delete(key: _refreshKey(secretRef));
  }

  Future<void> deletePassword(String secretRef) {
    return _storage.delete(key: _passwordKey(secretRef));
  }

  Future<String> readOrCreatePushSecret(String accountId) async {
    final existing = await _storage.read(key: _pushSecretKey(accountId));
    if (existing != null && existing.isNotEmpty) return existing;

    final bytes = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    final secret = base64UrlEncode(bytes).replaceAll('=', '');
    await _storage.write(key: _pushSecretKey(accountId), value: secret);
    return secret;
  }

  Future<void> deletePushSecret(String accountId) {
    return _storage.delete(key: _pushSecretKey(accountId));
  }

  /// 移除账户时清除其全部密钥。
  Future<void> deleteSecrets(String secretRef) async {
    await deleteRefreshToken(secretRef);
    await deletePassword(secretRef);
  }
}
