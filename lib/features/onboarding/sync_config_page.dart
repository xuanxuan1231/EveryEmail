import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/enums/account_enums.dart';
import '../../domain/models/account_config.dart';

/// 同步配置页面。
///
/// 在测试连接成功后，让用户配置首次同步的邮件数量。
class SyncConfigPage extends ConsumerStatefulWidget {
  const SyncConfigPage({
    required this.email,
    required this.accountId,
    super.key,
  });

  final String email;
  final String accountId;

  @override
  ConsumerState<SyncConfigPage> createState() => _SyncConfigPageState();
}

class _SyncConfigPageState extends ConsumerState<SyncConfigPage> {
  int _messageCount = 100;
  bool _isSyncing = false;
  double _syncProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('同步设置'),
      ),
      body: _isSyncing ? _buildSyncingView(theme) : _buildConfigView(theme),
    );
  }

  Widget _buildConfigView(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // 标题
        Text(
          '首次同步',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '选择要下载的邮件数量',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // 邮件数量选择
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '下载邮件数量',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '$_messageCount 封',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _messageCount.toDouble(),
                  min: 50,
                  max: 500,
                  divisions: 9,
                  label: '$_messageCount 封',
                  onChanged: (value) {
                    setState(() {
                      _messageCount = value.toInt();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '50 封',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '500 封',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 预设选项
        Text(
          '快速选择',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPresetChip(theme, 50),
            _buildPresetChip(theme, 100),
            _buildPresetChip(theme, 200),
            _buildPresetChip(theme, 500),
          ],
        ),

        const SizedBox(height: 32),

        // 说明
        Container(
          padding: const EdgeInsets.all(16),
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
                  '首次同步会下载最近的邮件。\n'
                  '下载数量越多，首次同步时间越长。\n'
                  '后续可以在设置中调整。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // 开始同步按钮
        FilledButton(
          onPressed: _startSync,
          child: const Text('开始同步'),
        ),

        const SizedBox(height: 12),

        // 跳过按钮
        OutlinedButton(
          onPressed: () {
            context.go('/');
          },
          child: const Text('稍后同步'),
        ),
      ],
    );
  }

  Widget _buildSyncingView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: _syncProgress,
                strokeWidth: 8,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '正在同步邮件',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${(_syncProgress * 100).toInt()}%',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '请稍候，正在下载邮件...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(ThemeData theme, int count) {
    final isSelected = _messageCount == count;

    return FilterChip(
      label: Text('$count 封'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _messageCount = count;
          });
        }
      },
    );
  }

  Future<void> _startSync() async {
    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
    });

    try {
      final db = ref.read(databaseProvider);
      final syncService = ref.read(syncServiceProvider);

      // 1. 获取账户配置
      final accountData = await db.accountDao.getAccount(widget.accountId);
      if (accountData == null) {
        throw Exception('账户不存在');
      }

      // 2. 转换为 AccountConfig
      final account = AccountConfig(
        id: accountData.id,
        email: accountData.email,
        displayName: accountData.displayName,
        type: accountData.accountType,
        authType: accountData.authType,
        secretRef: accountData.secretRef,
        imap: accountData.imapHost != null
            ? ServerConfig(
                host: accountData.imapHost!,
                port: accountData.imapPort!,
                socketType: accountData.imapSocketType!,
              )
            : null,
        smtp: accountData.smtpHost != null
            ? ServerConfig(
                host: accountData.smtpHost!,
                port: accountData.smtpPort!,
                socketType: accountData.smtpSocketType!,
              )
            : null,
        colorValue: accountData.colorValue,
      );

      // 3. 执行同步
      await syncService.syncAccountWithLimit(
        account,
        _messageCount,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _syncProgress = progress;
            });
          }
        },
      );

      // 4. Microsoft 账户：启用 Graph webhook 订阅 + 注册 FCM token（推送通知）。
      //    失败不阻塞——webhook 是体验优化，主同步已经完成；
      //    下次启动时 FcmBootstrap 会再补一次订阅和 token 注册。
      if (account.type == AccountType.microsoftGraph) {
        try {
          final manager = ref.read(webhookManagerProvider);
          await manager.enableWebhook(account);
          final fcmToken = ref.read(fcmTokenProvider);
          if (fcmToken != null) {
            await manager.registerFCMToken(account.id, fcmToken);
          }
        } catch (e) {
          debugPrint('启用 webhook 订阅失败（不阻塞）: $e');
        }
      }

      // 5. 同步完成，导航到主页面
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }
}
