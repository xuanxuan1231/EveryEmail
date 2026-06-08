import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/enums/message_enums.dart';

const Object _unset = Object();

/// 每个账户头像的来源。
enum AccountAvatarMode { text, icon, image }

/// 每个账户的文件夹同步范围。
enum AccountFolderSyncScope { inboxOnly, standard, subscribed, all }

/// 每个邮箱账户独立的偏好设置。
class AccountSettings {
  const AccountSettings({
    required this.avatarMode,
    required this.avatarText,
    required this.avatarIconId,
    required this.avatarImagePath,
    required this.receiveEnabled,
    required this.sendEnabled,
    required this.realtimeSyncEnabled,
    required this.folderSyncScope,
    required this.syncSpamAndTrash,
    required this.notificationsEnabled,
    required this.notificationSound,
    required this.notificationVibration,
    required this.includeInSearch,
    required this.searchSpamAndTrash,
  });

  static const AccountSettings defaults = AccountSettings(
    avatarMode: AccountAvatarMode.text,
    avatarText: null,
    avatarIconId: null,
    avatarImagePath: null,
    receiveEnabled: true,
    sendEnabled: true,
    realtimeSyncEnabled: true,
    folderSyncScope: AccountFolderSyncScope.standard,
    syncSpamAndTrash: false,
    notificationsEnabled: true,
    notificationSound: true,
    notificationVibration: true,
    includeInSearch: true,
    searchSpamAndTrash: false,
  );

  final AccountAvatarMode avatarMode;
  final String? avatarText;
  final String? avatarIconId;
  final String? avatarImagePath;
  final bool receiveEnabled;
  final bool sendEnabled;
  final bool realtimeSyncEnabled;
  final AccountFolderSyncScope folderSyncScope;
  final bool syncSpamAndTrash;
  final bool notificationsEnabled;
  final bool notificationSound;
  final bool notificationVibration;
  final bool includeInSearch;
  final bool searchSpamAndTrash;

  AccountSettings copyWith({
    AccountAvatarMode? avatarMode,
    Object? avatarText = _unset,
    Object? avatarIconId = _unset,
    Object? avatarImagePath = _unset,
    bool? receiveEnabled,
    bool? sendEnabled,
    bool? realtimeSyncEnabled,
    AccountFolderSyncScope? folderSyncScope,
    bool? syncSpamAndTrash,
    bool? notificationsEnabled,
    bool? notificationSound,
    bool? notificationVibration,
    bool? includeInSearch,
    bool? searchSpamAndTrash,
  }) {
    return AccountSettings(
      avatarMode: avatarMode ?? this.avatarMode,
      avatarText: identical(avatarText, _unset)
          ? this.avatarText
          : avatarText as String?,
      avatarIconId: identical(avatarIconId, _unset)
          ? this.avatarIconId
          : avatarIconId as String?,
      avatarImagePath: identical(avatarImagePath, _unset)
          ? this.avatarImagePath
          : avatarImagePath as String?,
      receiveEnabled: receiveEnabled ?? this.receiveEnabled,
      sendEnabled: sendEnabled ?? this.sendEnabled,
      realtimeSyncEnabled: realtimeSyncEnabled ?? this.realtimeSyncEnabled,
      folderSyncScope: folderSyncScope ?? this.folderSyncScope,
      syncSpamAndTrash: syncSpamAndTrash ?? this.syncSpamAndTrash,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationSound: notificationSound ?? this.notificationSound,
      notificationVibration:
          notificationVibration ?? this.notificationVibration,
      includeInSearch: includeInSearch ?? this.includeInSearch,
      searchSpamAndTrash: searchSpamAndTrash ?? this.searchSpamAndTrash,
    );
  }

  bool canSearchFolder(FolderType folderType) {
    if (!includeInSearch) return false;
    if (searchSpamAndTrash) return true;
    return folderType != FolderType.spam && folderType != FolderType.trash;
  }

