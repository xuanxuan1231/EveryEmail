import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/enums/account_enums.dart';

/// 添加账户页面（账户向导入口）。
///
/// 流程：
/// 1. 输入邮箱地址
/// 2. 自动发现服务器配置
/// 3. 根据账户类型路由到 OAuth 或密码页面
class AddAccountPage extends ConsumerStatefulWidget {
  const AddAccountPage({super.key});

  @override
  ConsumerState<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends ConsumerState<AddAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isDiscovering = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 监听路由返回，重置状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 如果从其他页面返回，重置加载状态
      if (mounted && _isDiscovering) {
        setState(() {
          _isDiscovering = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isDiscovering = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final accountRepo = ref.read(accountRepositoryProvider);

      // 尝试自动发现服务器配置
      final result = await accountRepo.discover(email);

      if (!mounted) return;

      // 根据发现结果路由
      if (result != null) {
        switch (result.suggestedType) {
          case AccountType.gmailOAuth:
          case AccountType.microsoftGraph:
            // OAuth 流程
            context.push(
              '/onboarding/oauth?type=${result.suggestedType.name}&email=${Uri.encodeComponent(email)}',
            );
            return;

          case AccountType.genericImap:
            // IMAP 密码流程 - 显示自动发现的配置
            if (result.imap != null) {
              final imap = result.imap!;
              final smtp = result.smtp;

              final queryParams = {
                'email': email,
                'imapHost': imap.host,
                'imapPort': imap.port.toString(),
                'imapSocketType': imap.socketType.name,
                if (smtp != null) ...{
                  'smtpHost': smtp.host,
                  'smtpPort': smtp.port.toString(),
                  'smtpSocketType': smtp.socketType.name,
                },
              };

              final uri = Uri(path: '/onboarding/password', queryParameters: queryParams);
              context.push(uri.toString());
              return;
            }
            break;
        }
      }

      // 未找到配置，直接导航到手动设置页面
      if (mounted) {
        context.push('/onboarding/manual?email=${Uri.encodeComponent(email)}');
      }

      setState(() {
        _isDiscovering = false;
      });
    } catch (e) {
      // 发现失败，直接跳转到手动设置
      if (mounted) {
        final email = _emailController.text.trim();
        context.push('/onboarding/manual?email=${Uri.encodeComponent(email)}');
      }
      setState(() {
        _isDiscovering = false;
      });
    }
  }

  void _manualSetup() {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    context.push('/onboarding/manual?email=${Uri.encodeComponent(email)}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加账户'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // 标题
            Text(
              '输入邮箱地址',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '我们会自动配置服务器设置',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // 邮箱输入
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '邮箱地址',
                hintText: 'example@gmail.com',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入邮箱地址';
                }
                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                if (!emailRegex.hasMatch(value)) {
                  return '请输入有效的邮箱地址';
                }
                return null;
              },
              enabled: !_isDiscovering,
              onFieldSubmitted: (_) => _discover(),
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
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                    ),
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

            // 继续按钮
            FilledButton(
              onPressed: _isDiscovering ? null : _discover,
              child: _isDiscovering
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('继续'),
            ),

            const SizedBox(height: 12),

            // 手动设置按钮
            OutlinedButton(
              onPressed: _isDiscovering ? null : _manualSetup,
              child: const Text('手动设置'),
            ),

            const SizedBox(height: 24),

            // 支持的服务商
            Text(
              '支持的邮箱服务',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildProviderChip(context, 'Gmail'),
                _buildProviderChip(context, 'Outlook'),
                _buildProviderChip(context, 'QQ 邮箱'),
                _buildProviderChip(context, '163 邮箱'),
                _buildProviderChip(context, '其他 IMAP'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderChip(BuildContext context, String label) {
    return Chip(
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.bodySmall,
      visualDensity: VisualDensity.compact,
    );
  }
}
