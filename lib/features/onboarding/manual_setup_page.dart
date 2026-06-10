import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/utils/id_generator.dart';
import '../../data/backends/imap/imap_mail_backend.dart';
import '../../data/local/database/app_database.dart';
import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';

/// 手动设置服务器页面。
///
/// 用户手动输入 IMAP/SMTP 服务器配置。
class ManualSetupPage extends ConsumerStatefulWidget {
  const ManualSetupPage({
    required this.email,
    super.key,
  });

  final String email;

  @override
  ConsumerState<ManualSetupPage> createState() => _ManualSetupPageState();
}

class _ManualSetupPageState extends ConsumerState<ManualSetupPage> {
  final _formKey = GlobalKey<FormState>();

  // 登录名（IMAP 用户名，默认等于邮箱）
  late final TextEditingController _loginNameController =
      TextEditingController(text: widget.email);

  // IMAP 配置
  final _imapHostController = TextEditingController();
  final _imapPortController = TextEditingController(text: '993');
  SocketType _imapSocketType = SocketType.ssl;
  final _imapPasswordController = TextEditingController();
  bool _obscureImapPassword = true;

  // SMTP 配置
  final _smtpHostController = TextEditingController();
  final _smtpPortController = TextEditingController(text: '465');
  SocketType _smtpSocketType = SocketType.ssl;
  final _smtpPasswordController = TextEditingController();
  bool _obscureSmtpPassword = true;
  bool _useSamePassword = true;

