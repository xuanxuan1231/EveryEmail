import 'package:shared_preferences/shared_preferences.dart';

/// IMAP 实时同步方式。
enum ImapRealtimeMode {
  /// IMAP IDLE 长连接：新邮件/标志变更近实时（默认，服务端支持时）。
  idle,

  /// 前台自适应轮询（复用 RealtimeSyncService）：无长连接，省心但有延迟。
  polling,
}

/// IMAP 实时方式的持久化设置（SharedPreferences，与 WebhookManager 一致的存储方式）。
///
/// 默认 [ImapRealtimeMode.idle]。保留全局读写用于现有同步协调器，同时支持按账户
/// 覆盖，后续设置页可把长连接控制下放到单个 IMAP 账户。
class ImapRealtimeSettings {
  const ImapRealtimeSettings._();

  static const String _globalKey = 'imap.realtime.mode';
  static const String _accountKeyPrefix = 'imap.realtime.account.';

  static ImapRealtimeMode _parse(String? raw) {
    return raw == 'polling' ? ImapRealtimeMode.polling : ImapRealtimeMode.idle;
  }

  static String _encode(ImapRealtimeMode mode) {
    return mode == ImapRealtimeMode.polling ? 'polling' : 'idle';
  }

  static String _accountKey(String accountId) {
    return '$_accountKeyPrefix$accountId.mode';
  }

  static Future<ImapRealtimeMode> read({String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (accountId != null) {
      return _parse(
        prefs.getString(_accountKey(accountId)) ?? prefs.getString(_globalKey),
      );
    }
    return _parse(prefs.getString(_globalKey));
  }

  static Future<ImapRealtimeMode> readForAccount(String accountId) {
    return read(accountId: accountId);
  }

  static Future<void> write(ImapRealtimeMode mode, {String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      accountId == null ? _globalKey : _accountKey(accountId),
      _encode(mode),
    );
  }

  static Future<void> writeForAccount(String accountId, ImapRealtimeMode mode) {
    return write(mode, accountId: accountId);
  }

  static Future<void> clearForAccount(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountKey(accountId));
  }
}
