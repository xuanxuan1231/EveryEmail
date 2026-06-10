// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';

import '../../core/platform/avatar_image_picker.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';
import '../auth/oauth_service.dart';
import '../autoconfig/discovery_service.dart';
import '../local/database/app_database.dart';
import '../local/file_store.dart';
import '../secure/token_store.dart';
import '../settings/account_settings.dart';
import '../webhook/gmail_watch_manager.dart';
import '../webhook/webhook_manager.dart';

/// 账户仓储：编排自动配置发现、OAuth/密码认证、凭据安全存储与 Drift 持久化。
///
/// 是「添加账户向导」的后端入口。
class AccountRepository {
  AccountRepository({
    required AppDatabase db,
    required TokenStore tokenStore,
    required OAuthService oauthService,
    DiscoveryService? discovery,
    WebhookManager? webhookManager,
    GmailWatchManager? gmailWatchManager,
  }) : _db = db,
       _tokenStore = tokenStore,
       _oauth = oauthService,
       _discovery = discovery ?? DiscoveryService(),
       _webhookManager = webhookManager,
       _gmailWatchManager = gmailWatchManager;

  final AppDatabase _db;
  final TokenStore _tokenStore;
  final OAuthService _oauth;
  final DiscoveryService _discovery;

  /// 可选：删除账户时用来拆除 Graph 订阅 + FCM 映射。为空则跳过拆除。
  final WebhookManager? _webhookManager;

  /// 可选：删除账户时用来停掉 Gmail watch + 清 FCM 映射。为空则跳过拆除。
  final GmailWatchManager? _gmailWatchManager;

  /// 监听全部账户。
  Stream<List<Account>> watchAccounts() => _db.accountDao.watchAccounts();

  /// 自动配置：根据邮箱地址发现服务器/类型。
  Future<DiscoveryResult?> discover(String email) => _discovery.discover(email);

