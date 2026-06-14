import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/providers.dart';
import '../../core/utils/id_generator.dart';
import '../../data/autoconfig/local_provider_presets.dart';
import '../../data/backends/imap/imap_mail_backend.dart';
import '../../data/local/database/app_database.dart';
import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';
import 'account_overwrite_guard.dart';

/// 密码输入页面（IMAP 账户）。
///
/// 流程：
/// 1. 显示自动发现的服务器配置
/// 2. 输入密码
/// 3. 测试连接
/// 4. 保存账户配置
/// 5. 导航到主界面
class PasswordPage extends ConsumerStatefulWidget {
  const PasswordPage({
    required this.email,
    required this.imap,
    this.smtp,
    this.loginName,
    super.key,
  });

  final String email;
  final ServerConfig imap;
  final ServerConfig? smtp;

  /// 自动发现推导出的建议登录名（如 local-part）；为空则默认用邮箱地址。
  final String? loginName;

  @override
  ConsumerState<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends ConsumerState<PasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  late final TextEditingController _loginNameController = TextEditingController(
    text: widget.loginName ?? widget.email,
  );
  bool _obscurePassword = true;
  bool _isTesting = false;
  String? _errorMessage;

  /// 检查是否是 Office 365 服务器。
  bool get _isOffice365 {
    final imapHost = widget.imap.host.toLowerCase();
    final smtpHost = widget.smtp?.host.toLowerCase() ?? '';

    return imapHost.contains('outlook.office365.com') ||
        imapHost.contains('imap-mail.outlook.com') ||
        smtpHost.contains('smtp.office365.com') ||
        smtpHost.contains('smtp-mail.outlook.com');
  }

  /// 国内邮箱本地预设的登录引导（授权码 / 客户端专用密码等），无则为 null。
  String? get _loginHint => ProviderPresets.lookup(widget.email)?.loginHint;

  @override
  void dispose() {
    _passwordController.dispose();
    _loginNameController.dispose();
    super.dispose();
  }

  /// 使用 OAuth 登录（Office 365）。
  Future<void> _loginWithOAuth() async {
    // 跳转到 OAuth 登录页面
    context.push(
      '/onboarding/oauth?type=${AccountType.microsoftGraph.name}&email=${Uri.encodeComponent(widget.email)}',
    );
  }

  Future<void> _testAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final db = ref.read(databaseProvider);
    final overwriteDecision = await confirmAccountOverwrite(
      context: context,
      db: db,
      email: widget.email,
    );
    if (!mounted || !overwriteDecision.shouldContinue) return;

    setState(() {
      _isTesting = true;
      _errorMessage = null;
    });

    try {
      final password = _passwordController.text;
      final tokenStore = ref.read(tokenStoreProvider);
      final email = widget.email.trim();
      final existingAccount = overwriteDecision.existingAccount;

      // 1. 生成临时账户配置用于测试连接
      final testAccount = AccountConfig(
        id: 'test',
        email: email,
        displayName: email,
        type: AccountType.genericImap,
        authType: AuthType.password,
        imap: widget.imap,
        smtp: widget.smtp,
        secretRef: null,
        loginName: _loginNameController.text.trim(),
      );

      // 2. 测试 IMAP 连接
      final backend = ImapMailBackend(account: testAccount, password: password);

      await backend.connect();
      await backend.disconnect();

      // 3. 生成账户 ID 和密钥引用
      final accountId = existingAccount?.id ?? generateId();
      final secretRef = existingAccount?.secretRef ?? 'account_$accountId';

      // 4. 保存密码到安全存储
      await tokenStore.writePassword(secretRef, password);
      await tokenStore.deleteRefreshToken(secretRef);

      // 5. 保存账户配置到数据库
      await db.accountDao.upsertAccount(
        AccountsCompanion.insert(
          id: accountId,
          email: email,
          displayName: existingAccount?.displayName ?? email.split('@').first,
          accountType: AccountType.genericImap,
          authType: AuthType.password,
          secretRef: Value(secretRef),
          imapHost: Value(widget.imap.host),
          imapPort: Value(widget.imap.port),
          imapSocketType: Value(widget.imap.socketType),
          smtpHost: Value(widget.smtp?.host),
          smtpPort: Value(widget.smtp?.port),
          smtpSocketType: Value(widget.smtp?.socketType),
          loginName: Value(_loginNameController.text.trim()),
          colorValue: Value(
            existingAccount == null
                ? _generateAccountColor()
                : existingAccount.colorValue,
          ),
        ),
      );

      // 6. 导航到完善账户信息页面（首次同步前可改名称/颜色/头像）
      if (mounted) {
        context.push(
          '/onboarding/profile?email=${Uri.encodeComponent(email)}&accountId=${Uri.encodeComponent(accountId)}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _errorMessage = '连接失败: ${e.toString()}';
      });
    }
  }

  int _generateAccountColor() {
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

    return Scaffold(
      appBar: AppBar(title: const Text('输入密码')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // 邮箱地址
            Text(widget.email, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '已自动配置服务器设置',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // 服务器配置卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('服务器配置', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    _buildServerInfo('IMAP', widget.imap),
                    if (widget.smtp != null) ...[
                      const Divider(height: 24),
                      _buildServerInfo('SMTP', widget.smtp!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 授权码 / 客户端专用密码提示（国内邮箱本地预设命中时）
            if (_loginHint != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.info,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _loginHint!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Office 365 检测提示
            if (_isOffice365) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.info,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '检测到 Microsoft 365 / Office 365',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '推荐使用 OAuth 登录，更安全且无需应用专用密码',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // OAuth 登录按钮
              FilledButton.icon(
                onPressed: _isTesting ? null : _loginWithOAuth,
                icon: const Icon(Symbols.login),
                label: const Text('使用 Microsoft 账号登录'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 16),

              // 分隔线
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '或使用密码登录',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 登录名（IMAP 用户名；默认等于邮箱，部分邮箱要求 @ 前的本地部分，可改）
            TextFormField(
              controller: _loginNameController,
              decoration: const InputDecoration(
                labelText: '登录名',
                hintText: '通常为完整邮箱地址',
                prefixIcon: Icon(Symbols.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入登录名';
                }
                return null;
              },
              enabled: !_isTesting,
            ),
            const SizedBox(height: 16),

            // 密码输入
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '密码',
                hintText: '输入邮箱密码',
                prefixIcon: const Icon(Symbols.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Symbols.visibility
                        : Symbols.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                return null;
              },
              enabled: !_isTesting,
            ),
            const SizedBox(height: 8),
            Text(
              '密码将安全存储在设备上',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            // 错误消息
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Symbols.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // 操作按钮
            FilledButton(
              onPressed: _isTesting ? null : _testAndSave,
              child: _isTesting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('测试连接并保存'),
            ),

            const SizedBox(height: 12),

            // 手动设置按钮
            OutlinedButton(
              onPressed: _isTesting
                  ? null
                  : () {
                      context.push(
                        '/onboarding/manual?email=${Uri.encodeComponent(widget.email)}',
                      );
                    },
              child: const Text('修改服务器设置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerInfo(String label, ServerConfig config) {
    final theme = Theme.of(context);
    final socketTypeLabel = config.socketType == SocketType.ssl
        ? 'SSL/TLS'
        : config.socketType == SocketType.starttls
        ? 'STARTTLS'
        : '明文';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow('服务器', config.host),
        _buildInfoRow('端口', config.port.toString()),
        _buildInfoRow('加密', socketTypeLabel),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