  bool canSyncFolder(FolderType folderType, {required bool isSubscribed}) {
    if (!receiveEnabled) return false;
    if (!syncSpamAndTrash &&
        (folderType == FolderType.spam || folderType == FolderType.trash)) {
      return false;
    }

    return switch (folderSyncScope) {
      AccountFolderSyncScope.inboxOnly => folderType == FolderType.inbox,
      AccountFolderSyncScope.standard =>
        folderType == FolderType.inbox ||
            folderType == FolderType.sent ||
            folderType == FolderType.drafts,
      AccountFolderSyncScope.subscribed => isSubscribed,
      AccountFolderSyncScope.all => true,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AccountSettings &&
            avatarMode == other.avatarMode &&
            avatarText == other.avatarText &&
            avatarIconId == other.avatarIconId &&
            avatarImagePath == other.avatarImagePath &&
            receiveEnabled == other.receiveEnabled &&
            sendEnabled == other.sendEnabled &&
            realtimeSyncEnabled == other.realtimeSyncEnabled &&
            folderSyncScope == other.folderSyncScope &&
            syncSpamAndTrash == other.syncSpamAndTrash &&
            notificationsEnabled == other.notificationsEnabled &&
            notificationSound == other.notificationSound &&
            notificationVibration == other.notificationVibration &&
            includeInSearch == other.includeInSearch &&
            searchSpamAndTrash == other.searchSpamAndTrash;
  }

  @override
  int get hashCode => Object.hash(
    avatarText,
    avatarMode,
    avatarIconId,
    avatarImagePath,
    receiveEnabled,
    sendEnabled,
    realtimeSyncEnabled,
    folderSyncScope,
    syncSpamAndTrash,
    notificationsEnabled,
    notificationSound,
    notificationVibration,
    includeInSearch,
    searchSpamAndTrash,
  );
}

/// 账户级偏好持久化。
class AccountSettingsStore {
  const AccountSettingsStore._();

  static String _key(String accountId, String name) =>
      'account.$accountId.$name';

  static Future<AccountSettings> read(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final avatarText = _normalizeAvatarText(
      prefs.getString(_key(accountId, 'avatarText')),
    );
    final avatarIconId = _normalizeOptional(
      prefs.getString(_key(accountId, 'avatarIconId')),
    );
    final avatarImagePath = _normalizeOptional(
      prefs.getString(_key(accountId, 'avatarImagePath')),
    );
    final avatarMode = _parseAvatarMode(
      prefs.getString(_key(accountId, 'avatarMode')),
      avatarIconId: avatarIconId,
      avatarImagePath: avatarImagePath,
    );

    return AccountSettings(
      avatarMode: avatarMode,
      avatarText: avatarText,
      avatarIconId: avatarIconId,
      avatarImagePath: avatarImagePath,
      receiveEnabled:
          prefs.getBool(_key(accountId, 'receiveEnabled')) ??
          AccountSettings.defaults.receiveEnabled,
      sendEnabled:
          prefs.getBool(_key(accountId, 'sendEnabled')) ??
          AccountSettings.defaults.sendEnabled,
      realtimeSyncEnabled:
          prefs.getBool(_key(accountId, 'realtimeSyncEnabled')) ??
          AccountSettings.defaults.realtimeSyncEnabled,
      folderSyncScope: _parseFolderSyncScope(
        prefs.getString(_key(accountId, 'folderSyncScope')),
      ),
      syncSpamAndTrash:
          prefs.getBool(_key(accountId, 'syncSpamAndTrash')) ??
          AccountSettings.defaults.syncSpamAndTrash,
      notificationsEnabled:
          prefs.getBool(_key(accountId, 'notificationsEnabled')) ??
          AccountSettings.defaults.notificationsEnabled,
      notificationSound:
          prefs.getBool(_key(accountId, 'notificationSound')) ??
          AccountSettings.defaults.notificationSound,
      notificationVibration:
          prefs.getBool(_key(accountId, 'notificationVibration')) ??
          AccountSettings.defaults.notificationVibration,
      includeInSearch:
          prefs.getBool(_key(accountId, 'includeInSearch')) ??
          AccountSettings.defaults.includeInSearch,
      searchSpamAndTrash:
          prefs.getBool(_key(accountId, 'searchSpamAndTrash')) ??
          AccountSettings.defaults.searchSpamAndTrash,
    );
  }

  static Future<Map<String, AccountSettings>> readMany(
    Iterable<String> accountIds,
  ) async {
    final result = <String, AccountSettings>{};
    for (final accountId in accountIds.toSet()) {
      result[accountId] = await read(accountId);
    }
    return result;
  }

