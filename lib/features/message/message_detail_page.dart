import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/navigation/predictive_back_shared_element.dart';
import '../../core/theme/mail_list_colors.dart';
import '../../data/local/database/app_database.dart';
import '../../data/settings/remote_image_trust.dart';
import '../../domain/enums/message_enums.dart';
import '../../domain/models/mail_attachment.dart';
import '../home/widgets/gmail_mobile_message_item.dart';
import 'widgets/attachment_list.dart';
import 'widgets/folder_picker_dialog.dart';
import 'widgets/message_header_tile.dart';
import 'widgets/message_html_view.dart';

/// 邮件详情页面（独立路由）。
///
/// 显示邮件的完整内容：
/// - 发件人、收件人、主题、时间
/// - 正文（HTML 渲染）
/// - 附件列表
/// - 操作按钮（回复、转发、删除等）
class MessageDetailPage extends ConsumerStatefulWidget {
  const MessageDetailPage({
    required this.messageId,
    this.initialMessage,
    super.key,
  });

  final String messageId;
  final Message? initialMessage;

  @override
  ConsumerState<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends ConsumerState<MessageDetailPage> {
  String? _registeredSharedElementId;

  String get messageId => widget.messageId;

  @override
  void initState() {
    super.initState();
    final initialMessage = widget.initialMessage;
    if (initialMessage != null && initialMessage.id == messageId) {
      _registerReturnPreview(initialMessage);
    }
  }

  @override
  void didUpdateWidget(covariant MessageDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId) {
      _clearReturnPreview();
      final initialMessage = widget.initialMessage;
      if (initialMessage != null && initialMessage.id == messageId) {
        _registerReturnPreview(initialMessage);
      }
    }
  }

  @override
  void dispose() {
    _clearReturnPreview();
    super.dispose();
  }

  void _registerReturnPreview(Message message, {Color? sourceBackgroundColor}) {
    _registeredSharedElementId = message.id;
    final displaySettings = ref.read(displaySettingsProvider);
    PredictiveBackSharedElementRegistry.instance.setActive(
      id: message.id,
      sourceBackgroundColor: sourceBackgroundColor,
      previewBuilder: (context) => GmailMobileMessageCardContent(
        message: message,
        showAccountLabel: false,
        displaySettings: displaySettings,
      ),
    );
  }

  void _clearReturnPreview() {
    final id = _registeredSharedElementId;
    if (id == null) return;
    PredictiveBackSharedElementRegistry.instance.clearActive(id);
    _registeredSharedElementId = null;
  }

  /// 归档：移动到归档文件夹并返回列表。账户无归档文件夹时提示失败。
  Future<void> _archiveMessage() async {
    final message = await ref
        .read(databaseProvider)
        .messageDao
        .getMessage(messageId);
    if (message == null || !mounted) return;

    final syncService = ref.read(syncServiceProvider);
    try {
      await syncService.moveMessageToFolderType(message.id, FolderType.archive);
      final account = await syncService.accountConfigFor(message.accountId);
      unawaited(syncService.flushOutbox(account));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已归档')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('归档失败: $e')));
    }
  }

