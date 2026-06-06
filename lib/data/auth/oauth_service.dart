import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import '../../domain/enums/account_enums.dart';
import '../backends/mail_backend.dart';
import 'oauth_config.dart';
import 'oauth_identity.dart';

/// 一次 OAuth 认证产出的令牌包。
class OAuthTokens {
  const OAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
    this.idToken,
    this.scopes = const [],
    this.identity,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? idToken;
  final List<String> scopes;
  final OAuthAccountIdentity? identity;

  /// access token 是否已过期（或将在 [skew] 内过期）。
  bool isExpired({Duration skew = const Duration(minutes: 5)}) {
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().toUtc().add(skew).isAfter(exp.toUtc());
  }
}

/// OAuth 认证服务，基于 flutter_appauth（原生 AppAuth + PKCE + Custom Tab）。
///
/// 同时服务 Google（Gmail XOAUTH2）与 Microsoft（Graph）。
/// - [authorize]：交互式登录（弹出 Custom Tab），返回令牌包。
/// - [refresh]：用 refresh token 静默换新 access token。
class OAuthService {
  OAuthService([FlutterAppAuth? appAuth, Dio? dio])
    : _appAuth = appAuth ?? const FlutterAppAuth(),
      _dio = dio ?? Dio();

  final FlutterAppAuth _appAuth;
  final Dio _dio;

  /// 交互式登录。[accountType] 必须是 OAuth 类型（gmail / microsoft）。
  Future<OAuthTokens> authorize(
    AccountType accountType, {
    String? expectedEmail,
  }) async {
    final provider = OAuthProviders.forType(accountType);
    if (provider == null) {
      throw MailAuthException(
        '账户类型 $accountType 未配置 OAuth（请检查 client id 是否通过 --dart-define 传入）',
      );
    }

    try {
      debugPrint('=== OAuth Service ===');
      debugPrint('客户端 ID: ${provider.clientId}');
      debugPrint('重定向 URL: ${provider.redirectUrl}');
      debugPrint(
        '授权端点: ${provider.serviceConfiguration.authorizationEndpoint}',
      );
      debugPrint('令牌端点: ${provider.serviceConfiguration.tokenEndpoint}');
      debugPrint('权限范围: ${provider.scopes.join(", ")}');
      debugPrint('额外参数: ${provider.additionalParameters}');

      // 创建一个新的 map，排除 prompt 参数（因为使用 promptValues）
      Map<String, String>? additionalParams;
      if (provider.additionalParameters != null) {
        additionalParams = Map<String, String>.from(
          provider.additionalParameters!,
        );
        additionalParams.remove('prompt');
      }
      final loginHint = _loginHint(expectedEmail);

      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          provider.clientId,
          provider.redirectUrl,
          serviceConfiguration: provider.serviceConfiguration,
          scopes: provider.scopes,
          promptValues: const [
            'select_account',
          ], // 使用 promptValues 而不是 additionalParameters
          loginHint: loginHint,
          additionalParameters: additionalParams,
          // Android 始终使用 Custom Tab；externalUserAgent 仅影响 iOS/macOS，用默认即可。
        ),
      );

      debugPrint('OAuth 授权成功！');
      var tokens = _toTokens(result, fallbackRefresh: null);
      if (accountType == AccountType.microsoftGraph) {
        final identity = await _resolveMicrosoftIdentity(tokens);
        final normalizedExpected = OAuthAccountIdentity.normalizeEmail(
          expectedEmail,
        );
        if (normalizedExpected != null &&
            !identity.matchesEmail(normalizedExpected)) {
          throw OAuthAccountMismatchException(
            expectedEmail: normalizedExpected,
            identity: identity,
          );
        }
        tokens = OAuthTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          expiresAt: tokens.expiresAt,
          idToken: tokens.idToken,
          scopes: tokens.scopes,
          identity: identity,
        );
      }
      return tokens;
    } on Exception catch (e) {
      debugPrint('=== OAuth Service 错误 ===');
      debugPrint('异常类型: ${e.runtimeType}');
      debugPrint('异常详情: $e');
      if (e is OAuthAccountMismatchException) rethrow;
      throw MailAuthException('OAuth 登录失败: $e', cause: e);
    }
  }

  /// 用 refresh token 静默刷新。
  Future<OAuthTokens> refresh(
    AccountType accountType,
    String refreshToken,
  ) async {
    final provider = OAuthProviders.forType(accountType);
    if (provider == null) {
      throw MailAuthException('账户类型 $accountType 未配置 OAuth');
    }

    try {
      final result = await _appAuth.token(
        TokenRequest(
          provider.clientId,
          provider.redirectUrl,
          serviceConfiguration: provider.serviceConfiguration,
          refreshToken: refreshToken,
          scopes: provider.scopes,
        ),
      );
      // 部分提供商刷新时不回传 refresh token，沿用旧的。
      return _toTokens(result, fallbackRefresh: refreshToken);
    } on Exception catch (e) {
      throw MailAuthException('OAuth 刷新失败，需要重新登录', cause: e);
    }
  }

  OAuthTokens _toTokens(TokenResponse? r, {required String? fallbackRefresh}) {
    final access = r?.accessToken;
    if (access == null) {
      throw const MailAuthException('OAuth 未返回 access token');
    }
    return OAuthTokens(
      accessToken: access,
      refreshToken: r?.refreshToken ?? fallbackRefresh,
      expiresAt: r?.accessTokenExpirationDateTime,
      idToken: r?.idToken,
      scopes: r?.scopes ?? const [],
    );
  }

  Future<OAuthAccountIdentity> _resolveMicrosoftIdentity(
    OAuthTokens tokens,
  ) async {
    final tokenClaims = _decodeJwtPayload(tokens.idToken);
    Map<String, dynamic>? graphProfile;

    try {
      graphProfile = await _fetchMicrosoftMe(tokens.accessToken);
    } on DioException catch (e) {
      final fallback = OAuthAccountIdentity.fromMicrosoftData(
        tokenClaims: tokenClaims,
      );
      if (fallback.emailCandidates.isNotEmpty) {
        return fallback;
      }
      throw MailAuthException('无法读取 Microsoft 授权账号信息', cause: e);
    }

    final identity = OAuthAccountIdentity.fromMicrosoftData(
      tokenClaims: tokenClaims,
      graphProfile: graphProfile,
    );
    if (identity.emailCandidates.isEmpty) {
      throw const MailAuthException('Microsoft 未返回可校验的账号邮箱');
    }
    return identity;
  }

  Future<Map<String, dynamic>> _fetchMicrosoftMe(String accessToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://graph.microsoft.com/v1.0/me',
      queryParameters: const {
        r'$select': 'mail,userPrincipalName,otherMails,proxyAddresses',
      },
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );

    final data = response.data;
    if (data == null) {
      throw const MailAuthException('Microsoft Graph 未返回账号信息');
    }
    return data;
  }

  Map<String, dynamic>? _decodeJwtPayload(String? token) {
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String? _loginHint(String? email) {
    final trimmed = email?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
