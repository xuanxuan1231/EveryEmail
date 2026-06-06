import 'package:everyemail/data/auth/oauth_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OAuthAccountIdentity', () {
    test('matches Microsoft profile and token email candidates', () {
      final identity = OAuthAccountIdentity.fromMicrosoftData(
        tokenClaims: const {'preferred_username': 'Token.User@Example.com'},
        graphProfile: const {
          'mail': 'Primary@Example.com',
          'userPrincipalName': 'upn@example.com',
          'otherMails': ['Alias@Example.com'],
          'proxyAddresses': [
            'SMTP:Primary@Example.com',
            'smtp:Proxy@Example.com',
          ],
        },
      );

      expect(identity.primaryEmail, 'primary@example.com');
      expect(identity.emailCandidates, [
        'primary@example.com',
        'upn@example.com',
        'token.user@example.com',
        'alias@example.com',
        'proxy@example.com',
      ]);
      expect(identity.matchesEmail('PROXY@example.com'), isTrue);
      expect(identity.matchesEmail('other@example.com'), isFalse);
    });

    test('ignores non-email identity values', () {
      final identity = OAuthAccountIdentity.fromMicrosoftData(
        tokenClaims: const {'preferred_username': 'display-name'},
        graphProfile: const {
          'mail': null,
          'userPrincipalName': '',
          'otherMails': [''],
          'proxyAddresses': ['SIP:user@example.com'],
        },
      );

      expect(identity.emailCandidates, isEmpty);
      expect(identity.matchesEmail('user@example.com'), isFalse);
    });

    test('mismatch exception reports actual and expected accounts', () {
      final identity = OAuthAccountIdentity.fromMicrosoftData(
        graphProfile: const {'mail': 'actual@example.com'},
      );
      final error = OAuthAccountMismatchException(
        expectedEmail: 'expected@example.com',
        identity: identity,
      );

      expect(error.actualEmail, 'actual@example.com');
      expect(
        error.message,
        contains('actual@example.com，与输入的邮箱 expected@example.com 不一致'),
      );
    });
  });
}
