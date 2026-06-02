import 'package:go_router/go_router.dart';

import '../domain/enums/account_enums.dart';
import '../domain/models/account_config.dart';
import '../features/home/home_page.dart';
import '../features/message/message_detail_page.dart';
import '../features/search/search_page.dart';
import '../features/onboarding/add_account_page.dart';
import '../features/onboarding/manual_setup_page.dart';
import '../features/onboarding/oauth_page.dart';
import '../features/onboarding/password_page.dart';
import '../features/onboarding/sync_config_page.dart';

/// 应用路由表。
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),

    // 邮件详情
    GoRoute(
      path: '/message/:id',
      builder: (context, state) {
        final messageId = state.pathParameters['id']!;
        return MessageDetailPage(messageId: messageId);
      },
    ),

    // 搜索
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchPage(),
    ),

    // 账户向导
    GoRoute(
      path: '/onboarding/add',
      builder: (context, state) => const AddAccountPage(),
    ),
    GoRoute(
      path: '/onboarding/manual',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        return ManualSetupPage(email: email);
      },
    ),
    GoRoute(
      path: '/onboarding/sync-config',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        final accountId = state.uri.queryParameters['accountId'] ?? '';
        return SyncConfigPage(email: email, accountId: accountId);
      },
    ),
    GoRoute(
      path: '/onboarding/oauth',
      builder: (context, state) {
        final accountType = state.uri.queryParameters['type'];
        final email = state.uri.queryParameters['email'] ?? '';

        return OAuthPage(
          accountType: AccountType.values.firstWhere(
            (t) => t.name == accountType,
            orElse: () => AccountType.gmailOAuth,
          ),
          email: email,
        );
      },
    ),
    GoRoute(
      path: '/onboarding/password',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        final imapHost = state.uri.queryParameters['imapHost'] ?? '';
        final imapPort = int.tryParse(state.uri.queryParameters['imapPort'] ?? '') ?? 993;
        final imapSocketType = state.uri.queryParameters['imapSocketType'] ?? 'ssl';
        final smtpHost = state.uri.queryParameters['smtpHost'];
        final smtpPort = int.tryParse(state.uri.queryParameters['smtpPort'] ?? '') ?? 465;
        final smtpSocketType = state.uri.queryParameters['smtpSocketType'] ?? 'ssl';

        return PasswordPage(
          email: email,
          imap: ServerConfig(
            host: imapHost,
            port: imapPort,
            socketType: _parseSocketType(imapSocketType),
          ),
          smtp: smtpHost != null
              ? ServerConfig(
                  host: smtpHost,
                  port: smtpPort,
                  socketType: _parseSocketType(smtpSocketType),
                )
              : null,
        );
      },
    ),
  ],
);

SocketType _parseSocketType(String value) {
  switch (value.toLowerCase()) {
    case 'ssl':
      return SocketType.ssl;
    case 'starttls':
      return SocketType.starttls;
    case 'plain':
      return SocketType.plain;
    default:
      return SocketType.ssl;
  }
}