  bool _isTesting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _loginNameController.dispose();
    _imapHostController.dispose();
    _imapPortController.dispose();
    _imapPasswordController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpPasswordController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _errorMessage = null;
    });

    try {
      final imapPassword = _imapPasswordController.text;
      final smtpPassword = _useSamePassword ? imapPassword : _smtpPasswordController.text;

      final tokenStore = ref.read(tokenStoreProvider);
      final db = ref.read(databaseProvider);

      // 1. 生成临时账户配置用于测试连接
      final testAccount = AccountConfig(
        id: 'test',
        email: widget.email,
        displayName: widget.email,
        type: AccountType.genericImap,
        authType: AuthType.password,
        imap: ServerConfig(
          host: _imapHostController.text.trim(),
          port: int.parse(_imapPortController.text),
          socketType: _imapSocketType,
        ),
        smtp: ServerConfig(
          host: _smtpHostController.text.trim(),
          port: int.parse(_smtpPortController.text),
          socketType: _smtpSocketType,
        ),
        secretRef: null,
        loginName: _loginNameController.text.trim(),
      );

      // 2. 测试 IMAP 连接
      final backend = ImapMailBackend(
        account: testAccount,
        password: imapPassword,
      );

      await backend.connect();
      await backend.disconnect();

      // 3. 生成账户 ID 和密钥引用
      final accountId = generateId();
      final secretRef = 'account_$accountId';

      // 4. 保存密码到安全存储
      await tokenStore.writePassword(secretRef, imapPassword);
      // 如果 SMTP 密码不同，也保存
      if (!_useSamePassword) {
        await tokenStore.writePassword('${secretRef}_smtp', smtpPassword);
      }

      // 5. 保存账户配置到数据库
      await db.accountDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          email: widget.email,
          displayName: widget.email.split('@').first,
          accountType: AccountType.genericImap,
          authType: AuthType.password,
          secretRef: Value(secretRef),
          imapHost: Value(_imapHostController.text.trim()),
          imapPort: Value(int.parse(_imapPortController.text)),
          imapSocketType: Value(_imapSocketType),
          smtpHost: Value(_smtpHostController.text.trim()),
          smtpPort: Value(int.parse(_smtpPortController.text)),
          smtpSocketType: Value(_smtpSocketType),
          loginName: Value(_loginNameController.text.trim()),
          colorValue: Value(_generateAccountColor()),
        ),
      );

      // 6. 导航到同步配置页面
      if (mounted) {
        context.push('/onboarding/sync-config?email=${Uri.encodeComponent(widget.email)}&accountId=${Uri.encodeComponent(accountId)}');
      }
    } catch (e) {
      setState(() {
        _isTesting = false;
        _errorMessage = '连接失败: ${e.toString()}';
      });
    }
  }

  int _generateAccountColor() {
    final colors = [
      Colors.blue.value,
      Colors.green.value,
      Colors.orange.value,
      Colors.purple.value,
      Colors.teal.value,
      Colors.pink.value,
      Colors.indigo.value,
      Colors.amber.value,
    ];
    return colors[DateTime.now().millisecondsSinceEpoch % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('手动设置'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // 邮箱地址
            Text(
              widget.email,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '请输入服务器配置',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // IMAP 配置
            Text(
              'IMAP',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _imapHostController,
              decoration: const InputDecoration(
                labelText: 'IMAP 服务器',
                hintText: 'imap.example.com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入 IMAP 服务器地址';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _imapPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入端口';
                      }
                      final port = int.tryParse(value);
                      if (port == null || port < 1 || port > 65535) {
                        return '端口范围 1-65535';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<SocketType>(
                    value: _imapSocketType,
                    decoration: const InputDecoration(
                      labelText: '加密方式',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SocketType.ssl,
                        child: Text('SSL/TLS'),
                      ),
                      DropdownMenuItem(
                        value: SocketType.starttls,
                        child: Text('STARTTLS'),
                      ),
                      DropdownMenuItem(
                        value: SocketType.plain,
                        child: Text('无加密'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _imapSocketType = value;
                          // 自动调整端口
                          if (value == SocketType.ssl && _imapPortController.text == '143') {
                            _imapPortController.text = '993';
                          } else if (value == SocketType.starttls && _imapPortController.text == '993') {
                            _imapPortController.text = '143';
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // SMTP 配置
            Text(
              'SMTP',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _smtpHostController,
              decoration: const InputDecoration(
                labelText: 'SMTP 服务器',
                hintText: 'smtp.example.com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入 SMTP 服务器地址';
                }
                return null;
              },
              enabled: !_isTesting,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _smtpPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入端口';
                      }
                      final port = int.tryParse(value);
                      if (port == null || port < 1 || port > 65535) {
                        return '端口范围 1-65535';
                      }
                      return null;
                    },
                    enabled: !_isTesting,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<SocketType>(
                    value: _smtpSocketType,
                    decoration: const InputDecoration(
                      labelText: '加密方式',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SocketType.ssl,
                        child: Text('SSL/TLS'),
                      ),
                      DropdownMenuItem(
                        value: SocketType.starttls,
                        child: Text('STARTTLS'),
                      ),
                      DropdownMenuItem(
                        value: SocketType.plain,
                        child: Text('无加密'),
                      ),
                    ],
                    onChanged: _isTesting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _smtpSocketType = value;
                                if (value == SocketType.ssl && _smtpPortController.text == '587') {
                                  _smtpPortController.text = '465';
                                } else if (value == SocketType.starttls && _smtpPortController.text == '465') {
                                  _smtpPortController.text = '587';
                                }
                              });
                            }
                          },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 密码配置
            Text(
              '登录凭据',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _loginNameController,
              decoration: const InputDecoration(
                labelText: '登录名',
                hintText: '通常为完整邮箱地址',
                prefixIcon: Icon(Icons.person_outline),
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

            TextFormField(
              controller: _imapPasswordController,
              obscureText: _obscureImapPassword,
              decoration: InputDecoration(
                labelText: 'IMAP 密码',
                hintText: '输入邮箱密码',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureImapPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureImapPassword = !_obscureImapPassword;
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
            const SizedBox(height: 16),

            CheckboxListTile(
              value: _useSamePassword,
              onChanged: _isTesting
                  ? null
                  : (value) {
                      setState(() {
                        _useSamePassword = value ?? true;
                      });
                    },
              title: const Text('SMTP 使用相同密码'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            if (!_useSamePassword) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _smtpPasswordController,
                obscureText: _obscureSmtpPassword,
                decoration: InputDecoration(
                  labelText: 'SMTP 密码',
                  hintText: '输入 SMTP 密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSmtpPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureSmtpPassword = !_obscureSmtpPassword;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 SMTP 密码';
                  }
                  return null;
                },
                enabled: !_isTesting,
              ),
            ],

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

            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '常见配置：\n'
                      '• SSL/TLS: IMAP 993, SMTP 465\n'
                      '• STARTTLS: IMAP 143, SMTP 587',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 继续按钮
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
          ],
        ),
      ),
    );
  }
}
