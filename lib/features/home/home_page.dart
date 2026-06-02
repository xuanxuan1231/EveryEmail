import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/local/database/app_database.dart';
import '../../data/local/database/message_with_account.dart';
import '../../domain/enums/message_enums.dart';
import '../../domain/models/account_config.dart';
import 'widgets/gmail_mobile_message_item.dart';

/// 主页面（移动端布局）。
///
/// 布局：
/// - 主界面：邮件列表（Gmail 风格卡片）
/// - 侧边栏：文件夹树（统一收件箱 + 各账户文件夹）
/// - 详情页：独立路由页面
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _selectedFolderId;
  String? _selectedAccountId;
  String? _selectedFolderName; // 缓存选中的文件夹名称
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isUnifiedInbox => _selectedFolderId == null && _selectedAccountId == null;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return _buildEmptyState(context);
        }
        return _buildMainLayout(context, accounts);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('加载失败: $error'),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mail_outline,
                size: 120,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                '欢迎使用 EveryEmail',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '添加邮箱账户开始使用',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.push('/onboarding/add'),
                icon: const Icon(Icons.add),
                label: const Text('添加账户'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainLayout(BuildContext context, List<Account> accounts) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text(_getFolderTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              context.push('/search');
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: 更多选项
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, accounts),
      body: _MessageList(
        folderId: _selectedFolderId,
        accountId: _selectedAccountId,
        onMessageTap: (messageId) {
          context.push('/message/$messageId');
        },
        onRefresh: () async {
          // 触发同步
          final syncService = ref.read(syncServiceProvider);
          if (_isUnifiedInbox) {
            // 同步所有账户
            for (final account in accounts) {
              await _syncAccount(syncService, account);
            }
          } else if (_selectedAccountId != null) {
            // 同步选中的账户
            final account = accounts.firstWhere((a) => a.id == _selectedAccountId);
            await _syncAccount(syncService, account);
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 撰写邮件
        },
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, List<Account> accounts) {
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'EveryEmail',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${accounts.length} 个账户',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 统一收件箱
                ListTile(
                  leading: const Icon(Icons.inbox),
                  title: const Text('统一收件箱'),
                  selected: _isUnifiedInbox,
                  onTap: () {
                    setState(() {
                      _selectedFolderId = null;
                      _selectedAccountId = null;
                      _selectedFolderName = null;
                    });
                    Navigator.pop(context);
                  },
                ),
                const Divider(),

                // 各账户
                ...accounts.map((account) {
                  final isAccountSelected = _selectedAccountId == account.id && _selectedFolderId == null;

                  return Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(account.colorValue ?? Colors.blue.toARGB32()),
                        radius: 16,
                        child: Text(
                          account.email[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      title: Text(
                        account.displayName,
                        style: TextStyle(
                          fontWeight: isAccountSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        account.email,
                        style: theme.textTheme.bodySmall,
                      ),
                      backgroundColor: isAccountSelected
                          ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
                          : null,
                      collapsedBackgroundColor: isAccountSelected
                          ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
                          : null,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      childrenPadding: EdgeInsets.zero,
                      children: [
                        // 显示该账户的所有文件夹
                        _buildAccountFolders(context, account, theme),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('添加账户'),
            onTap: () {
              Navigator.pop(context);
              context.push('/onboarding/add');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 设置页面
            },
          ),
        ],
      ),
    );
  }

  /// 构建账户的文件夹列表。
  Widget _buildAccountFolders(BuildContext context, Account account, ThemeData theme) {
    final db = ref.read(databaseProvider);

    return StreamBuilder<List<Folder>>(
      stream: db.folderDao.watchFolders(account.id),
      builder: (context, snapshot) {
        final folders = snapshot.data ?? [];

        if (folders.isEmpty) {
          return ListTile(
            leading: const SizedBox(width: 16),
            title: const Text('暂无文件夹'),
            dense: true,
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
          );
        }

        return Column(
          children: folders.map((folder) {
            final isFolderSelected = _selectedFolderId == folder.id;

            return ListTile(
              leading: Icon(
                _getFolderIcon(folder.folderType),
                size: 20,
              ),
              title: Text(folder.displayName),
              trailing: folder.unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${folder.unreadCount}',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
              dense: true,
              selected: isFolderSelected,
              selectedTileColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
              shape: const Border(),
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
              onTap: () {
                setState(() {
                  _selectedAccountId = account.id;
                  _selectedFolderId = folder.id;
                  _selectedFolderName = folder.displayName;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  /// 获取文件夹图标。
  IconData _getFolderIcon(FolderType type) {
    switch (type) {
      case FolderType.inbox:
        return Icons.inbox;
      case FolderType.sent:
        return Icons.send;
      case FolderType.drafts:
        return Icons.drafts;
      case FolderType.archive:
        return Icons.archive;
      case FolderType.spam:
        return Icons.report;
      case FolderType.trash:
        return Icons.delete;
      case FolderType.custom:
        return Icons.folder;
    }
  }

  String _getFolderTitle() {
    if (_isUnifiedInbox) {
      return '统一收件箱';
    }
    if (_selectedAccountId != null && _selectedFolderId == null) {
      return '账户收件箱';
    }
    if (_selectedFolderId != null && _selectedFolderName != null) {
      return _selectedFolderName!;
    }
    return '收件箱';
  }

  Future<void> _syncAccount(dynamic syncService, Account account) async {
    try {
      final accountConfig = AccountConfig(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        type: account.accountType,
        authType: account.authType,
        secretRef: account.secretRef,
        imap: account.imapHost != null
            ? ServerConfig(
                host: account.imapHost!,
                port: account.imapPort!,
                socketType: account.imapSocketType!,
              )
            : null,
        smtp: account.smtpHost != null
            ? ServerConfig(
                host: account.smtpHost!,
                port: account.smtpPort!,
                socketType: account.smtpSocketType!,
              )
            : null,
        colorValue: account.colorValue,
      );
      await syncService.syncAccount(accountConfig);
    } catch (e) {
      debugPrint('同步账户失败: $e');
    }
  }
}

/// 邮件列表组件（移动端优化）。
class _MessageList extends ConsumerWidget {
  const _MessageList({
    required this.folderId,
    required this.accountId,
    required this.onMessageTap,
    required this.onRefresh,
  });

  final String? folderId;
  final String? accountId;
  final ValueChanged<String> onMessageTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // 统一收件箱
    if (folderId == null && accountId == null) {
      return _buildUnifiedInbox(context, ref, theme);
    }

    // 单个账户的收件箱
    if (accountId != null && folderId == null) {
      return _buildAccountInbox(context, ref, theme);
    }

    // 特定文件夹
    if (folderId != null) {
      return _buildFolderView(context, ref, theme);
    }

    return Center(
      child: Text(
        '请选择文件夹',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildUnifiedInbox(BuildContext context, WidgetRef ref, ThemeData theme) {
    final unifiedInboxAsync = ref.watch(unifiedInboxProvider);

    return unifiedInboxAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return _buildEmptyMessages(theme);
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: _buildMessageListView(messages, theme),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(theme, error),
    );
  }

  Widget _buildAccountInbox(BuildContext context, WidgetRef ref, ThemeData theme) {
    final accountMessagesAsync = ref.watch(accountMessagesProvider(accountId!));

    return accountMessagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return _buildEmptyMessages(theme);
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: _buildAccountMessageListView(messages, theme),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(theme, error),
    );
  }

  Widget _buildFolderView(BuildContext context, WidgetRef ref, ThemeData theme) {
    final db = ref.watch(databaseProvider);
    final messagesStream = db.messageDao.watchFolderMessages(folderId!);

    return StreamBuilder<List<Message>>(
      stream: messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(theme, snapshot.error!);
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return _buildEmptyMessages(theme);
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: _buildAccountMessageListView(messages, theme),
        );
      },
    );
  }

  Widget _buildMessageListView(List<MessageWithAccount> messages, ThemeData theme) {
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final item = messages[index];
        final message = item.message;

        return GmailMobileMessageItem(
          message: message,
          onTap: () => onMessageTap(message.id),
          accountEmail: item.accountEmail,
          accountColor: item.accountColorValue != null
              ? Color(item.accountColorValue!)
              : null,
          showAccountLabel: true,
          onStarTap: () {
            // TODO: 实现星标切换
            debugPrint('切换星标: ${message.id}');
          },
          onLongPress: () {
            // TODO: 实现长按选择
            debugPrint('长按选择: ${message.id}');
          },
        );
      },
    );
  }

  Widget _buildAccountMessageListView(List<Message> messages, ThemeData theme) {
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];

        return GmailMobileMessageItem(
          message: message,
          onTap: () => onMessageTap(message.id),
          showAccountLabel: false,
          onStarTap: () {
            // TODO: 实现星标切换
            debugPrint('切换星标: ${message.id}');
          },
          onLongPress: () {
            // TODO: 实现长按选择
            debugPrint('长按选择: ${message.id}');
          },
        );
      },
    );
  }

  Widget _buildErrorState(ThemeData theme, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 没邮件时仍然支持下拉刷新：用 always-scrollable physics + 撑满高度的占位。
  Widget _buildEmptyMessages(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '没有邮件',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '下拉刷新',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
