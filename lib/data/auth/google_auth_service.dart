import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';
import '../backends/mail_backend.dart';
import 'oauth_config.dart';

/// 一次 GIS 授权产出的、交给后端兑换 token 的 server auth code（外加账户邮箱）。
class GoogleServerAuth {
  const GoogleServerAuth({required this.serverAuthCode, required this.email});

  /// 一次性授权码：由 Cloudflare Worker 用 Web client（含 secret）兑换
  /// access/refresh token。
  final String serverAuthCode;

  /// 已认证 Google 账户的邮箱（来自 `GoogleSignInAccount.email`，必不为空）。
  final String email;
}

/// 用户在 Google 原生登录/授权中主动取消。
class GoogleSignInCancelled extends MailAuthException {
  const GoogleSignInCancelled() : super('已取消 Google 登录');
}

/// 封装 google_sign_in v7（Android: Credential Manager + Authorization API，
/// iOS: GoogleSignIn SDK），产出给后端兑换 token 的 **server auth code**。
///
/// 这是 Google 推荐的原生方案：账户选择器直接返回一次性 server auth code，由
/// 持有 Web client secret 的后端（本项目的 Cloudflare Worker）兑换 access/
/// refresh token——不再使用自定义 URI scheme 回调。
class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  Future<void>? _initialization;

  /// `initialize` 全局只需成功一次；用 memo 复用同一个 future。
  Future<void> _ensureInitialized() {
    return _initialization ??= _signIn.initialize(
      // iOS 需要 iOS client id；Android 留 null（凭包名 + SHA-1 自动匹配）。
      clientId: _orNull(AppConfig.googleIosClientId),
      // 两端都用 **Web** client id 作 serverClientId——server auth code 即为它签发，
      // 后端也用同一个 Web client 兑换。
      serverClientId: _orNull(AppConfig.googleServerClientId),
    );
  }

  /// 交互式登录并取得 server auth code。
  ///
  /// 流程：登出（强制弹账户选择器 + 重新同意）→ `authenticate` → `authorizeServer`。
  /// [scopes] 默认为 Gmail 所需的全权限 scope；[loginHint] 暂未被 GIS 强制使用，
  /// 保留以兼容调用方传入的期望邮箱。
  Future<GoogleServerAuth> getServerAuthCode({
    List<String> scopes = OAuthProviders.googleScopes,
    String? loginHint,
  }) async {
    if (AppConfig.googleServerClientId.isEmpty) {
      throw const MailAuthException(
        'Google 未配置：缺少 GOOGLE_SERVER_CLIENT_ID（Web 客户端 ID）',
      );
    }

    await _ensureInitialized();

    // 先登出：authorizeServer 只在「首次同意」时可靠地签发 server auth code，
    // 沿用旧会话再次请求可能返回 null。登出后强制重新选择账户并同意。
    try {
      await _signIn.signOut();
    } catch (_) {
      // 无已登录会话时可能抛错，忽略。
    }

    final GoogleSignInAccount account;
    try {
      account = await _signIn.authenticate(scopeHint: scopes);
    } on GoogleSignInException catch (e) {
      throw _mapException(e, '登录');
    }

    final GoogleSignInServerAuthorization? server;
    try {
      server = await account.authorizationClient.authorizeServer(scopes);
    } on GoogleSignInException catch (e) {
      throw _mapException(e, '授权');
    }

    final code = server?.serverAuthCode;
    if (code == null || code.isEmpty) {
      throw const MailAuthException(
        '未能获取 Google server auth code，请重试。'
        '若反复出现，请到 Google 账户「第三方访问」中移除本应用授权后重新登录。',
      );
    }
    return GoogleServerAuth(serverAuthCode: code, email: account.email);
  }

  MailAuthException _mapException(GoogleSignInException e, String stage) {
    if (e.code == GoogleSignInExceptionCode.canceled) {
      return const GoogleSignInCancelled();
    }
    final detail = e.description?.trim();
    return MailAuthException(
      'Google $stage失败（${e.code.name}）${detail == null || detail.isEmpty ? '' : ': $detail'}',
      cause: e,
    );
  }

  static String? _orNull(String value) => value.isEmpty ? null : value;
}
