import 'package:everyemail/data/settings/account_settings.dart';
import 'package:everyemail/domain/enums/message_enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('账户设置默认值可直接使用', () async {
    final settings = await AccountSettingsStore.read('acc-1');

    expect(settings, AccountSettings.defaults);
    expect(settings.canSearchFolder(FolderType.inbox), isTrue);
    expect(settings.canSearchFolder(FolderType.spam), isFalse);
  });

  test('账户设置会保存并读回用户选择', () async {
    const settings = AccountSettings(
      avatarMode: AccountAvatarMode.icon,
      avatarText: 'WK',
      avatarIconId: 'work',
      avatarImagePath: null,
      receiveEnabled: false,
      sendEnabled: true,
      realtimeSyncEnabled: false,
      draftSyncAutoRetry: false,
      draftSyncRetryInterval: Duration(minutes: 10),
      folderSyncScope: AccountFolderSyncScope.all,
      syncSpamAndTrash: true,
      notificationsEnabled: false,
      notificationSound: false,
      notificationVibration: false,
      includeInSearch: true,
      searchSpamAndTrash: true,
    );

    await AccountSettingsStore.write('acc-1', settings);

    expect(await AccountSettingsStore.read('acc-1'), settings);
  });

  test('账户头像文字会归一化为空或最多两个字符', () async {
    await AccountSettingsStore.write(
      'acc-1',
      AccountSettings.defaults.copyWith(
        avatarMode: AccountAvatarMode.text,
        avatarText: ' work ',
      ),
    );
    expect((await AccountSettingsStore.read('acc-1')).avatarText, 'WO');

    await AccountSettingsStore.write(
      'acc-1',
      AccountSettings.defaults.copyWith(avatarText: '   '),
    );
    expect((await AccountSettingsStore.read('acc-1')).avatarText, isNull);
  });

  test('账户头像图片模式需要有效图片路径', () async {
    await AccountSettingsStore.write(
      'acc-1',
      AccountSettings.defaults.copyWith(
        avatarMode: AccountAvatarMode.image,
        avatarImagePath: '/tmp/avatar.png',
      ),
    );

    var settings = await AccountSettingsStore.read('acc-1');
    expect(settings.avatarMode, AccountAvatarMode.image);
    expect(settings.avatarImagePath, '/tmp/avatar.png');

    await AccountSettingsStore.write(
      'acc-1',
      AccountSettings.defaults.copyWith(
        avatarMode: AccountAvatarMode.image,
        avatarImagePath: ' ',
      ),
    );

    settings = await AccountSettingsStore.read('acc-1');
    expect(settings.avatarMode, AccountAvatarMode.text);
    expect(settings.avatarImagePath, isNull);
  });

  test('clear 移除目标账户的全部偏好且不误伤前缀相近的账户', () async {
    const custom = AccountSettings(
      avatarMode: AccountAvatarMode.icon,
      avatarText: 'WK',
      avatarIconId: 'work',
      avatarImagePath: null,
      receiveEnabled: false,
      sendEnabled: false,
      realtimeSyncEnabled: false,
      draftSyncAutoRetry: false,
      draftSyncRetryInterval: Duration(minutes: 15),
      folderSyncScope: AccountFolderSyncScope.all,
      syncSpamAndTrash: true,
      notificationsEnabled: false,
      notificationSound: false,
      notificationVibration: false,
      includeInSearch: false,
      searchSpamAndTrash: true,
    );

    await AccountSettingsStore.write('acc-1', custom);
    // acc-10 的键前缀与 acc-1 相近，清理 acc-1 不应误删（前缀结尾的点号是关键）。
    await AccountSettingsStore.write('acc-10', custom);

    await AccountSettingsStore.clear('acc-1');

    // acc-1 的键被删除，读回默认值。
    expect(await AccountSettingsStore.read('acc-1'), AccountSettings.defaults);
    // acc-10 不受影响。
    expect(await AccountSettingsStore.read('acc-10'), custom);
  });
}
