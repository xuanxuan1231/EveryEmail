import '../backends/mail_backend.dart';

/// Identity information returned by an OAuth provider after authorization.
class OAuthAccountIdentity {
  const OAuthAccountIdentity({
    this.mail,
    this.userPrincipalName,
    this.preferredUsername,
    this.email,
    this.upn,
    this.uniqueName,
    this.otherMails = const [],
    this.proxyAddresses = const [],
  });

  /// Identity from a generic OIDC id_token. Google's id_token carries the
  /// verified `email` claim (scopes `openid email`), which is all we need to
  /// learn the account's address when the user signs in without typing one.
  factory OAuthAccountIdentity.fromIdTokenClaims(
    Map<String, dynamic>? tokenClaims,
  ) {
    final claims = tokenClaims ?? const <String, dynamic>{};
    return OAuthAccountIdentity(
      email: _stringOrNull(claims['email']),
      preferredUsername: _stringOrNull(claims['preferred_username']),
    );
  }

  factory OAuthAccountIdentity.fromMicrosoftData({
    Map<String, dynamic>? tokenClaims,
    Map<String, dynamic>? graphProfile,
  }) {
    final claims = tokenClaims ?? const <String, dynamic>{};
    final profile = graphProfile ?? const <String, dynamic>{};

    return OAuthAccountIdentity(
      mail: _stringOrNull(profile['mail']),
      userPrincipalName: _stringOrNull(profile['userPrincipalName']),
      preferredUsername: _stringOrNull(claims['preferred_username']),
      email: _stringOrNull(claims['email']),
      upn: _stringOrNull(claims['upn']),
      uniqueName: _stringOrNull(claims['unique_name']),
      otherMails: _stringsFrom(profile['otherMails']).toList(),
      proxyAddresses: _stringsFrom(profile['proxyAddresses']).toList(),
    );
  }

  final String? mail;
  final String? userPrincipalName;
  final String? preferredUsername;
  final String? email;
  final String? upn;
  final String? uniqueName;
  final List<String> otherMails;
  final List<String> proxyAddresses;

  String? get primaryEmail {
    for (final value in [
      mail,
      userPrincipalName,
      preferredUsername,
      email,
      upn,
      uniqueName,
      ...otherMails,
      ...proxyAddresses,
    ]) {
      final normalized = _normalizeEmailCandidate(value);
      if (normalized != null) return normalized;
    }
    return null;
  }

  List<String> get emailCandidates {
    final result = <String>[];
    final seen = <String>{};
    for (final value in [
      mail,
      userPrincipalName,
      preferredUsername,
      email,
      upn,
      uniqueName,
      ...otherMails,
      ...proxyAddresses,
    ]) {
      final normalized = _normalizeEmailCandidate(value);
      if (normalized != null && seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }

  bool matchesEmail(String expectedEmail) {
    final normalizedExpected = normalizeEmail(expectedEmail);
    if (normalizedExpected == null) return false;
    return emailCandidates.contains(normalizedExpected);
  }

  static String? normalizeEmail(String? value) {
    final trimmed = value?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty || !trimmed.contains('@')) {
      return null;
    }
    return trimmed;
  }

  static String? _normalizeEmailCandidate(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final colon = trimmed.indexOf(':');
    if (colon < 0) return normalizeEmail(trimmed);

    final proxyType = trimmed.substring(0, colon).toLowerCase();
    if (proxyType != 'smtp') return null;
    return normalizeEmail(trimmed.substring(colon + 1));
  }

  static String? _stringOrNull(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Iterable<String> _stringsFrom(Object? value) sync* {
    if (value is List) {
      for (final item in value) {
        final stringValue = _stringOrNull(item);
        if (stringValue != null) yield stringValue;
      }
    }
  }
}

/// Raised when the user authorizes a different Microsoft account than the
/// email address entered in the add-account flow.
class OAuthAccountMismatchException extends MailAuthException {
  OAuthAccountMismatchException({
    required this.expectedEmail,
    required this.identity,
  }) : super(_message(expectedEmail, identity));

  final String expectedEmail;
  final OAuthAccountIdentity identity;

  String? get actualEmail => identity.primaryEmail;

  static String _message(String expectedEmail, OAuthAccountIdentity identity) {
    final actual = identity.primaryEmail;
    if (actual == null) {
      return '无法确认 Microsoft 授权账号是否为 $expectedEmail，请重新登录正确账号';
    }
    return 'Microsoft 授权账号是 $actual，与输入的邮箱 $expectedEmail 不一致，请重新登录正确账号';
  }
}
