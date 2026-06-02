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

  /// Google：IMAP/SMTP 全权限 scope = https://mail.google.com/，外加身份 scope。
  /// Android 客户端重定向用 client id 的反向 DNS（AppAuth 约定）。
  static OAuthProviderConfig? google() {
    if (!AppConfig.isGoogleConfigured) return null;
    final clientId = AppConfig.googleClientId;
    // 反向 DNS：xxxx.apps.googleusercontent.com -> com.googleusercontent.apps.xxxx
    final reversed = _reverseGoogleClientId(clientId);
    return OAuthProviderConfig(
      clientId: clientId,
      redirectUrl: '$reversed:/oauth2redirect',
      scopes: const [
        'https://mail.google.com/',
        'openid',
        'email',
        'profile',
      ],
      serviceConfiguration: const AuthorizationServiceConfiguration(
        authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
        tokenEndpoint: 'https://oauth2.googleapis.com/token',
      ),
      // 强制返回 refresh token + 每次都给同意，避免拿不到 refresh token。
      additionalParameters: const {
        'access_type': 'offline',
        'prompt': 'consent',
      },
    );
  }

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

  /// 按账户类型取提供商配置；未配置或不适用时返回 null。
  static OAuthProviderConfig? forType(AccountType type) {
    switch (type) {
      case AccountType.gmailOAuth:
        return google();
      case AccountType.microsoftGraph:
        return microsoft();
      case AccountType.genericImap:
        return null;
    }
  }

  static String _reverseGoogleClientId(String clientId) {
    // xxxx.apps.googleusercontent.com -> com.googleusercontent.apps.xxxx
    final base = clientId.replaceAll('.apps.googleusercontent.com', '');
    return 'com.googleusercontent.apps.$base';
  }
}