  /// 删除：确认后删除并返回列表。
  Future<void> _deleteMessage() async {
    final message = await ref
        .read(databaseProvider)
        .messageDao
        .getMessage(messageId);
    if (message == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除邮件'),
        content: const Text('确定要删除这封邮件吗？'),
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
    if (confirmed != true || !mounted) return;

    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.deleteMessage(message.id);
      final account = await syncService.accountConfigFor(message.accountId);
      unawaited(syncService.flushOutbox(account));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('邮件已删除')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  /// 切换已读/未读：本地立即更新 + 入队推送到服务端，原地停留。
  Future<void> _toggleRead(bool isRead) async {
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.setMessageFlag(
        messageId,
        flag: MessageFlag.seen,
        value: !isRead,
      );
      // 立即推送，否则只入队、要等下一次周期同步才回推服务端。
      final message = await ref
          .read(databaseProvider)
          .messageDao
          .getMessage(messageId);
      if (message != null) {
        final account = await syncService.accountConfigFor(message.accountId);
        unawaited(syncService.flushOutbox(account));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(isRead ? '已标记为未读' : '已标记为已读')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  /// 移动到文件夹（选择目标后移动，原地停留）。
  Future<void> _moveMessage() async {
    final message = await ref
        .read(databaseProvider)
        .messageDao
        .getMessage(messageId);
    if (message == null || !mounted) return;

    final targetFolder = await showFolderPicker(
      context,
      accountId: message.accountId,
      currentFolderId: message.folderId,
    );
    if (targetFolder == null || !mounted) return;

    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.moveMessageToFolder(message.id, targetFolder.id);
      final account = await syncService.accountConfigFor(message.accountId);
      unawaited(syncService.flushOutbox(account));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已移动到 ${targetFolder.displayName}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('移动失败: $e')));
    }
  }

  /// 暂未实现的功能（回复/转发/打印/帮助等）：先弹占位提示。
  void _notImplemented(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label功能开发中')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);

    final scaffold = Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: '归档',
            onPressed: _archiveMessage,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: _deleteMessage,
          ),
          // 已读/未读：实时标志位驱动图标与动作，Consumer 把重建限定在按钮本身，
          // 不触发正文 WebView 重建。
          Consumer(
            builder: (context, ref, _) {
              final flags =
                  ref.watch(messageFlagsProvider(messageId)).value ??
                  (widget.initialMessage?.flagsBitmask ?? 0);
              final isRead = (flags & (1 << MessageFlag.seen.index)) != 0;
              return IconButton(
                icon: Icon(
                  isRead
                      ? Icons.mark_email_unread_outlined
                      : Icons.mark_email_read_outlined,
                ),
                tooltip: isRead ? '标为未读' : '标为已读',
                onPressed: () => _toggleRead(isRead),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'move':
                  _moveMessage();
                case 'print':
                  _notImplemented('全部打印');
                case 'help':
                  _notImplemented('帮助和反馈');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'move',
                child: Row(
                  children: [
                    Icon(Icons.drive_file_move_outline),
                    SizedBox(width: 12),
                    Text('移动到'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print_outlined),
                    SizedBox(width: 12),
                    Text('全部打印'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline),
                    SizedBox(width: 12),
                    Text('帮助和反馈'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<Message?>(
        initialData: widget.initialMessage?.id == messageId
            ? widget.initialMessage
            : null,
        stream: db.messageDao
            .watchMessage(messageId)
            .distinct(_sameVisibleMessage),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
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
                  Text('加载失败', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final message = snapshot.data;
          if (message == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '邮件不存在',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // 注册「收束到按钮」返回预览：键用入口 messageId（= 列表会话行的共享
          // 元素 id），多卡片会话不影响收束（预览由列表行 target 提供）。
          _registerReturnPreview(
            message,
            sourceBackgroundColor: theme.colorScheme.surface,
          );

          return _ThreadContent(key: ValueKey(message.id), entry: message);
        },
      ),
    );
    return scaffold;
  }
}

bool _sameVisibleMessage(Message? previous, Message? next) {
  if (identical(previous, next)) return true;
  if (previous == null || next == null) return previous == next;

  // The detail header/body does not depend on local flag changes. Ignoring
  // flag-only updates prevents the auto mark-read write from rebuilding the
  // whole HTML body during route transitions.
  return previous.id == next.id &&
      previous.accountId == next.accountId &&
      previous.folderId == next.folderId &&
      previous.subject == next.subject &&
      previous.fromName == next.fromName &&
      previous.fromEmail == next.fromEmail &&
      previous.toRecipients == next.toRecipients &&
      previous.ccRecipients == next.ccRecipients &&
      previous.date == next.date;
}

/// 会话内容组件：把整条会话（账户内同 threadKey）的邮件按时间升序堆叠成多张卡片。
///
/// 结构：主题 + 星标 → 每封邮件一张卡片（[MessageHeaderTile] 头部 + 可折叠正文）。
/// 默认仅展开最新一封与未读邮件；折叠且从未展开过的卡片不挂载正文（不触发下载），
/// 展开过的用 Offstage 保活，再次折叠不丢状态。打开会话即把其中所有未读标为已读。
/// threadKey 为空时退化为单封会话。
class _ThreadContent extends ConsumerStatefulWidget {
  const _ThreadContent({required this.entry, super.key});

  /// 进入会话的入口邮件（列表里点中的代表邮件），提供 accountId/threadKey。
  final Message entry;

  @override
  ConsumerState<_ThreadContent> createState() => _ThreadContentState();
}

class _ThreadContentState extends ConsumerState<_ThreadContent> {
  late final Stream<List<Message>> _threadStream;

  /// 当前展开的邮件 id。
  final Set<String> _expanded = <String>{};

  /// 曾展开过的邮件 id：用于保活（折叠后 Offstage 隐藏而非卸载正文）。
  final Set<String> _everExpanded = <String>{};

  bool _initializedExpansion = false;
  bool _autoMarkReadDone = false;

  Message get entry => widget.entry;

  @override
  void initState() {
    super.initState();
    // 首帧先展开入口邮件（= 会话最新一封），避免初始一片折叠。
    _expanded.add(entry.id);
    _everExpanded.add(entry.id);

    final db = ref.read(databaseProvider);
    // 尊重「会话视图」开关：关闭时阅读页只显示点开的这一封（与列表一封一行一致）。
    final conversationView = ref.read(displaySettingsProvider).conversationView;
    final threadKey = entry.threadKey?.trim();
    if (conversationView && threadKey != null && threadKey.isNotEmpty) {
      // 整个账户内同 threadKey 的邮件（跨文件夹），按日期升序。
      // 用 distinct 忽略 flag-only 变化，避免自动已读写入重建正文 WebView。
      _threadStream = db.messageDao
          .watchThread(entry.accountId, threadKey)
          .distinct(_sameThread);
    } else {
      _threadStream = db.messageDao
          .watchMessage(entry.id)
          .map((m) => m == null ? <Message>[] : <Message>[m])
          .distinct(_sameThread);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = mailListSurfaceColor(theme);
    final displaySettings = ref.watch(displaySettingsProvider);
    final accounts =
        ref.watch(accountsStreamProvider).value ?? const <Account>[];
    final selfEmails = <String>{
      for (final account in accounts) account.email.trim().toLowerCase(),
    };

    return StreamBuilder<List<Message>>(
      initialData: <Message>[entry],
      stream: _threadStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final thread = (data == null || data.isEmpty) ? <Message>[entry] : data;

        // 拿到真实会话数据（非 initialData）后，按「最新 + 未读」补充默认展开。
        if (snapshot.connectionState != ConnectionState.waiting) {
          _ensureExpansionInitialized(thread);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureThreadMarkedRead(thread);
        });

        // 代表邮件：会话最新一封（升序末尾）。
        final representative = thread.last;
        // 该会话所属账户：阅读页按账户内 threadKey 分组，整条会话同属一个账户。
        final account = _accountFor(accounts, representative.accountId);

        return RepaintBoundary(
          // HC 模式的正文 WebView 是叠加在 Flutter 之上的原生视图,无法跟随
          // overscroll 的 stretch 形变;关闭本页 overscroll 指示器,让所有元素一致地
          // 不形变,消除「周围被拉伸而 WebView 纹丝不动」的割裂感(physics、滚动条
          // 等其余 Material 行为保留)。
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(overscroll: false),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // 账户标签：以账户颜色为底，显示账户名称，置于主题上方。
                if (account != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _AccountBadge(account: account),
                    ),
                  ),
                // 主题行：主题 + 星标按钮同行。
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          representative.subject.isEmpty
                              ? '(无主题)'
                              : representative.subject,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 星标作用于代表邮件；实时标志位驱动，Consumer 限定重建范围。
                      Consumer(
                        builder: (context, ref, _) {
                          final flags =
                              ref
                                  .watch(
                                    messageFlagsProvider(representative.id),
                                  )
                                  .value ??
                              representative.flagsBitmask;
                          final isFlagged =
                              (flags & (1 << MessageFlag.flagged.index)) != 0;
                          return IconButton(
                            icon: Icon(
                              isFlagged ? Icons.star : Icons.star_border,
                            ),
                            color: isFlagged ? const Color(0xFFE0A100) : null,
                            tooltip: isFlagged ? '取消星标' : '星标',
                            onPressed: () =>
                                _toggleStar(representative, isFlagged),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // 每封邮件一张卡片（多封 = 会话堆叠）。
                M3ECardList(
                  itemCount: thread.length,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: EdgeInsets.zero,
                  gap: 3,
                  outerRadius: 24,
                  innerRadius: 4,
                  color: cardColor,
                  itemBuilder: (context, index) {
                    final message = thread[index];
                    final expanded = _expanded.contains(message.id);
                    // 从未展开过的折叠卡片不挂载正文，避免一次性下载整条会话的正文。
                    final mountBody =
                        expanded || _everExpanded.contains(message.id);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MessageHeaderTile(
                          message: message,
                          selfEmails: selfEmails,
                          displaySettings: displaySettings,
                          collapsed: !expanded,
                          onToggleCollapsed: () => _toggleExpanded(message.id),
                        ),
                        if (mountBody)
                          Offstage(
                            offstage: !expanded,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              child: _MessageBody(
                                key: ValueKey(message.id),
                                message: message,
                                backgroundColor: cardColor,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _ensureExpansionInitialized(List<Message> thread) {
    if (_initializedExpansion) return;
    _initializedExpansion = true;
    if (thread.isNotEmpty) {
      _expanded.add(thread.last.id); // 最新一封
      _everExpanded.add(thread.last.id);
    }
    final seenBit = 1 << MessageFlag.seen.index;
    for (final m in thread) {
      if ((m.flagsBitmask & seenBit) == 0) {
        _expanded.add(m.id); // 未读默认展开
        _everExpanded.add(m.id);
      }
    }
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expanded.remove(id)) return;
      _expanded.add(id);
      _everExpanded.add(id);
    });
  }

  /// 打开会话即把其中所有未读标记为已读：走 outbox，按账户去重各刷一次。
  /// 不阻塞 UI；失败不弹错（最终一致即可）。
  Future<void> _ensureThreadMarkedRead(List<Message> thread) async {
    if (_autoMarkReadDone) return;
    _autoMarkReadDone = true;
    final seenBit = 1 << MessageFlag.seen.index;
    final unread = thread
        .where((m) => (m.flagsBitmask & seenBit) == 0)
        .toList(growable: false);
    if (unread.isEmpty) return;
    try {
      final syncService = ref.read(syncServiceProvider);
      for (final message in unread) {
        await syncService.setMessageFlag(
          message.id,
          flag: MessageFlag.seen,
          value: true,
        );
      }
      // 立即推送，否则只入队、要等下一次周期同步才回推服务端。
      for (final accountId in unread.map((m) => m.accountId).toSet()) {
        final account = await syncService.accountConfigFor(accountId);
        unawaited(syncService.flushOutbox(account));
      }
    } catch (_) {
      _autoMarkReadDone = false;
    }
  }

  Future<void> _toggleStar(Message message, bool isFlagged) {
    return ref
        .read(syncServiceProvider)
        .setMessageFlag(
          message.id,
          flag: MessageFlag.flagged,
          value: !isFlagged,
        );
  }
}

/// 比较两个会话快照是否「可见结构」一致：忽略 flag-only 变化，
/// 使自动已读等标志位写入不会重建正文 WebView（与 [_sameVisibleMessage] 同理）。
bool _sameThread(List<Message> a, List<Message> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (x.id != y.id ||
        x.folderId != y.folderId ||
        x.subject != y.subject ||
        x.fromName != y.fromName ||
        x.fromEmail != y.fromEmail ||
        x.toRecipients != y.toRecipients ||
        x.ccRecipients != y.ccRecipients ||
        x.date != y.date) {
      return false;
    }
  }
  return true;
}

/// 邮件正文区：打开邮件即自动下载正文，下载完成后通过 `watchBody` 响应式预览。
///
/// 状态：下载中（spinner）/ 失败（错误卡片 + 重试）/ 有正文（HTML 或纯文本 + 附件）/
/// 空正文（"（无正文）" + 重新下载）。手动重试走 [SyncService.fetchMessageBody] 的
/// `force: true`，正常情况下首帧的自动下载已覆盖。
class _MessageBody extends ConsumerStatefulWidget {
  const _MessageBody({
    required this.message,
    required this.backgroundColor,
    super.key,
  });

  final Message message;

  /// 正文 WebView 的背景色：设为所在卡片色，使正文与卡片无缝衔接。
  final Color backgroundColor;

  @override
  ConsumerState<_MessageBody> createState() => _MessageBodyState();
}

class _MessageBodyState extends ConsumerState<_MessageBody> {
  late final Stream<MessageBody?> _bodyStream;
  bool _downloading = false;
  Object? _error;
  bool _autoTriggered = false;

  String get _messageId => widget.message.id;

  @override
  void initState() {
    super.initState();
    // 建一次流即可，避免每次 build 重新订阅。
    _bodyStream = ref.read(databaseProvider).messageDao.watchBody(_messageId);
  }

  Future<void> _download({
    bool force = false,
    bool checkExisting = true,
  }) async {
    if (_downloading) return;
    if (!force && checkExisting) {
      final existing = await ref
          .read(databaseProvider)
          .messageDao
          .getBody(_messageId);
      if (!mounted || _isDownloadedBody(existing)) return;
    }

    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await ref
          .read(syncServiceProvider)
          .fetchMessageBody(_messageId, force: force);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 在 build 本体里 watch（builder 闭包中调用 ref.watch 不合法）；
    // 信任名单变化会重建本组件，使同发件人的其余卡片也即时出图。
    final remoteImageTrust = ref.watch(remoteImageTrustProvider);

    return StreamBuilder<MessageBody?>(
      stream: _bodyStream,
      builder: (context, snapshot) {
        final body = _isDownloadedBody(snapshot.data) ? snapshot.data : null;

        // 本地已有正文行（下载成功后才会写入）：展示正文 + 附件。
        if (body != null) {
          return _buildContent(theme, body, remoteImageTrust);
        }

        // Drift 的 watchSingleOrNull 首帧会先进入 waiting。此时不能判定
        // 本地无正文，否则已缓存正文也会短暂触发下载 UI。
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return _buildError(theme, snapshot.error);
        }

        // 还没有正文行且上次下载失败：错误卡片 + 重试。
        if (_error != null) {
          return _buildError(theme);
        }

        // 首次进入：自动触发一次下载，本帧先显示加载中。
        if (!_autoTriggered && !_downloading) {
          _autoTriggered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _download(checkExisting: false);
          });
        }
        return _buildLoading(theme);
      },
    );
  }

  bool _isDownloadedBody(MessageBody? body) {
    return body != null && body.fetchState != BodyFetchState.notDownloaded;
  }

  Widget _buildContent(
    ThemeData theme,
    MessageBody body,
    RemoteImageTrust remoteImageTrust,
  ) {
    final hasHtml = body.htmlBody != null && body.htmlBody!.isNotEmpty;
    final hasPlain = body.plainText != null && body.plainText!.isNotEmpty;
    final attachments = AttachmentUtils.parseAttachments(body.attachmentsMeta);
    // 受信发件人（手动信任过或命中预置名单）的远程图片自动加载；
    // 其余发件人先拦截，手动加载一次后正文里会给出「信任该发件人」入口。
    final senderEmail = widget.message.fromEmail?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasHtml)
          MessageHtmlView(
            htmlBody: body.htmlBody!,
            textStyle: theme.textTheme.bodyMedium,
            backgroundColor: widget.backgroundColor,
            foregroundColor: theme.colorScheme.onSurface,
            linkColor: theme.colorScheme.primary,
            borderColor: theme.colorScheme.outlineVariant,
            onOpenUrl: _openLink,
            senderEmail: senderEmail,
            autoLoadRemoteImages: remoteImageTrust.isTrustedSender(senderEmail),
            onTrustSender: senderEmail == null || senderEmail.isEmpty
                ? null
                : () => ref
                      .read(remoteImageTrustProvider.notifier)
                      .trustSender(senderEmail),
          )
        else if (hasPlain)
          Container(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              body.plainText!,
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          // 正文为空（可能仅有附件）。
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '（无正文）',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _downloading ? null : () => _download(force: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新下载'),
                ),
              ],
            ),
          ),

        // 附件（字节按需下载，这里只列元数据）。
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 24),
          AttachmentList(attachments: attachments, messageId: _messageId),
        ],
      ],
    );
  }

  /// 正文尚未到达本地时的占位：立即显示信封里的 `preview` 摘要，避免空白转圈，
  /// 正文 HTML 下载完成后由 `watchBody` 触发无缝替换为 [_buildContent]。
  Widget _buildLoading(ThemeData theme) {
    final preview = widget.message.preview.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部细进度条：提示正文正在后台下载。
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: LinearProgressIndicator(minHeight: 2),
        ),
        const SizedBox(height: 12),
        if (preview.isNotEmpty)
          // 立即可读的摘要，观感接近"点开即见内容"。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              preview,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          )
        else
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                '正在下载正文…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildError(ThemeData theme, [Object? error]) {
    final displayError = error ?? _error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(
            '正文下载失败',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$displayError',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _downloading ? null : () => _download(force: true),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 打开正文中的链接（与原内联实现一致）。
  Future<bool> _openLink(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('打开链接失败: $e')));
      }
    }
    return true;
  }
}

/// 在账户列表中按 id 查找邮件所属账户；列表未就绪或找不到时返回 null。
Account? _accountFor(List<Account> accounts, String accountId) {
  for (final account in accounts) {
    if (account.id == accountId) return account;
  }
  return null;
}

/// 会话主题上方的账户标签：以账户颜色为底色的圆角标签，显示账户名称。
///
/// 文字颜色按底色明暗自动取黑/白以保证对比度；账户未配置颜色时回退到主色。
/// 名称为空时回退到邮箱地址，悬浮显示完整邮箱。
class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = account.colorValue == null
        ? theme.colorScheme.primary
        : Color(account.colorValue!);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final name = account.displayName.trim();
    final label = name.isEmpty ? account.email : name;

    return Tooltip(
      message: account.email,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: onColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