  static Future<void> write(String accountId, AccountSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final avatarText = _normalizeAvatarText(settings.avatarText);
    final avatarIconId = _normalizeOptional(settings.avatarIconId);
    final avatarImagePath = _normalizeOptional(settings.avatarImagePath);
    await prefs.setString(
      _key(accountId, 'avatarMode'),
      _encodeAvatarMode(settings.avatarMode),
    );
    if (avatarText == null) {
      await prefs.remove(_key(accountId, 'avatarText'));
    } else {
      await prefs.setString(_key(accountId, 'avatarText'), avatarText);
    }
    if (avatarIconId == null) {
      await prefs.remove(_key(accountId, 'avatarIconId'));
    } else {
      await prefs.setString(_key(accountId, 'avatarIconId'), avatarIconId);
    }
    if (avatarImagePath == null) {
      await prefs.remove(_key(accountId, 'avatarImagePath'));
    } else {
      await prefs.setString(
        _key(accountId, 'avatarImagePath'),
        avatarImagePath,
      );
    }
    await prefs.setBool(
      _key(accountId, 'receiveEnabled'),
      settings.receiveEnabled,
    );
    await prefs.setBool(_key(accountId, 'sendEnabled'), settings.sendEnabled);
    await prefs.setBool(
      _key(accountId, 'realtimeSyncEnabled'),
      settings.realtimeSyncEnabled,
    );
    await prefs.setString(
      _key(accountId, 'folderSyncScope'),
      _encodeFolderSyncScope(settings.folderSyncScope),
    );
    await prefs.setBool(
      _key(accountId, 'syncSpamAndTrash'),
      settings.syncSpamAndTrash,
    );
    await prefs.setBool(
      _key(accountId, 'notificationsEnabled'),
      settings.notificationsEnabled,
    );
    await prefs.setBool(
      _key(accountId, 'notificationSound'),
      settings.notificationSound,
    );
    await prefs.setBool(
      _key(accountId, 'notificationVibration'),
      settings.notificationVibration,
    );
    await prefs.setBool(
      _key(accountId, 'includeInSearch'),
      settings.includeInSearch,
    );
    await prefs.setBool(
      _key(accountId, 'searchSpamAndTrash'),
      settings.searchSpamAndTrash,
    );
  }

  static Future<void> reset(String accountId) {
    return write(accountId, AccountSettings.defaults);
  }

  /// 删除某账户的全部偏好键（账户移除时调用）。
  ///
  /// 与 [reset] 不同：[reset] 写回默认值（键仍在），这里直接移除所有
  /// `account.<id>.*` 键，避免账户删除后遗留孤儿条目。
  static Future<void> clear(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'account.$accountId.';
    final keys = prefs.getKeys().where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static String? _normalizeAvatarText(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return String.fromCharCodes(trimmed.runes.take(2)).toUpperCase();
  }

  static String? _normalizeOptional(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static AccountAvatarMode _parseAvatarMode(
    String? raw, {
    required String? avatarIconId,
    required String? avatarImagePath,
  }) {
    return switch (raw) {
      'icon' when avatarIconId != null => AccountAvatarMode.icon,
      'image' when avatarImagePath != null => AccountAvatarMode.image,
      _ => AccountAvatarMode.text,
    };
  }

  static String _encodeAvatarMode(AccountAvatarMode mode) {
    return switch (mode) {
      AccountAvatarMode.text => 'text',
      AccountAvatarMode.icon => 'icon',
      AccountAvatarMode.image => 'image',
    };
  }

  static AccountFolderSyncScope _parseFolderSyncScope(String? raw) {
    return switch (raw) {
      'inboxOnly' => AccountFolderSyncScope.inboxOnly,
      'subscribed' => AccountFolderSyncScope.subscribed,
      'all' => AccountFolderSyncScope.all,
      _ => AccountFolderSyncScope.standard,
    };
  }

  static String _encodeFolderSyncScope(AccountFolderSyncScope scope) {
    return switch (scope) {
      AccountFolderSyncScope.inboxOnly => 'inboxOnly',
      AccountFolderSyncScope.standard => 'standard',
      AccountFolderSyncScope.subscribed => 'subscribed',
      AccountFolderSyncScope.all => 'all',
    };
  }
}
