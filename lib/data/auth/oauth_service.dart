import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import '../../core/config/app_config.dart';
import '../../domain/enums/account_enums.dart';
import '../backends/mail_backend.dart';
import 'google_auth_service.dart';
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

/// OAuth 认证服务。
///
/// - **Microsoft（Graph）**：flutter_appauth（原生 AppAuth + PKCE + Custom Tab，
///   自定义 scheme 回调）。
/// - **Google（Gmail XOAUTH2）**：Google Identity Services 原生流程——账户选择器
///   返回 server auth code，交给 Cloudflare Worker 用 Web client 兑换 token
///   （[GoogleAuthService]）。不再使用自定义 URI scheme 回调。
///
/// - [authorize]：交互式登录，返回令牌包。
/// - [refresh]：用 refresh token 静默换新 access token。
class OAuthService {
  OAuthService({
    FlutterAppAuth? appAuth,
    Dio? dio,
    GoogleAuthService? googleAuth,
    String? workerBaseUrl,
  }) : _appAuth = appAuth ?? const FlutterAppAuth(),
       _dio = dio ?? Dio(),
       _googleAuth = googleAuth ?? GoogleAuthService(),
       _workerBaseUrl = workerBaseUrl ?? AppConfig.workerBaseUrl;

  final FlutterAppAuth _appAuth;
  final Dio _dio;
  final GoogleAuthService _googleAuth;
  final String _workerBaseUrl;

  /// 交互式登录。[accountType] 必须是 OAuth 类型（gmail / microsoft）。
  Future<OAuthTokens> authorize(
    AccountType accountType, {
    String? expectedEmail,
  }) async {
    // Gmail 走 GIS 原生流程（server auth code → Worker 兑换），与 Microsoft 的
    // AppAuth 流程完全分开。
    if (accountType == AccountType.gmailOAuth) {
      return _authorizeGoogle(expectedEmail: expectedEmail);
    }

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
    if (accountType == AccountType.gmailOAuth) {
      return _refreshGoogle(refreshToken);
    }

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

  // ---- Google（GIS + Worker 兑换）----

  /// Gmail 交互式登录：GIS 取 server auth code → Worker 用 Web client 兑换
  /// access/refresh token。
  Future<OAuthTokens> _authorizeGoogle({String? expectedEmail}) async {
    try {
      final auth = await _googleAuth.getServerAuthCode(
        scopes: OAuthProviders.googleScopes,
        loginHint: expectedEmail,
      );
      final data = await _postWorker('/api/google/exchange', {
        'serverAuthCode': auth.serverAuthCode,
      });
      final refresh = _stringField(data, 'refresh_token');
      if (refresh == null) {
        throw const MailAuthException(
          'Google 未返回 refresh token（请确认 Worker 用「Web 应用」客户端兑换，'
          '且授权请求带 access_type=offline）',
        );
      }
      return OAuthTokens(
        accessToken: _requireField(data, 'access_token'),
        refreshToken: refresh,
        expiresAt: _expiryFrom(data),
        idToken: _stringField(data, 'id_token'),
        scopes: _scopesFrom(data),
        identity: OAuthAccountIdentity(email: auth.email),
      );
    } on MailAuthException {
      rethrow;
    } on DioException catch (e) {
      throw MailAuthException('Google 令牌兑换失败: ${_workerError(e)}', cause: e);
    }
  }

  /// Gmail 静默刷新：把 refresh token 交给 Worker（仅它持有 Web client secret）。
  Future<OAuthTokens> _refreshGoogle(String refreshToken) async {
    try {
      final data = await _postWorker('/api/google/refresh', {
        'refreshToken': refreshToken,
      });
      return OAuthTokens(
        accessToken: _requireField(data, 'access_token'),
        // Google 刷新不回传新的 refresh token，沿用旧的。
        refreshToken: refreshToken,
        expiresAt: _expiryFrom(data),
        idToken: _stringField(data, 'id_token'),
        scopes: _scopesFrom(data),
      );
    } on MailAuthException {
      rethrow;
    } on DioException catch (e) {
      throw MailAuthException(
        'Google 令牌刷新失败，需要重新登录: ${_workerError(e)}',
        cause: e,
      );
    }
  }

  Future<Map<String, dynamic>> _postWorker(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_workerBaseUrl$path',
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = response.data;
    if (data == null) {
      throw const MailAuthException('Worker 未返回数据');
    }
    return data;
  }

  String _requireField(Map<String, dynamic> data, String key) {
    final value = _stringField(data, key);
    if (value == null) {
      throw MailAuthException('Worker 响应缺少字段 $key');
    }
    return value;
  }

  String? _stringField(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  DateTime? _expiryFrom(Map<String, dynamic> data) {
    final raw = data['expires_in'];
    final seconds = raw is int ? raw : int.tryParse('$raw');
    if (seconds == null) return null;
    return DateTime.now().toUtc().add(Duration(seconds: seconds));
  }

  List<String> _scopesFrom(Map<String, dynamic> data) {
    final scope = data['scope'];
    return scope is String && scope.isNotEmpty
        ? scope.split(' ')
        : const <String>[];
  }

  String _workerError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail =
          data['details'] ?? data['error_description'] ?? data['error'];
      if (detail != null && detail.toString().isNotEmpty) {
        return detail.toString();
      }
    }
    if (data != null && data.toString().isNotEmpty) return data.toString();
    return e.message ?? '网络错误';
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
