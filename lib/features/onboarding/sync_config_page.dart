import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/providers.dart';
import '../../core/theme/theme_ext.dart';
import '../../data/sync/initial_sync_progress.dart';
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
  InitialSyncProgress _syncDetail = const InitialSyncProgress(
    stage: InitialSyncStage.connecting,
    progress: 0.0,
    statusMessage: '准备同步',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('同步设置')),
      body: _isSyncing ? _buildSyncingView(theme) : _buildConfigView(theme),
    );
  }

  Widget _buildConfigView(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // 标题
        Text('首次同步', style: theme.textTheme.headlineMedium),
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
                    Text('下载邮件数量', style: theme.textTheme.titleMedium),
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
                Symbols.info,
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
        FilledButton(onPressed: _startSync, child: const Text('开始同步')),

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
    final detail = _syncDetail;
    final folderStatus = _folderStatus(detail);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: _buildProgressRing(theme)),
                const SizedBox(height: 32),
                Text(
                  '正在首次同步',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  detail.statusMessage ?? _stageSubtitle(detail.stage),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (folderStatus != null) ...[
                  const SizedBox(height: 24),
                  _buildFolderStatus(theme, folderStatus),
                ],
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetric(theme, '已获取', detail.fetchedMessages),
                    _buildMetric(theme, '已保存', detail.savedMessages),
                    _buildMetric(theme, '已更新', detail.updatedMessages),
                    _buildMetric(theme, '已移除', detail.removedMessages),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRing(ThemeData theme) {
    final motion = context.motion;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: _syncProgress),
      duration: motion.medium,
      curve: motion.emphasized,
      builder: (context, progress, child) {
        return SizedBox(
          width: 128,
          height: 128,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFolderStatus(ThemeData theme, String folderStatus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Symbols.folder,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '当前文件夹 $folderStatus',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(ThemeData theme, String label, int value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value 封',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _stageSubtitle(InitialSyncStage stage) {
    return switch (stage) {
      InitialSyncStage.connecting => '正在建立连接',
      InitialSyncStage.listingFolders => '正在读取文件夹列表',
      InitialSyncStage.savingFolders => '正在保存文件夹',
      InitialSyncStage.syncingInbox => '正在同步收件箱',
      InitialSyncStage.savingMessages => '正在保存邮件',
      InitialSyncStage.updatingCursor => '正在更新同步游标',
      InitialSyncStage.enablingRealtime => '正在启用实时同步',
      InitialSyncStage.complete => '同步完成',
    };
  }

  String? _folderStatus(InitialSyncProgress progress) {
    final folderName = progress.currentFolderName;
    if (folderName == null || folderName.trim().isEmpty) return null;

    final folderIndex = progress.folderIndex;
    final folderCount = progress.folderCount;
    if (folderIndex == null || folderCount == null || folderCount == 0) {
      return folderName;
    }

    return '$folderName ($folderIndex/$folderCount)';
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
      _syncDetail = const InitialSyncProgress(
        stage: InitialSyncStage.connecting,
        progress: 0.0,
        statusMessage: '准备同步',
      );
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
        onProgress: _handleLegacyProgress,
        onDetailedProgress: _handleDetailedProgress,
      );

      // 4. Microsoft 账户：启用 Graph webhook 订阅 + 注册 FCM token（推送通知）。
      //    失败不阻塞——webhook 是体验优化，主同步已经完成；
      //    下次启动时 FcmBootstrap 会再补一次订阅和 token 注册。
      if (account.type == AccountType.microsoftGraph) {
        _showRealtimeStage();
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
      } else if (account.type == AccountType.gmailOAuth) {
        // Gmail：建立 Gmail watch + 注册 FCM token。同样不阻塞，
        // 下次启动 FcmBootstrap 也会兜底重建 watch 和注册 token。
        _showRealtimeStage();
        try {
          final gmailManager = ref.read(gmailWatchManagerProvider);
          await gmailManager.enableWatch(account);
          final fcmToken = ref.read(fcmTokenProvider);
          if (fcmToken != null) {
            await gmailManager.registerFCMToken(account.id, fcmToken);
          }
        } catch (e) {
          debugPrint('启用 Gmail watch 失败（不阻塞）: $e');
        }
      }

      // 5. 同步完成，导航到主页面
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('同步失败: $e')));
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _handleLegacyProgress(double progress) {
    if (!mounted) return;
    final normalized = progress.clamp(0.0, 1.0).toDouble();
    setState(() {
      _syncProgress = normalized;
      _syncDetail = _syncDetail.copyWith(progress: normalized);
    });
  }

  void _handleDetailedProgress(InitialSyncProgress progress) {
    if (!mounted) return;
    setState(() {
      _syncProgress = progress.progress;
      _syncDetail = progress;
    });
  }

  void _showRealtimeStage() {
    if (!mounted) return;
    _handleDetailedProgress(
      _syncDetail.copyWith(
        stage: InitialSyncStage.enablingRealtime,
        progress: 1.0,
        statusMessage: '正在启用实时同步',
      ),
    );
  }
}
