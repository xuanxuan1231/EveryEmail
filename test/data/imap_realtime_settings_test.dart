import 'package:everyemail/data/settings/imap_realtime_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('IMAP 实时设置默认启用 IDLE 且轮询间隔为 30 秒', () async {
    final config = await ImapRealtimeSettings.readConfigForAccount('acc-1');

    expect(config.mode, ImapRealtimeMode.idle);
    expect(config.idleEnabled, isTrue);
    expect(config.pollingInterval, const Duration(seconds: 30));
  });

  test('IMAP 实时设置按账户保存模式和轮询间隔', () async {
    const config = ImapRealtimeConfig(
      mode: ImapRealtimeMode.polling,
      pollingInterval: Duration(minutes: 5),
    );

    await ImapRealtimeSettings.writeConfigForAccount('acc-1', config);

    expect(await ImapRealtimeSettings.readConfigForAccount('acc-1'), config);
    expect(
      await ImapRealtimeSettings.readConfigForAccount('acc-2'),
      ImapRealtimeConfig.defaults,
    );
  });

  test('轮询间隔会限制在支持范围内，clear 只清理指定账户', () async {
    await ImapRealtimeSettings.writeConfigForAccount(
      'acc-1',
      const ImapRealtimeConfig(
        mode: ImapRealtimeMode.polling,
        pollingInterval: Duration(seconds: 1),
      ),
    );
    await ImapRealtimeSettings.writeConfigForAccount(
      'acc-10',
      const ImapRealtimeConfig(
        mode: ImapRealtimeMode.polling,
        pollingInterval: Duration(minutes: 20),
      ),
    );

    expect(
      (await ImapRealtimeSettings.readConfigForAccount(
        'acc-1',
      )).pollingInterval,
      const Duration(seconds: 30),
    );
    expect(
      (await ImapRealtimeSettings.readConfigForAccount(
        'acc-10',
      )).pollingInterval,
      const Duration(minutes: 15),
    );

    await ImapRealtimeSettings.clearForAccount('acc-1');

    expect(
      await ImapRealtimeSettings.readConfigForAccount('acc-1'),
      ImapRealtimeConfig.defaults,
    );
    expect(
      (await ImapRealtimeSettings.readConfigForAccount('acc-10')).mode,
      ImapRealtimeMode.polling,
    );
  });
}
