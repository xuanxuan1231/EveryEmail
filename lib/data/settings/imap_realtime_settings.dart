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
/// 默认 [ImapRealtimeMode.idle]；用户可在设置页切到 [ImapRealtimeMode.polling]。
class ImapRealtimeSettings {
  const ImapRealtimeSettings._();

  static const String _key = 'imap.realtime.mode';

  static ImapRealtimeMode _parse(String? raw) {
    return raw == 'polling' ? ImapRealtimeMode.polling : ImapRealtimeMode.idle;
  }

  static String _encode(ImapRealtimeMode mode) {
    return mode == ImapRealtimeMode.polling ? 'polling' : 'idle';
  }

  static Future<ImapRealtimeMode> read() async {
    final prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(_key));
  }

  static Future<void> write(ImapRealtimeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(mode));
  }
}
