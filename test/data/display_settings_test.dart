import 'package:everyemail/data/settings/display_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('显示设置默认值可直接用于当前界面', () async {
    final settings = await DisplaySettingsStore.read();

    expect(settings, DisplaySettings.defaults);
  });

  test('显示设置会过滤无效预览行数', () async {
    SharedPreferences.setMockInitialValues({
      'display.previewLines': 9,
      'display.colorMode': 'unknown',
      'display.timeFormat': 'unknown',
    });

    final settings = await DisplaySettingsStore.read();

    expect(settings.previewLines, 3);
    expect(settings.colorMode, AppColorMode.system);
    expect(settings.timeFormat, MailListTimeFormat.smart);
  });

  test('显示设置会保存并读回用户选择', () async {
    const settings = DisplaySettings(
      colorMode: AppColorMode.dark,
      previewLines: 2,
      timeFormat: MailListTimeFormat.twentyFourHour,
      showSenderAvatar: false,
      showAccountLabels: false,
      showAttachmentIcon: false,
      showUnreadIndicator: false,
      showStarButton: false,
      prefetchBodies: false,
    );

    await DisplaySettingsStore.write(settings);

    expect(await DisplaySettingsStore.read(), settings);
  });
}
