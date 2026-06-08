import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';

import '../../app/providers.dart';
import '../../core/navigation/predictive_back_shared_element.dart';
import '../../core/theme/mail_list_colors.dart';
import '../../core/theme/theme_ext.dart';
import '../../data/local/database/app_database.dart';
import '../../data/local/database/message_with_account.dart';
import '../../data/settings/display_settings.dart';
import '../../domain/enums/message_enums.dart';
import '../../domain/models/account_config.dart';
import '../../domain/models/unified_mailbox.dart';
import 'widgets/gmail_mobile_message_item.dart';

/// 主页面（移动端布局）。
///
/// 布局：
/// - 主界面：邮件列表（Gmail 风格卡片）
/// - 侧边栏：账户切换器（统一账户 + 各真实账户）与对应文件夹树
/// - 详情页：独立路由页面
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _MailboxAccountItem {
  const _MailboxAccountItem({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.colorValue,
    this.realAccount,
  });

  factory _MailboxAccountItem.unified(int realAccountCount) {
    return _MailboxAccountItem(
      id: UnifiedMailbox.account.id,
      displayName: UnifiedMailbox.account.displayName,
      subtitle: '$realAccountCount 个账户',
      colorValue: UnifiedMailbox.account.colorValue,
    );
  }

  factory _MailboxAccountItem.real(Account account) {
    return _MailboxAccountItem(
      id: account.id,
      displayName: account.displayName,
      subtitle: account.email,
      colorValue: account.colorValue,
      realAccount: account,
    );
  }

  final String id;
  final String displayName;
  final String subtitle;
  final int? colorValue;
  final Account? realAccount;

  bool get isUnified => realAccount == null;
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _selectedFolderId = UnifiedMailbox.inbox.id;
  String? _selectedAccountId = UnifiedMailbox.account.id;
  String? _selectedFolderName = UnifiedMailbox.inbox.title; // 缓存选中的文件夹名称
  String? _drawerAccountId = UnifiedMailbox.account.id;
  final ValueNotifier<bool> _isAccountSwitcherOpen = ValueNotifier(false);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  UnifiedMailboxFolder? get _selectedUnifiedFolder {
    if (!UnifiedMailbox.isUnifiedAccountId(_selectedAccountId)) return null;
    return UnifiedMailbox.folderById(_selectedFolderId);
  }

  @override
  void dispose() {
    _isAccountSwitcherOpen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 选中的真实账户被删除后，回退到统一收件箱：否则会停留在空邮件列表，
    // 且下拉刷新里按 _selectedAccountId 查找账户会失败。
    ref.listen(accountsStreamProvider, (previous, next) {
      next.whenData((accounts) {
        final selectedId = _selectedAccountId;
        if (selectedId == null ||
            UnifiedMailbox.isUnifiedAccountId(selectedId)) {
          return;
        }
        if (accounts.any((account) => account.id == selectedId)) return;
        setState(() {
          _selectedAccountId = UnifiedMailbox.account.id;
          _selectedFolderId = UnifiedMailbox.inbox.id;
          _selectedFolderName = UnifiedMailbox.inbox.title;
          _drawerAccountId = UnifiedMailbox.account.id;
        });
      });
    });

    final accountsAsync = ref.watch(accountsStreamProvider);

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return _buildEmptyState(context);
        }
        return _buildMainLayout(context, accounts);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('加载失败: $error'))),
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
              Text('欢迎使用 EveryEmail', style: theme.textTheme.headlineMedium),
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
      drawer: _buildDrawer(context, accounts),
      body: _MessageList(
        title: _getFolderTitle(),
        subtitle: _getFolderSubtitle(accounts),
        unifiedFolder: _selectedUnifiedFolder,
        folderId: _selectedFolderId,
        accountId: _selectedAccountId,
        onMenuTap: () {
          _scaffoldKey.currentState?.openDrawer();
        },
        onSearchTap: () {
          context.push('/search');
        },
        onMessageTap: (message) {
          // 点击即抢先下载正文（高优先级），与导航转场重叠，争取点开即见内容。
          ref.read(bodyPrefetchServiceProvider).enqueueOnTap(message.id);
          context.push(
            '/message/${Uri.encodeComponent(message.id)}',
            extra: message,
          );
        },
        onRefresh: () async {
          // 触发同步
          final syncService = ref.read(syncServiceProvider);
          if (_selectedUnifiedFolder != null) {
            // 同步所有账户
            for (final account in accounts) {
              await _syncAccount(syncService, account);
            }
          } else if (_selectedAccountId != null) {
            // 同步选中的账户（若已被删除则跳过，避免查找失败）。
            for (final account in accounts) {
              if (account.id == _selectedAccountId) {
                await _syncAccount(syncService, account);
                break;
              }
            }
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
    final colors = theme.colorScheme;
    final drawerWidth = (MediaQuery.sizeOf(context).width * 0.88)
        .clamp(304.0, 360.0)
        .toDouble();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Drawer(
      width: drawerWidth,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: context.shapes.extraLarge.topRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildDrawerHeader(context, accounts.length),
          Expanded(child: _buildDrawerMiddleSpace(context, accounts, theme)),
          _buildDrawerActions(context, bottomInset),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, int accountCount) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: context.shapes.large,
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.52),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: context.shapes.medium,
                ),
                child: Icon(
                  Icons.mark_email_unread_rounded,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'EveryEmail',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$accountCount 个账户',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerMiddleSpace(
    BuildContext context,
    List<Account> accounts,
    ThemeData theme,
  ) {
    final accountItems = _buildMailboxAccountItems(accounts);
    final account = _currentDrawerAccount(accountItems);

    return Stack(
      children: [
        Column(
          children: [
            _buildAccountSwitcher(
              context,
              account,
              accountItems,
              expanded: false,
            ),
            Expanded(child: _buildFolderListPanel(context, account, theme)),
          ],
        ),
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: _isAccountSwitcherOpen,
            child: _buildAccountDropdownOverlay(context, account, accountItems),
            builder: (context, isOpen, child) {
              return _buildAccountDropdownTransition(context, isOpen, child!);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountDropdownTransition(
    BuildContext context,
    bool isOpen,
    Widget child,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isOpen ? 1 : 0),
      duration: context.motion.medium,
      curve: isOpen
          ? context.motion.emphasizedDecelerate
          : context.motion.emphasizedAccelerate,
      builder: (context, progress, child) {
        final easedProgress = progress.clamp(0.0, 1.0);

        return IgnorePointer(
          ignoring: !isOpen,
          child: ExcludeSemantics(
            excluding: easedProgress == 0,
            child: Opacity(
              opacity: easedProgress,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight * easedProgress,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minWidth: constraints.maxWidth,
                          maxWidth: constraints.maxWidth,
                          minHeight: constraints.maxHeight,
                          maxHeight: constraints.maxHeight,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildAccountSwitcher(
    BuildContext context,
    _MailboxAccountItem account,
    List<_MailboxAccountItem> accounts, {
    required bool expanded,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: M3ECardList(
        itemCount: 1,
        padding: EdgeInsets.zero,
        outerRadius: 24,
        innerRadius: 4,
        color: expanded
            ? colors.secondaryContainer.withValues(alpha: 0.48)
            : colors.surfaceContainerHighest,
        splashColor: colors.primary.withValues(alpha: 0.08),
        highlightColor: colors.primary.withValues(alpha: 0.04),
        itemBuilder: (context, index) {
          return SizedBox(
            height: 76,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 14),
                  child: InkResponse(
                    onTap: () => _cycleDrawerAccount(accounts),
                    radius: 30,
                    child: _buildAccountAvatar(
                      account,
                      radius: 22,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _toggleAccountSwitcher,
                    borderRadius: context.shapes.medium,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            account.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleAccountSwitcher,
                  icon: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: context.motion.short,
                    curve: context.motion.standard,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountDropdownOverlay(
    BuildContext context,
    _MailboxAccountItem currentAccount,
    List<_MailboxAccountItem> accounts, {
    Key? key,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ColoredBox(
      key: key,
      color: colors.surface,
      child: Column(
        children: [
          _buildAccountSwitcher(
            context,
            currentAccount,
            accounts,
            expanded: true,
          ),
          Expanded(
            child: M3ECardList.builder(
              itemCount: accounts.length,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              listPadding: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.zero,
              outerRadius: 24,
              innerRadius: 4,
              gap: 3,
              color: colors.surfaceContainerHighest,
              splashColor: colors.primary.withValues(alpha: 0.08),
              highlightColor: colors.primary.withValues(alpha: 0.04),
              haptic: M3EHapticFeedback.light,
              semanticLabelBuilder: (index) => accounts[index].displayName,
              onTap: (index) {
                _selectDrawerAccount(accounts[index], closeSwitcher: true);
              },
              itemBuilder: (context, index) {
                final account = accounts[index];
                return _buildAccountOptionRow(
                  context,
                  account,
                  selected: account.id == currentAccount.id,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderListPanel(
    BuildContext context,
    _MailboxAccountItem account,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          account.isUnified
              ? _buildUnifiedFolders(context, theme, margin: EdgeInsets.zero)
              : _buildAccountFolders(context, account.realAccount!, theme),
        ],
      ),
    );
  }

  Widget _buildUnifiedFolders(
    BuildContext context,
    ThemeData theme, {
    EdgeInsetsGeometry margin = const EdgeInsets.symmetric(horizontal: 16),
  }) {
    final db = ref.read(databaseProvider);

    return StreamBuilder<List<UnifiedMailboxFolder>>(
      stream: db.folderDao.watchUnifiedFolders(),
      builder: (context, snapshot) {
        final folders = snapshot.data ?? UnifiedMailbox.folders;

        return M3ECardList(
          itemCount: folders.length,
          margin: margin,
          padding: EdgeInsets.zero,
          outerRadius: 18,
          innerRadius: 4,
          gap: 2,
          color: theme.colorScheme.surfaceContainerLow,
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
          haptic: M3EHapticFeedback.light,
          semanticLabelBuilder: (index) => folders[index].title,
          onTap: (index) {
            final folder = folders[index];
            _isAccountSwitcherOpen.value = false;
            setState(() {
              _drawerAccountId = UnifiedMailbox.account.id;
              _selectedAccountId = UnifiedMailbox.account.id;
              _selectedFolderId = folder.id;
              _selectedFolderName = folder.title;
            });
            Navigator.pop(context);
          },
          itemBuilder: (context, index) {
            final folder = folders[index];
            final isSelected =
                UnifiedMailbox.isUnifiedAccountId(_selectedAccountId) &&
                _selectedFolderId == folder.id;

            return _buildDrawerRow(
              context,
              icon: _getFolderIcon(folder.type),
              title: folder.displayName,
              subtitle: folder.sourceAccountCount == 0
                  ? '暂无来源'
                  : '${folder.sourceAccountCount} 个来源账户',
              trailing: folder.unreadCount > 0
                  ? _buildUnreadBadge(context, folder.unreadCount)
                  : null,
              selected: isSelected,
              compact: true,
            );
          },
        );
      },
    );
  }

  Widget _buildAccountOptionRow(
    BuildContext context,
    _MailboxAccountItem account, {
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurface;
    final secondary = selected
        ? colors.onSecondaryContainer.withValues(alpha: 0.78)
        : colors.onSurfaceVariant;

    return AnimatedContainer(
      duration: context.motion.short,
      curve: context.motion.standard,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: selected
            ? colors.secondaryContainer.withValues(alpha: 0.78)
            : Colors.transparent,
        borderRadius: selected ? BorderRadius.zero : context.shapes.medium,
      ),
      child: Row(
        children: [
          _buildAccountAvatar(account, radius: 18, fontSize: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondary,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 12),
            Icon(Icons.check_rounded, color: colors.onSecondaryContainer),
          ],
        ],
      ),
    );
  }

  List<_MailboxAccountItem> _buildMailboxAccountItems(List<Account> accounts) {
    return [
      _MailboxAccountItem.unified(accounts.length),
      for (final account in accounts) _MailboxAccountItem.real(account),
    ];
  }

  _MailboxAccountItem _currentDrawerAccount(
    List<_MailboxAccountItem> accounts,
  ) {
    for (final id in <String?>[_drawerAccountId, _selectedAccountId]) {
      if (id == null) continue;
      for (final account in accounts) {
        if (account.id == id) return account;
      }
    }

    return accounts.first;
  }

  void _toggleAccountSwitcher() {
    _isAccountSwitcherOpen.value = !_isAccountSwitcherOpen.value;
  }

  Future<void> _cycleDrawerAccount(List<_MailboxAccountItem> accounts) async {
    final current = _currentDrawerAccount(accounts);
    final currentIndex = accounts.indexWhere((account) {
      return account.id == current.id;
    });
    final nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + 1) % accounts.length;

    await _selectDrawerAccount(accounts[nextIndex]);
  }

  Future<void> _selectDrawerAccount(
    _MailboxAccountItem account, {
    bool closeSwitcher = false,
  }) async {
    if (account.isUnified) {
      if (closeSwitcher) {
        _isAccountSwitcherOpen.value = false;
      }
      setState(() {
        _drawerAccountId = UnifiedMailbox.account.id;
        _selectedAccountId = UnifiedMailbox.account.id;
        _selectedFolderId = UnifiedMailbox.inbox.id;
        _selectedFolderName = UnifiedMailbox.inbox.title;
      });
      return;
    }

    final realAccount = account.realAccount;
    if (realAccount == null) return;
    if (closeSwitcher) {
      _isAccountSwitcherOpen.value = false;
    }

    setState(() {
      _drawerAccountId = account.id;
    });

    final folder = await _preferredFolderForAccount(realAccount);
    if (!mounted) return;

    setState(() {
      _drawerAccountId = account.id;
      _selectedAccountId = account.id;
      _selectedFolderId = folder?.id;
      _selectedFolderName = folder?.displayName ?? '收件箱';
    });
  }

  Future<Folder?> _preferredFolderForAccount(Account account) async {
    final db = ref.read(databaseProvider);
    final folders = await db.folderDao.getFolders(account.id);

    for (final folder in folders) {
      if (folder.folderType == FolderType.inbox) {
        return folder;
      }
    }

    return folders.isEmpty ? null : folders.first;
  }

  Widget _buildDrawerActions(BuildContext context, double bottomInset) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.64)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 12),
        child: M3ECardList(
          itemCount: 2,
          padding: EdgeInsets.zero,
          outerRadius: 24,
          innerRadius: 4,
          gap: 3,
          color: colors.surfaceContainerHighest,
          splashColor: colors.primary.withValues(alpha: 0.08),
          highlightColor: colors.primary.withValues(alpha: 0.04),
          haptic: M3EHapticFeedback.light,
          semanticLabelBuilder: (index) => index == 0 ? '添加账户' : '设置',
          onTap: (index) {
            Navigator.pop(context);
            if (index == 0) {
              context.push('/onboarding/add');
            } else {
              context.push('/settings');
            }
          },
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildDrawerRow(
                context,
                icon: Icons.add_circle_outline_rounded,
                title: '添加账户',
              );
            }

            return _buildDrawerRow(
              context,
              icon: Icons.settings_outlined,
              title: '设置',
            );
          },
        ),
      ),
    );
  }

  /// 构建账户的文件夹列表。
  Widget _buildAccountFolders(
    BuildContext context,
    Account account,
    ThemeData theme,
  ) {
    final db = ref.read(databaseProvider);

    return StreamBuilder<List<Folder>>(
      stream: db.folderDao.watchFolders(account.id),
      builder: (context, snapshot) {
        // 隐藏被用户关闭「显示文件夹」的文件夹（管理文件夹页仍可见以便重新开启）。
        final folders = (snapshot.data ?? [])
            .where((folder) => folder.visible)
            .toList();

        if (folders.isEmpty) {
          return M3ECardList(
            itemCount: 1,
            padding: EdgeInsets.zero,
            outerRadius: 18,
            innerRadius: 4,
            color: theme.colorScheme.surfaceContainerLow,
            itemBuilder: (context, index) {
              return _buildDrawerRow(
                context,
                icon: Icons.folder_off_outlined,
                title: '暂无文件夹',
                compact: true,
                enabled: false,
              );
            },
          );
        }

        return M3ECardList(
          itemCount: folders.length,
          padding: EdgeInsets.zero,
          outerRadius: 18,
          innerRadius: 4,
          gap: 2,
          color: theme.colorScheme.surfaceContainerLow,
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
          haptic: M3EHapticFeedback.light,
          semanticLabelBuilder: (index) => folders[index].displayName,
          onTap: (index) {
            final folder = folders[index];
            _isAccountSwitcherOpen.value = false;
            setState(() {
              _drawerAccountId = account.id;
              _selectedAccountId = account.id;
              _selectedFolderId = folder.id;
              _selectedFolderName = folder.displayName;
            });
            Navigator.pop(context);
          },
          itemBuilder: (context, index) {
            final folder = folders[index];
            final isFolderSelected = _selectedFolderId == folder.id;

            return _buildDrawerRow(
              context,
              icon: _getFolderIcon(folder.folderType),
              title: folder.displayName,
              trailing: folder.unreadCount > 0
                  ? _buildUnreadBadge(context, folder.unreadCount)
                  : null,
              selected: isFolderSelected,
              compact: true,
            );
          },
        );
      },
    );
  }

  Widget _buildDrawerRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool selected = false,
    bool compact = false,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected
        ? colors.onSecondaryContainer
        : enabled
        ? colors.onSurface
        : colors.onSurfaceVariant.withValues(alpha: 0.72);
    final secondary = selected
        ? colors.onSecondaryContainer.withValues(alpha: 0.78)
        : colors.onSurfaceVariant;

    return AnimatedContainer(
      duration: context.motion.short,
      curve: context.motion.standard,
      constraints: BoxConstraints(minHeight: compact ? 46 : 58),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: subtitle == null ? (compact ? 10 : 12) : 10,
      ),
      decoration: BoxDecoration(
        color: selected
            ? colors.secondaryContainer.withValues(alpha: 0.78)
            : Colors.transparent,
        borderRadius: selected
            ? BorderRadius.zero
            : compact
            ? context.shapes.small
            : context.shapes.large,
      ),
      child: Row(
        children: [
          Icon(icon, size: compact ? 20 : 22, color: foreground),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact
                              ? theme.textTheme.bodyMedium
                              : theme.textTheme.titleSmall)
                          ?.copyWith(
                            color: foreground,
                            fontWeight: selected
                                ? FontWeight.w700
                                : compact
                                ? FontWeight.w500
                                : FontWeight.w600,
                            letterSpacing: 0,
                          ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondary,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
        ],
      ),
    );
  }

  Widget _buildAccountAvatar(
    _MailboxAccountItem account, {
    double radius = 17,
    double fontSize = 13,
  }) {
    final color = Color(account.colorValue ?? Colors.blue.toARGB32());

    if (account.isUnified) {
      return CircleAvatar(
        backgroundColor: color,
        radius: radius,
        child: Icon(
          Icons.all_inbox_rounded,
          color: Colors.white,
          size: radius * 1.08,
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: color,
      radius: radius,
      child: Text(
        _accountInitial(account),
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(BuildContext context, int unreadCount) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: context.shapes.small,
      ),
      child: Text(
        '$unreadCount',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }

  String _accountInitial(_MailboxAccountItem account) {
    final displayName = account.displayName.trim();
    if (displayName.isNotEmpty) {
      return displayName.characters.first.toUpperCase();
    }

    final subtitle = account.subtitle.trim();
    if (subtitle.isNotEmpty) {
      return subtitle.characters.first.toUpperCase();
    }

    return '?';
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
    final unifiedFolder = _selectedUnifiedFolder;
    if (unifiedFolder != null) {
      return unifiedFolder.title;
    }
    if (_selectedAccountId != null && _selectedFolderId == null) {
      return _selectedFolderName ?? '账户邮件';
    }
    if (_selectedFolderId != null && _selectedFolderName != null) {
      return _selectedFolderName!;
    }
    return '收件箱';
  }

  String? _getFolderSubtitle(List<Account> accounts) {
    if (UnifiedMailbox.isUnifiedAccountId(_selectedAccountId)) {
      return null;
    }

    for (final account in accounts) {
      if (account.id == _selectedAccountId) {
        return '${account.displayName} (${account.email})';
      }
    }

    return null;
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

enum _MessageListMenuAction {
  selectAll,
  markAllRead,
  archiveSelected,
  flagSelected,
  unflagSelected,
  clearSelection,
}

/// 邮件列表组件（移动端优化）。
class _MessageList extends ConsumerStatefulWidget {
  const _MessageList({
    required this.title,
    required this.subtitle,
    required this.unifiedFolder,
    required this.folderId,
    required this.accountId,
    required this.onMenuTap,
    required this.onSearchTap,
    required this.onMessageTap,
    required this.onRefresh,
  });

  @override
  ConsumerState<_MessageList> createState() => _MessageListState();

  final String title;
  final String? subtitle;
  final UnifiedMailboxFolder? unifiedFolder;
  final String? folderId;
  final String? accountId;
  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;
  final ValueChanged<Message> onMessageTap;
  final Future<void> Function() onRefresh;
}

class _MessageListState extends ConsumerState<_MessageList> {
  static const double _mediumAppBarExpandedHeight = 112;
  static const double _mediumAppBarCollapsedHeight = 64;
  static const double _mediumAppBarCollapseDistance =
      _mediumAppBarExpandedHeight - _mediumAppBarCollapsedHeight;

  final Set<String> _selectedMessageIds = <String>{};
  bool _batchInProgress = false;

  String get title => widget.title;
  String? get subtitle => widget.subtitle;
  UnifiedMailboxFolder? get unifiedFolder => widget.unifiedFolder;
  String? get folderId => widget.folderId;
  String? get accountId => widget.accountId;
  VoidCallback get onMenuTap => widget.onMenuTap;
  VoidCallback get onSearchTap => widget.onSearchTap;
  ValueChanged<Message> get onMessageTap => widget.onMessageTap;
  Future<void> Function() get onRefresh => widget.onRefresh;

  @override
  void didUpdateWidget(covariant _MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUnifiedFolderId = oldWidget.unifiedFolder?.id;
    final nextUnifiedFolderId = widget.unifiedFolder?.id;
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.folderId != widget.folderId ||
        oldUnifiedFolderId != nextUnifiedFolderId) {
      _selectedMessageIds.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displaySettings = ref.watch(displaySettingsProvider);
    late final Widget content;

    // 统一账户下的聚合文件夹
    if (unifiedFolder != null) {
      content = _buildUnifiedFolder(
        context,
        ref,
        theme,
        unifiedFolder!,
        displaySettings,
      );
    }
    // 单个真实账户的邮件聚合视图
    else if (accountId != null && folderId == null) {
      content = _buildAccountInbox(context, ref, theme, displaySettings);
    }
    // 特定文件夹
    else if (folderId != null) {
      content = _buildFolderView(context, ref, theme, displaySettings);
    } else {
      content = _buildStatusScrollView(
        theme,
        Center(
          child: Text(
            '请选择文件夹',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: _selectedMessageIds.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedMessageIds.isNotEmpty) {
          _clearSelection();
        }
      },
      child: content,
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, List<Message> visibleMessages) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final collapsed =
            constraints.scrollOffset >= _mediumAppBarCollapseDistance;
        final selectedMessages = _selectedMessagesFrom(visibleMessages);
        final selectedCount = _selectedMessageIds.length;
        final selectionMode = selectedCount > 0;
        final markSelectionAsRead = selectedMessages.any((m) => !_isRead(m));

        return SliverAppBar.medium(
          pinned: true,
          backgroundColor: collapsed
              ? mailListAppBarSurfaceColor(theme)
              : theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          shape: collapsed
              ? Border(
                  bottom: BorderSide(color: mailListAppBarDividerColor(theme)),
                )
              : null,
          leading: IconButton(
            icon: Icon(selectionMode ? Icons.close : Icons.menu),
            tooltip: selectionMode ? '取消选择' : '菜单',
            onPressed: selectionMode ? _clearSelection : onMenuTap,
          ),
          title: selectionMode
              ? Text('已选择 $selectedCount 封')
              : _buildAppBarTitle(theme),
          actions: [
            if (!selectionMode)
              IconButton(icon: const Icon(Icons.search), onPressed: onSearchTap)
            else ...[
              IconButton(
                icon: Icon(
                  markSelectionAsRead
                      ? Icons.mark_email_read_outlined
                      : Icons.mark_email_unread_outlined,
                ),
                tooltip: markSelectionAsRead ? '标为已读' : '标为未读',
                onPressed: selectedMessages.isEmpty || _batchInProgress
                    ? null
                    : () => _setReadForMessages(
                        context,
                        selectedMessages,
                        read: markSelectionAsRead,
                      ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除',
                onPressed: selectedMessages.isEmpty || _batchInProgress
                    ? null
                    : () => _deleteMessages(context, selectedMessages),
              ),
            ],
            PopupMenuButton<_MessageListMenuAction>(
              tooltip: '更多',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) =>
                  _handleMenuAction(context, visibleMessages, value),
              itemBuilder: (context) => selectionMode
                  ? _buildSelectionMenuItems(visibleMessages, selectedMessages)
                  : _buildListMenuItems(visibleMessages),
            ),
          ],
        );
      },
    );
  }

  List<PopupMenuEntry<_MessageListMenuAction>> _buildListMenuItems(
    List<Message> visibleMessages,
  ) {
    final hasUnread = visibleMessages.any((m) => !_isRead(m));
    return [
      PopupMenuItem<_MessageListMenuAction>(
        value: _MessageListMenuAction.selectAll,
        enabled: visibleMessages.isNotEmpty,
        child: const Row(
          children: [
            Icon(Icons.select_all_outlined),
            SizedBox(width: 12),
            Text('全选'),
          ],
        ),
      ),
      PopupMenuItem<_MessageListMenuAction>(
        value: _MessageListMenuAction.markAllRead,
        enabled: hasUnread && !_batchInProgress,
        child: const Row(
          children: [
            Icon(Icons.mark_email_read_outlined),
            SizedBox(width: 12),
            Text('全部标为已读'),
          ],
        ),
      ),
    ];
  }

  List<PopupMenuEntry<_MessageListMenuAction>> _buildSelectionMenuItems(
    List<Message> visibleMessages,
    List<Message> selectedMessages,
  ) {
    final allVisibleSelected =
        visibleMessages.isNotEmpty &&
        visibleMessages.every(
          (message) => _selectedMessageIds.contains(message.id),
        );
    final enabled = selectedMessages.isNotEmpty && !_batchInProgress;

    return [
      PopupMenuItem<_MessageListMenuAction>(
        value: _MessageListMenuAction.selectAll,
        enabled: visibleMessages.isNotEmpty && !allVisibleSelected,
        child: const Row(
          children: [
            Icon(Icons.select_all_outlined),
            SizedBox(width: 12),
            Text('全选'),
          ],
        ),
      ),
      PopupMenuItem<_MessageListMenuAction>(
        value: _MessageListMenuAction.archiveSelected,
        enabled: enabled,
        child: const Row(
          children: [
            Icon(Icons.archive_outlined),
            SizedBox(width: 12),
            Text('归档'),
          ],
        ),
      ),
      PopupMenuItem<_MessageListMenuAction>(
        value: _MessageListMenuAction.flagSelected,
        enabled: enabled,
        child: const Row(
          children: [
            Icon(Icons.star_border_outlined),
            SizedBox(width: 12),
            Text('加星标'),
          ],
        ),
      ),
      PopupMenuItem<_MessageListMenuAction>(
        value: _MessageListMenuAction.unflagSelected,
        enabled: enabled,
        child: const Row(
          children: [
            Icon(Icons.star_outline),
            SizedBox(width: 12),
            Text('取消星标'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<_MessageListMenuAction>(
        value: _MessageListMenuAction.clearSelection,
        child: Row(
          children: [Icon(Icons.close), SizedBox(width: 12), Text('取消选择')],
        ),
      ),
    ];
  }

  Widget _buildAppBarTitle(ThemeData theme) {
    final subtitle = this.subtitle;
    if (subtitle == null || subtitle.isEmpty) {
      return Text(title, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 1),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusScrollView(
    ThemeData theme,
    Widget child, {
    bool refreshable = false,
    List<Message> visibleMessages = const <Message>[],
  }) {
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildSliverAppBar(theme, visibleMessages),
        SliverFillRemaining(hasScrollBody: false, child: child),
      ],
    );

    if (!refreshable) return scrollView;

    return RefreshIndicator(onRefresh: onRefresh, child: scrollView);
  }

  Widget _buildMessageScrollView(
    ThemeData theme,
    List<Message> visibleMessages,
    List<Widget> slivers,
  ) {
    final topGap = subtitle == null || subtitle!.isEmpty ? 8.0 : 14.0;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildSliverAppBar(theme, visibleMessages),
          SliverToBoxAdapter(child: SizedBox(height: topGap)),
          ...slivers,
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }

  Widget _buildUnifiedFolder(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    UnifiedMailboxFolder folder,
    DisplaySettings displaySettings,
  ) {
    final unifiedFolderAsync = ref.watch(
      unifiedFolderMessagesProvider(folder.type),
    );

    return unifiedFolderAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return _buildEmptyMessages(theme);
        }

        return _buildMessageListView(messages, theme, displaySettings);
      },
      loading: () => _buildStatusScrollView(
        theme,
        const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => _buildErrorState(theme, error),
    );
  }

  Widget _buildAccountInbox(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    DisplaySettings displaySettings,
  ) {
    final accountMessagesAsync = ref.watch(accountMessagesProvider(accountId!));

    return accountMessagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return _buildEmptyMessages(theme);
        }

        return _buildAccountMessageListView(messages, theme, displaySettings);
      },
      loading: () => _buildStatusScrollView(
        theme,
        const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => _buildErrorState(theme, error),
    );
  }

  Widget _buildFolderView(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    DisplaySettings displaySettings,
  ) {
    // 用 folderMessagesProvider（跨重建缓存）而非内联 StreamBuilder：返回详情页
    // 时不会重订阅、闪 loading，从而保住列表滚动位置（预见式返回动画才连贯）。
    final folderMessagesAsync = ref.watch(folderMessagesProvider(folderId!));

    return folderMessagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return _buildEmptyMessages(theme);
        }

        return _buildAccountMessageListView(messages, theme, displaySettings);
      },
      loading: () => _buildStatusScrollView(
        theme,
        const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => _buildErrorState(theme, error),
    );
  }

  Widget _buildMessageListView(
    List<MessageWithAccount> messages,
    ThemeData theme,
    DisplaySettings displaySettings,
  ) {
    final visibleMessages = messages
        .map((item) => item.message)
        .toList(growable: false);
    _pruneSelection(visibleMessages);

    return _buildMessageScrollView(theme, visibleMessages, [
      SliverM3ECardList(
        itemCount: messages.length,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: EdgeInsets.zero,
        gap: 3,
        outerRadius: 24,
        innerRadius: 4,
        color: mailListSurfaceColor(theme),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
        haptic: M3EHapticFeedback.light,
        semanticLabelBuilder: (index) {
          final item = messages[index];
          return _messageSemanticLabel(item.message, item.accountEmail);
        },
        onTap: (index) => _handleMessageTap(messages[index].message),
        onLongPress: (index) => _selectMessage(messages[index].message),
        itemBuilder: (context, index) {
          final item = messages[index];
          final message = item.message;
          // 滚动到（近）可见即后台预取正文（低优先级，仅 Wi‑Fi/非计费网络）。
          ref.read(bodyPrefetchServiceProvider).enqueueVisible(message.id);
          final selected = _selectedMessageIds.contains(message.id);
          final accountColor = item.accountColorValue != null
              ? Color(item.accountColorValue!)
              : null;

          Widget buildPreview(BuildContext context) {
            return GmailMobileMessageCardContent(
              message: message,
              accountEmail: item.accountEmail,
              accountColor: accountColor,
              showAccountLabel: true,
              displaySettings: displaySettings,
              isSelected: selected,
            );
          }

          return PredictiveBackSharedElementTarget(
            key: ValueKey(message.id),
            id: message.id,
            borderRadius: _messageCardBorderRadius(index, messages.length),
            backgroundColor: mailListSurfaceColor(theme),
            previewBuilder: buildPreview,
            child: GmailMobileMessageCardContent(
              message: message,
              accountEmail: item.accountEmail,
              accountColor: accountColor,
              showAccountLabel: true,
              displaySettings: displaySettings,
              isSelected: selected,
              onStarTap: () {
                // TODO: 实现星标切换
                debugPrint('切换星标: ${message.id}');
              },
            ),
          );
        },
      ),
    ]);
  }

  Widget _buildAccountMessageListView(
    List<Message> messages,
    ThemeData theme,
    DisplaySettings displaySettings,
  ) {
    _pruneSelection(messages);

    return _buildMessageScrollView(theme, messages, [
      SliverM3ECardList(
        itemCount: messages.length,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: EdgeInsets.zero,
        gap: 3,
        outerRadius: 24,
        innerRadius: 4,
        color: mailListSurfaceColor(theme),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
        haptic: M3EHapticFeedback.light,
        semanticLabelBuilder: (index) {
          return _messageSemanticLabel(messages[index], null);
        },
        onTap: (index) => _handleMessageTap(messages[index]),
        onLongPress: (index) => _selectMessage(messages[index]),
        itemBuilder: (context, index) {
          final message = messages[index];
          // 滚动到（近）可见即后台预取正文（低优先级，仅 Wi‑Fi/非计费网络）。
          ref.read(bodyPrefetchServiceProvider).enqueueVisible(message.id);
          final selected = _selectedMessageIds.contains(message.id);

          Widget buildPreview(BuildContext context) {
            return GmailMobileMessageCardContent(
              message: message,
              showAccountLabel: false,
              displaySettings: displaySettings,
              isSelected: selected,
            );
          }

          return PredictiveBackSharedElementTarget(
            key: ValueKey(message.id),
            id: message.id,
            borderRadius: _messageCardBorderRadius(index, messages.length),
            backgroundColor: mailListSurfaceColor(theme),
            previewBuilder: buildPreview,
            child: GmailMobileMessageCardContent(
              message: message,
              showAccountLabel: false,
              displaySettings: displaySettings,
              isSelected: selected,
              onStarTap: () {
                // TODO: 实现星标切换
                debugPrint('切换星标: ${message.id}');
              },
            ),
          );
        },
      ),
    ]);
  }

  void _handleMenuAction(
    BuildContext context,
    List<Message> visibleMessages,
    _MessageListMenuAction action,
  ) {
    final selectedMessages = _selectedMessagesFrom(visibleMessages);
    switch (action) {
      case _MessageListMenuAction.selectAll:
        _selectAll(visibleMessages);
        break;
      case _MessageListMenuAction.markAllRead:
        _markAllRead(context, visibleMessages);
        break;
      case _MessageListMenuAction.archiveSelected:
        _moveMessagesToFolderType(
          context,
          selectedMessages,
          FolderType.archive,
          successLabel: '已归档',
          failureLabel: '归档失败',
        );
        break;
      case _MessageListMenuAction.flagSelected:
        _setFlagForMessages(
          context,
          selectedMessages,
          flag: MessageFlag.flagged,
          value: true,
          successLabel: '已加星标',
          failureLabel: '加星标失败',
        );
        break;
      case _MessageListMenuAction.unflagSelected:
        _setFlagForMessages(
          context,
          selectedMessages,
          flag: MessageFlag.flagged,
          value: false,
          successLabel: '已取消星标',
          failureLabel: '取消星标失败',
        );
        break;
      case _MessageListMenuAction.clearSelection:
        _clearSelection();
        break;
    }
  }

  void _handleMessageTap(Message message) {
    if (_selectedMessageIds.isEmpty) {
      onMessageTap(message);
      return;
    }
    _toggleMessageSelection(message);
  }

  void _selectMessage(Message message) {
    if (_selectedMessageIds.contains(message.id)) return;
    setState(() {
      _selectedMessageIds.add(message.id);
    });
  }

  void _toggleMessageSelection(Message message) {
    setState(() {
      if (!_selectedMessageIds.remove(message.id)) {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  void _selectAll(List<Message> messages) {
    if (messages.isEmpty) return;
    setState(() {
      _selectedMessageIds
        ..clear()
        ..addAll(messages.map((message) => message.id));
    });
  }

  void _clearSelection() {
    if (_selectedMessageIds.isEmpty) return;
    setState(_selectedMessageIds.clear);
  }

  void _pruneSelection(List<Message> visibleMessages) {
    if (_selectedMessageIds.isEmpty) return;
    final visibleIds = visibleMessages.map((message) => message.id).toSet();
    _selectedMessageIds.removeWhere((id) => !visibleIds.contains(id));
  }

  List<Message> _selectedMessagesFrom(List<Message> visibleMessages) {
    if (_selectedMessageIds.isEmpty) return const <Message>[];
    return visibleMessages
        .where((message) => _selectedMessageIds.contains(message.id))
        .toList(growable: false);
  }

  Future<void> _markAllRead(
    BuildContext context,
    List<Message> visibleMessages,
  ) async {
    if (_batchInProgress) return;

    final unreadMessages = visibleMessages
        .where((message) => !_isRead(message))
        .toList(growable: false);
    if (unreadMessages.isEmpty) return;

    await _setReadForMessages(context, unreadMessages, read: true);
  }

  Future<void> _setReadForMessages(
    BuildContext context,
    List<Message> messages, {
    required bool read,
  }) async {
    if (_batchInProgress || messages.isEmpty) return;

    setState(() {
      _batchInProgress = true;
    });

    final changedMessages = messages
        .where((message) => _isRead(message) != read)
        .toList(growable: false);
    try {
      final syncService = ref.read(syncServiceProvider);
      for (final message in changedMessages) {
        await syncService.setMessageFlag(
          message.id,
          flag: MessageFlag.seen,
          value: read,
        );
      }

      if (!context.mounted) return;
      final actionLabel = read ? '已读' : '未读';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已将 ${changedMessages.length} 封邮件标为$actionLabel'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final actionLabel = read ? '标为已读' : '标为未读';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$actionLabel失败: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _batchInProgress = false;
        });
      }
    }
  }

  Future<void> _setFlagForMessages(
    BuildContext context,
    List<Message> messages, {
    required MessageFlag flag,
    required bool value,
    required String successLabel,
    required String failureLabel,
  }) async {
    if (_batchInProgress || messages.isEmpty) return;

    setState(() {
      _batchInProgress = true;
    });

    try {
      final syncService = ref.read(syncServiceProvider);
      for (final message in messages) {
        await syncService.setMessageFlag(message.id, flag: flag, value: value);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successLabel ${messages.length} 封邮件')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$failureLabel: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _batchInProgress = false;
        });
      }
    }
  }

  Future<void> _moveMessagesToFolderType(
    BuildContext context,
    List<Message> messages,
    FolderType folderType, {
    required String successLabel,
    required String failureLabel,
  }) async {
    if (_batchInProgress || messages.isEmpty) return;

    setState(() {
      _batchInProgress = true;
    });

    try {
      final syncService = ref.read(syncServiceProvider);
      for (final message in messages) {
        await syncService.moveMessageToFolderType(message.id, folderType);
      }

      if (!context.mounted) return;
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successLabel ${messages.length} 封邮件')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$failureLabel: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _batchInProgress = false;
        });
      }
    }
  }

  Future<void> _deleteMessages(
    BuildContext context,
    List<Message> messages,
  ) async {
    if (_batchInProgress || messages.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除邮件'),
        content: Text('确定要删除选中的 ${messages.length} 封邮件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() {
      _batchInProgress = true;
    });

    try {
      final syncService = ref.read(syncServiceProvider);
      for (final message in messages) {
        await syncService.deleteMessage(message.id);
      }

      if (!context.mounted) return;
      _clearSelection();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除 ${messages.length} 封邮件')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _batchInProgress = false;
        });
      }
    }
  }

  bool _isRead(Message message) {
    return (message.flagsBitmask & (1 << MessageFlag.seen.index)) != 0;
  }

  String _messageSemanticLabel(Message message, String? accountEmail) {
    final sender = message.fromName?.trim().isNotEmpty == true
        ? message.fromName!.trim()
        : message.fromEmail?.trim();
    final subject = message.subject.isEmpty ? '无主题' : message.subject;
    final account = accountEmail == null ? '' : '，账户 $accountEmail';
    return '${sender ?? '未知发件人'}，$subject$account';
  }

  BorderRadius _messageCardBorderRadius(int index, int total) {
    const outerRadius = Radius.circular(24);
    const innerRadius = Radius.circular(4);

    if (total <= 1) {
      return const BorderRadius.all(outerRadius);
    }
    if (index == 0) {
      return const BorderRadius.vertical(top: outerRadius, bottom: innerRadius);
    }
    if (index == total - 1) {
      return const BorderRadius.vertical(top: innerRadius, bottom: outerRadius);
    }
    return const BorderRadius.all(innerRadius);
  }

  Widget _buildErrorState(ThemeData theme, Object error) {
    return _buildStatusScrollView(
      theme,
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('加载失败', style: theme.textTheme.bodyLarge),
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
      ),
    );
  }

  /// 没邮件时仍然支持下拉刷新：用 always-scrollable physics + 撑满高度的占位。
  Widget _buildEmptyMessages(ThemeData theme) {
    _pruneSelection(const <Message>[]);

    return _buildStatusScrollView(
      theme,
      Center(
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
      refreshable: true,
    );
  }
}
