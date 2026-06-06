import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/utils/id_generator.dart';
import '../../data/auth/oauth_config.dart';
import '../../data/auth/oauth_identity.dart';
import '../../data/local/database/app_database.dart';
import '../../domain/enums/account_enums.dart';

/// OAuth 认证页面（Gmail / Microsoft）。
///
/// 流程：
/// 1. 自动触发 OAuth 登录（Custom Tab）
/// 2. 获取令牌后保存账户配置
/// 3. 导航到主界面
class OAuthPage extends ConsumerStatefulWidget {
  const OAuthPage({required this.accountType, required this.email, super.key});

  final AccountType accountType;
  final String email;

  @override
  ConsumerState<OAuthPage> createState() => _OAuthPageState();
}

class _OAuthPageState extends ConsumerState<OAuthPage> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 页面加载后自动触发 OAuth 流程
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startOAuth();
    });
  }

  Future<void> _startOAuth() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      // 调试：检查配置
      debugPrint('=== 开始 OAuth 流程 ===');
      debugPrint('账户类型: ${widget.accountType}');
      debugPrint('邮箱: ${widget.email}');

      final config = OAuthProviders.forType(widget.accountType);
      if (config == null) {
        throw Exception(
          'OAuth 配置未找到。\n'
          '请检查是否传入了 --dart-define=MS_OAUTH_CLIENT_ID\n'
          '客户端 ID 格式应为 GUID（如 12345678-1234-1234-1234-123456789abc）',
        );
      }

      debugPrint('客户端 ID: ${config.clientId.substring(0, 8)}...');
      debugPrint('重定向 URI: ${config.redirectUrl}');
      debugPrint('权限范围数量: ${config.scopes.length}');

      final oauthService = ref.read(oauthServiceProvider);
      final tokenStore = ref.read(tokenStoreProvider);
      final db = ref.read(databaseProvider);

      // 1. 执行 OAuth 登录
      debugPrint('调用 OAuth 服务...');
      final tokens = await oauthService.authorize(
        widget.accountType,
        expectedEmail: widget.email,
      );
      debugPrint('OAuth 成功！');

      if (tokens.refreshToken == null) {
        throw Exception('未获取到 refresh token，无法保存账户');
      }

      // 2. 生成账户 ID 和密钥引用
      final accountId = generateId();
      final secretRef = 'account_$accountId';

      // 3. 保存 refresh token 到安全存储
      await tokenStore.writeRefreshToken(secretRef, tokens.refreshToken!);

      // 4. 保存账户配置到数据库
      final displayName = widget.accountType == AccountType.gmailOAuth
          ? 'Gmail'
          : 'Microsoft';

      await db.accountDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          email: widget.email,
          displayName: displayName,
          accountType: widget.accountType,
          authType: AuthType.oauth,
          secretRef: Value(secretRef),
          colorValue: Value(_generateAccountColor()),
        ),
      );

      debugPrint('账户保存成功！');

      // 5. 导航到同步配置页面
      if (mounted) {
        context.push(
          '/onboarding/sync-config?email=${Uri.encodeComponent(widget.email)}&accountId=${Uri.encodeComponent(accountId)}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('=== OAuth 错误 ===');
      debugPrint('错误类型: ${e.runtimeType}');
      debugPrint('错误消息: $e');
      debugPrint('堆栈跟踪:\n$stackTrace');

      setState(() {
        _isAuthenticating = false;
        _errorMessage = _formatErrorMessage(e);
      });
    }
  }

  String _formatErrorMessage(Object error) {
    if (error is OAuthAccountMismatchException) {
      return '${error.message}\n\n请点击重试，并在 Microsoft 登录页选择 ${error.expectedEmail}。';
    }

    return '登录失败：$error\n\n'
        '请检查：\n'
        '1. 客户端 ID 是否正确配置\n'
        '2. Azure 应用的重定向 URI 是否为\n'
        '   com.everyemail.app://oauth2redirect\n'
        '3. 网络连接是否正常\n\n'
        '查看控制台日志获取详细信息';
  }

  int _generateAccountColor() {
    // 生成随机的 Material 3 色调
    final colors = [
      Colors.blue.toARGB32(),
      Colors.green.toARGB32(),
      Colors.orange.toARGB32(),
      Colors.purple.toARGB32(),
      Colors.teal.toARGB32(),
      Colors.pink.toARGB32(),
      Colors.indigo.toARGB32(),
      Colors.amber.toARGB32(),
    ];
    return colors[DateTime.now().millisecondsSinceEpoch % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountName = widget.accountType == AccountType.gmailOAuth
        ? 'Gmail'
        : 'Microsoft';

    return Scaffold(
      appBar: AppBar(title: Text('登录 $accountName')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isAuthenticating) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  '正在打开 $accountName 登录页面...',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '请在浏览器中完成登录',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else if (_errorMessage != null) ...[
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text('登录失败', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('返回'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: _startOAuth,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
