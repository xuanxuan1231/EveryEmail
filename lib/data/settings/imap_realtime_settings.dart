import 'package:shared_preferences/shared_preferences.dart';

/// IMAP 实时同步方式。
enum ImapRealtimeMode {
  /// IMAP IDLE 长连接：新邮件/标志变更近实时（默认，服务端支持时）。
  idle,

  /// 前台自适应轮询（复用 RealtimeSyncService）：无长连接，省心但有延迟。
  polling,
}

class ImapRealtimeConfig {
  const ImapRealtimeConfig({required this.mode, required this.pollingInterval});

  static const defaults = ImapRealtimeConfig(
    mode: ImapRealtimeMode.idle,
    pollingInterval: Duration(seconds: 30),
  );

  final ImapRealtimeMode mode;
  final Duration pollingInterval;

  bool get idleEnabled => mode == ImapRealtimeMode.idle;

  ImapRealtimeConfig copyWith({
    ImapRealtimeMode? mode,
    Duration? pollingInterval,
  }) {
    return ImapRealtimeConfig(
      mode: mode ?? this.mode,
      pollingInterval: pollingInterval ?? this.pollingInterval,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ImapRealtimeConfig &&
            mode == other.mode &&
            pollingInterval == other.pollingInterval;
  }

  @override
  int get hashCode => Object.hash(mode, pollingInterval);
}

/// IMAP 实时方式的持久化设置（SharedPreferences，与 WebhookManager 一致的存储方式）。
///
/// 默认 [ImapRealtimeMode.idle]。保留全局读写用于现有同步协调器，同时支持按账户
/// 覆盖，后续设置页可把长连接控制下放到单个 IMAP 账户。
class ImapRealtimeSettings {
  const ImapRealtimeSettings._();

  static const List<Duration> pollingIntervalChoices = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
  ];

  static const String _globalKey = 'imap.realtime.mode';
  static const String _globalPollingIntervalKey =
      'imap.realtime.pollingIntervalSeconds';
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

  static String _accountPollingIntervalKey(String accountId) {
    return '$_accountKeyPrefix$accountId.pollingIntervalSeconds';
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

  static Future<Duration> readPollingInterval({String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = accountId == null
        ? prefs.getInt(_globalPollingIntervalKey)
        : prefs.getInt(_accountPollingIntervalKey(accountId)) ??
              prefs.getInt(_globalPollingIntervalKey);
    return _normalizePollingInterval(
      Duration(
        seconds:
            seconds ?? ImapRealtimeConfig.defaults.pollingInterval.inSeconds,
      ),
    );
  }

  static Future<ImapRealtimeConfig> readConfig({String? accountId}) async {
    return ImapRealtimeConfig(
      mode: await read(accountId: accountId),
      pollingInterval: await readPollingInterval(accountId: accountId),
    );
  }

  static Future<ImapRealtimeMode> readForAccount(String accountId) {
    return read(accountId: accountId);
  }

  static Future<Duration> readPollingIntervalForAccount(String accountId) {
    return readPollingInterval(accountId: accountId);
  }

  static Future<ImapRealtimeConfig> readConfigForAccount(String accountId) {
    return readConfig(accountId: accountId);
  }

  static Future<void> write(ImapRealtimeMode mode, {String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      accountId == null ? _globalKey : _accountKey(accountId),
      _encode(mode),
    );
  }

  static Future<void> writePollingInterval(
    Duration interval, {
    String? accountId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      accountId == null
          ? _globalPollingIntervalKey
          : _accountPollingIntervalKey(accountId),
      _normalizePollingInterval(interval).inSeconds,
    );
  }

  static Future<void> writeConfig(
    ImapRealtimeConfig config, {
    String? accountId,
  }) async {
    await write(config.mode, accountId: accountId);
    await writePollingInterval(config.pollingInterval, accountId: accountId);
  }

  static Future<void> writeForAccount(String accountId, ImapRealtimeMode mode) {
    return write(mode, accountId: accountId);
  }

  static Future<void> writePollingIntervalForAccount(
    String accountId,
    Duration interval,
  ) {
    return writePollingInterval(interval, accountId: accountId);
  }

  static Future<void> writeConfigForAccount(
    String accountId,
    ImapRealtimeConfig config,
  ) {
    return writeConfig(config, accountId: accountId);
  }

  static Future<void> clearForAccount(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountKey(accountId));
    await prefs.remove(_accountPollingIntervalKey(accountId));
  }

  static Duration _normalizePollingInterval(Duration interval) {
    final min = pollingIntervalChoices.first;
    final max = pollingIntervalChoices.last;
    if (interval < min) return min;
    if (interval > max) return max;
    return interval;
  }
}
