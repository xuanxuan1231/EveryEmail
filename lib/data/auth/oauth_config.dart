import 'package:flutter_appauth/flutter_appauth.dart';

import '../../core/config/app_config.dart';
import '../../domain/enums/account_enums.dart';

/// 单个 OAuth 提供商的配置（端点、scope、client id、重定向 URI）。
class OAuthProviderConfig {
  const OAuthProviderConfig({
    required this.clientId,
    required this.redirectUrl,
    required this.scopes,
    required this.serviceConfiguration,
    this.additionalParameters,
  });

  final String clientId;
  final String redirectUrl;
  final List<String> scopes;
  final AuthorizationServiceConfiguration serviceConfiguration;
  final Map<String, String>? additionalParameters;
}

/// 内置的 Google / Microsoft OAuth 提供商配置。
class OAuthProviders {
  const OAuthProviders._();

  /// Gmail 所需的 OAuth scope。IMAP/SMTP XOAUTH2 需要全权限 `https://mail.google.com/`。
  /// 账户邮箱直接取自 GIS 登录返回的 `GoogleSignInAccount.email`，无需额外的
  /// `openid/email/profile` 授权 scope。
  static const List<String> googleScopes = ['https://mail.google.com/'];

  /// Microsoft：邮件走 Graph，scope 为 Graph 委托权限 + offline_access。
  /// authority = common（个人 + 工作/学校账户）。
  static OAuthProviderConfig? microsoft() {
    if (!AppConfig.isMicrosoftConfigured) return null;
    return OAuthProviderConfig(
      clientId: AppConfig.microsoftClientId,
      redirectUrl: '${AppConfig.redirectScheme}://oauth2redirect',
      scopes: const [
        'https://graph.microsoft.com/Mail.ReadWrite',
        'https://graph.microsoft.com/Mail.Send',
        'https://graph.microsoft.com/User.Read',
        'offline_access',
        'openid',
        'email',
        'profile',
      ],
      serviceConfiguration: const AuthorizationServiceConfiguration(
        authorizationEndpoint:
            'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
        tokenEndpoint:
            'https://login.microsoftonline.com/common/oauth2/v2.0/token',
        endSessionEndpoint:
            'https://login.microsoftonline.com/common/oauth2/v2.0/logout',
      ),
      // 强制选择账户，避免自动使用浏览器中已登录的账户
      additionalParameters: const {
        'prompt': 'select_account',
      },
    );
  }

  /// 按账户类型取 **AppAuth** 提供商配置；未配置或不适用时返回 null。
  ///
  /// Gmail 已改用 Google Identity Services 原生流程（见 `GoogleAuthService`），
  /// 不再走 flutter_appauth / 自定义 URI scheme，因此这里对 Gmail 返回 null。
  static OAuthProviderConfig? forType(AccountType type) {
    switch (type) {
      case AccountType.gmailOAuth:
        return null;
      case AccountType.microsoftGraph:
        return microsoft();
      case AccountType.genericImap:
        return null;
    }
  }
}
