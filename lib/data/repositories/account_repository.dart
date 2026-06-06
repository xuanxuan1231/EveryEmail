// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';

import '../../core/utils/id_generator.dart';
import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';
import '../auth/oauth_service.dart';
import '../autoconfig/discovery_service.dart';
import '../local/database/app_database.dart';
import '../secure/token_store.dart';
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
  }) : _db = db,
       _tokenStore = tokenStore,
       _oauth = oauthService,
       _discovery = discovery ?? const DiscoveryService(),
       _webhookManager = webhookManager;

  final AppDatabase _db;
  final TokenStore _tokenStore;
  final OAuthService _oauth;
  final DiscoveryService _discovery;

  /// 可选：删除账户时用来拆除 Graph 订阅 + FCM 映射。为空则跳过拆除。
  final WebhookManager? _webhookManager;

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
      ),
    );
    return accountId;
  }

  /// 移除账户：拆除推送订阅 + 清安全存储 + 级联删除 Drift 行（文件清理由调用方做）。
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

    if (account?.secretRef != null) {
      await _tokenStore.deleteSecrets(account!.secretRef!);
    }
    await _db.accountDao.deleteAccount(accountId);
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
}