  /// 通过 OAuth 添加账户（Gmail / Microsoft）。
  ///
  /// 触发交互式登录，refresh token 入安全存储，账户行入 Drift。
  /// [discovered] 一般来自 [discover]；Microsoft 可为最简结果。
  Future<String> addOAuthAccount({
    required String email,
    required String displayName,
    required AccountType type,
    required DiscoveryResult discovered,
  }) async {
    assert(
      type == AccountType.gmailOAuth || type == AccountType.microsoftGraph,
    );

    final tokens = await _oauth.authorize(type, expectedEmail: email);
    final refresh = tokens.refreshToken;
    if (refresh == null) {
      throw StateError(
        'OAuth 未返回 refresh token（请确认已申请 offline_access / access_type=offline）',
      );
    }

    final accountId = generateId();
    final secretRef = accountId; // 一对一，直接复用 accountId 作为密钥引用。
    final sortIndex = await _nextSortIndex();
    await _tokenStore.writeRefreshToken(secretRef, refresh);

    await _db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: accountId,
        email: email,
        displayName: displayName,
        accountType: type,
        authType: AuthType.oauth,
        secretRef: Value(secretRef),
        imapHost: Value(discovered.imap?.host),
        imapPort: Value(discovered.imap?.port),
        imapSocketType: Value(discovered.imap?.socketType),
        smtpHost: Value(discovered.smtp?.host),
        smtpPort: Value(discovered.smtp?.port),
        smtpSocketType: Value(discovered.smtp?.socketType),
        loginName: Value(email),
        sortIndex: Value(sortIndex),
      ),
    );
    return accountId;
  }

  /// 通过密码/应用专用密码添加通用 IMAP 账户。
  Future<String> addPasswordAccount({
    required String email,
    required String displayName,
    required String password,
    required ServerConfig imap,
    required ServerConfig smtp,
    String? loginName,
  }) async {
    final accountId = generateId();
    final secretRef = accountId;
    final sortIndex = await _nextSortIndex();
    await _tokenStore.writePassword(secretRef, password);

    await _db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: accountId,
        email: email,
        displayName: displayName,
        accountType: AccountType.genericImap,
        authType: AuthType.password,
        secretRef: Value(secretRef),
        imapHost: Value(imap.host),
        imapPort: Value(imap.port),
        imapSocketType: Value(imap.socketType),
        smtpHost: Value(smtp.host),
        smtpPort: Value(smtp.port),
        smtpSocketType: Value(smtp.socketType),
        loginName: Value(loginName ?? email),
        sortIndex: Value(sortIndex),
      ),
    );
    return accountId;
  }

  /// 按 UI 传入的账户 ID 顺序重写排序序号。
  Future<void> reorderAccounts(List<String> orderedAccountIds) {
    return _db.accountDao.updateSortOrder(orderedAccountIds);
  }

  /// 更新账户在本地 UI 中展示的资料。
  Future<void> updateAccountProfile(
    String accountId, {
    String? displayName,
    Value<int?> colorValue = const Value.absent(),
  }) {
    final normalizedName = displayName?.trim();
    if (displayName != null &&
        (normalizedName == null || normalizedName.isEmpty)) {
      throw ArgumentError.value(displayName, 'displayName', '账户名称不能为空');
    }

    return _db.accountDao.updateProfile(
      accountId,
      displayName: normalizedName,
      colorValue: colorValue,
    );
  }

  /// 移除账户：拆推送订阅 + 清安全存储 + 级联删除 Drift 行 + 清理本地文件/头像/偏好。
  ///
  /// 删除账户行会随外键级联清掉其文件夹/邮件/正文/同步游标/发件箱。之后的本地文件、
  /// 头像图片、SharedPreferences 偏好清理均为 best-effort：各自吞掉异常、互不影响，
  /// 也不回滚已经完成的账户删除。
  Future<void> removeAccount(String accountId) async {
    final account = await _db.accountDao.getAccount(accountId);

    // 先拆推送：删订阅需要 access token，必须在凭据清除前完成。失败不阻塞删除。
    if (account != null && _webhookManager != null) {
      try {
        await _webhookManager.tearDownForAccount(toConfig(account));
      } catch (e) {
        // 拆除失败（离线/令牌失效）不应卡住账户删除，订阅最终会因 3 天 TTL 过期。
      }
    }

    // Gmail watch 拆除：停 watch（Worker 清 KV + 加密 refresh token）+ 注销 FCM。
    if (account != null && _gmailWatchManager != null) {
      try {
        await _gmailWatchManager.tearDownForAccount(toConfig(account));
      } catch (e) {
        // 同上：失败不阻塞删除；Worker Cron 命中 invalid_grant 也会兜底清理。
      }
    }

    if (account?.secretRef != null) {
      await _tokenStore.deleteSecrets(account!.secretRef!);
    }
    await _db.accountDao.deleteAccount(accountId);

    // 本地痕迹清理：库行已删，下面任一步失败都不影响账户已被移除的结果。
    try {
      final fileStore = await FileStore.init();
      await fileStore.deleteAccountFiles(accountId);
    } catch (e) {
      // 附件文件删除失败（IO/权限）忽略：残留字节已无任何库行引用。
    }
    try {
      await AvatarImagePicker.deleteAccountAvatarImages(accountId);
    } catch (e) {
      // 头像图片删除失败忽略。
    }
    try {
      await AccountSettingsStore.clear(accountId);
    } catch (e) {
      // 偏好清理失败忽略：键按 accountId 命名，不会与未来新账户冲突。
    }
  }

  /// 把 Drift 行映射为领域模型 [AccountConfig]。
  AccountConfig toConfig(Account row) {
    return AccountConfig(
      id: row.id,
      email: row.email,
      displayName: row.displayName,
      type: row.accountType,
      authType: row.authType,
      secretRef: row.secretRef,
      loginName: row.loginName,
      colorValue: row.colorValue,
      imap: row.imapHost == null
          ? null
          : ServerConfig(
              host: row.imapHost!,
              port: row.imapPort ?? 993,
              socketType: row.imapSocketType ?? SocketType.ssl,
            ),
      smtp: row.smtpHost == null
          ? null
          : ServerConfig(
              host: row.smtpHost!,
              port: row.smtpPort ?? 465,
              socketType: row.smtpSocketType ?? SocketType.ssl,
            ),
    );
  }

  Future<int> _nextSortIndex() async {
    final rows = await _db.accountDao.getAccounts();
    var next = 0;
    for (final row in rows) {
      if (row.sortIndex >= next) next = row.sortIndex + 1;
    }
    return next;
  }
}
