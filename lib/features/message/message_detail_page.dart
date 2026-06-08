import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/navigation/predictive_back_shared_element.dart';
import '../../data/local/database/app_database.dart';
import '../../domain/enums/message_enums.dart';
import '../../domain/models/mail_attachment.dart';
import '../../domain/models/mail_recipient.dart';
import '../home/widgets/gmail_mobile_message_item.dart';
import 'widgets/attachment_list.dart';
import 'widgets/folder_picker_dialog.dart';
import 'widgets/message_html_view.dart';
import 'widgets/recipient_section.dart';

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
  bool _autoMarkReadDone = false;
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

  /// 打开邮件即标记为已读：通过 SyncService 走 outbox，下一次同步会推送到服务端。
  /// 这里不阻塞 UI；失败也不弹错（最终一致即可）。
  Future<void> _ensureMarkedRead(Message message) async {
    if (_autoMarkReadDone) return;
    final isRead = (message.flagsBitmask & (1 << MessageFlag.seen.index)) != 0;
    if (isRead) {
      _autoMarkReadDone = true;
      return;
    }
    _autoMarkReadDone = true;
    try {
      await ref
          .read(syncServiceProvider)
          .setMessageFlag(message.id, flag: MessageFlag.seen, value: true);
    } catch (_) {
      _autoMarkReadDone = false;
    }
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
            icon: const Icon(Icons.reply),
            tooltip: '回复',
            onPressed: () {
              // TODO: 回复邮件
            },
          ),
          IconButton(
            icon: const Icon(Icons.forward),
            tooltip: '转发',
            onPressed: () {
              // TODO: 转发邮件
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final db = ref.read(databaseProvider);
              final message = await db.messageDao.getMessage(messageId);
              if (message == null) return;

              switch (value) {
                case 'delete':
                  // 删除邮件（显示确认对话框）
                  if (context.mounted) {
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

                    if (confirmed == true) {
                      try {
                        final syncService = ref.read(syncServiceProvider);
                        await syncService.deleteMessage(message.id);
                        final account = await syncService.accountConfigFor(
                          message.accountId,
                        );
                        unawaited(syncService.flushOutbox(account));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('邮件已删除')),
                          );
                          context.pop(); // 返回列表页
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
                        }
                      }
                    }
                  }
                  break;

                case 'mark_unread':
                  // 标记为未读：通过 SyncService，本地立即更新 + 入队推送到 Graph。
                  await ref
                      .read(syncServiceProvider)
                      .setMessageFlag(
                        message.id,
                        flag: MessageFlag.seen,
                        value: false,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已标记为未读')));
                  }
                  break;

                case 'star':
                  // 切换星标：同样走 SyncService，确保推送到服务端。
                  final isFlagged =
                      (message.flagsBitmask &
                          (1 << MessageFlag.flagged.index)) !=
                      0;
                  await ref
                      .read(syncServiceProvider)
                      .setMessageFlag(
                        message.id,
                        flag: MessageFlag.flagged,
                        value: !isFlagged,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isFlagged ? '已取消星标' : '已加星标')),
                    );
                  }
                  break;

                case 'move':
                  // 移动到文件夹
                  if (context.mounted) {
                    final targetFolder = await showFolderPicker(
                      context,
                      accountId: message.accountId,
                      currentFolderId: message.folderId,
                    );

                    if (targetFolder != null && context.mounted) {
                      try {
                        final syncService = ref.read(syncServiceProvider);
                        await syncService.moveMessageToFolder(
                          message.id,
                          targetFolder.id,
                        );
                        final account = await syncService.accountConfigFor(
                          message.accountId,
                        );
                        unawaited(syncService.flushOutbox(account));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已移动到 ${targetFolder.displayName}'),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('移动失败: $e')));
                        }
                      }
                    }
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 12),
                    Text('删除'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mark_unread',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_unread_outlined),
                    SizedBox(width: 12),
                    Text('标记为未读'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'star',
                child: Row(
                  children: [
                    Icon(Icons.star_border),
                    SizedBox(width: 12),
                    Text('加星标'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'move',
                child: Row(
                  children: [
                    Icon(Icons.drive_file_move_outline),
                    SizedBox(width: 12),
                    Text('移动到...'),
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

          // 邮件首次进入视图时自动标记为已读。在 build 之外、frame 完成后触发，
          // 避免 build 阶段触发 setState/数据库写。
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureMarkedRead(message);
          });
          _registerReturnPreview(
            message,
            sourceBackgroundColor: theme.colorScheme.surface,
          );

          return _MessageContent(message: message);
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

/// 邮件内容组件。
class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 主题
          Text(message.subject, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),

          // 发件人信息
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  (message.fromName ?? message.fromEmail ?? '?')[0]
                      .toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.fromName ?? message.fromEmail ?? '未知发件人',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (message.fromEmail != null)
                      Text(
                        message.fromEmail!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _formatDate(message.date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 收件人信息（可展开）
          RecipientSection(
            toRecipients: RecipientUtils.parseRecipients(message.toRecipients),
            ccRecipients: RecipientUtils.parseRecipients(message.ccRecipients),
          ),

          const Divider(height: 32),

          // 邮件正文与附件：打开即自动下载，下载完成后响应式预览。
          _MessageBody(key: ValueKey(message.id), message: message),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// 邮件正文区：打开邮件即自动下载正文，下载完成后通过 `watchBody` 响应式预览。
///
/// 状态：下载中（spinner）/ 失败（错误卡片 + 重试）/ 有正文（HTML 或纯文本 + 附件）/
/// 空正文（"（无正文）" + 重新下载）。手动重试走 [SyncService.fetchMessageBody] 的
/// `force: true`，正常情况下首帧的自动下载已覆盖。
class _MessageBody extends ConsumerStatefulWidget {
  const _MessageBody({required this.message, super.key});

  final Message message;

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

    return StreamBuilder<MessageBody?>(
      stream: _bodyStream,
      builder: (context, snapshot) {
        final body = _isDownloadedBody(snapshot.data) ? snapshot.data : null;

        // 本地已有正文行（下载成功后才会写入）：展示正文 + 附件。
        if (body != null) {
          return _buildContent(theme, body);
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

  Widget _buildContent(ThemeData theme, MessageBody body) {
    final hasHtml = body.htmlBody != null && body.htmlBody!.isNotEmpty;
    final hasPlain = body.plainText != null && body.plainText!.isNotEmpty;
    final attachments = AttachmentUtils.parseAttachments(body.attachmentsMeta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasHtml)
          MessageHtmlView(
            htmlBody: body.htmlBody!,
            textStyle: theme.textTheme.bodyMedium,
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            linkColor: theme.colorScheme.primary,
            borderColor: theme.colorScheme.outlineVariant,
            onOpenUrl: _openLink,
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
