import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../data/local/database/app_database.dart';
import '../../domain/enums/message_enums.dart';
import '../../domain/models/mail_attachment.dart';
import '../../domain/models/mail_recipient.dart';
import 'widgets/attachment_list.dart';
import 'widgets/folder_picker_dialog.dart';
import 'widgets/recipient_section.dart';

/// 邮件详情页面（独立路由）。
///
/// 显示邮件的完整内容：
/// - 发件人、收件人、主题、时间
/// - 正文（HTML 渲染）
/// - 附件列表
/// - 操作按钮（回复、转发、删除等）
class MessageDetailPage extends ConsumerWidget {
  const MessageDetailPage({
    required this.messageId,
    super.key,
  });

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
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
                        await db.messageDao.deleteMessages([message.id]);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('邮件已删除')),
                          );
                          context.pop(); // 返回列表页
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('删除失败: $e')),
                          );
                        }
                      }
                    }
                  }
                  break;

                case 'mark_unread':
                  // 标记为未读
                  final newFlags = message.flagsBitmask & ~(1 << MessageFlag.seen.index);
                  await db.messageDao.updateFlags(message.id, newFlags);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已标记为未读')),
                    );
                  }
                  break;

                case 'star':
                  // 切换星标
                  final isFlagged = (message.flagsBitmask & (1 << MessageFlag.flagged.index)) != 0;
                  final newFlags = isFlagged
                      ? message.flagsBitmask & ~(1 << MessageFlag.flagged.index)
                      : message.flagsBitmask | (1 << MessageFlag.flagged.index);
                  await db.messageDao.updateFlags(message.id, newFlags);
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
                      // TODO: 连接后端 API 移动邮件
                      // 暂时只更新本地数据库
                      try {
                        // 这里应该调用后端 API，然后更新本地
                        // await syncService.moveMessage(message, targetFolder);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('移动功能需要连接后端 API\n目标文件夹: ${targetFolder.displayName}'),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('移动失败: $e')),
                          );
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
        stream: db.messageDao.watchMessage(messageId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
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
                  Text(
                    '加载失败',
                    style: theme.textTheme.bodyLarge,
                  ),
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

          return _MessageContent(message: message);
        },
      ),
    );
  }
}

/// 邮件内容组件。
class _MessageContent extends ConsumerWidget {
  const _MessageContent({
    required this.message,
  });

  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 主题
        Text(
          message.subject,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),

        // 发件人信息
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                (message.fromName ?? message.fromEmail ?? '?')[0].toUpperCase(),
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

        // 邮件正文
        FutureBuilder<MessageBody?>(
          future: ref.read(databaseProvider).messageDao.getBody(message.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final body = snapshot.data;
            if (body == null) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_download_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '正文未下载',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () {
                        // TODO: 下载邮件正文
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('下载正文'),
                    ),
                  ],
                ),
              );
            }

            // 显示正文
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HTML 正文
                if (body.htmlBody != null && body.htmlBody!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: HtmlWidget(
                      body.htmlBody!,
                      textStyle: theme.textTheme.bodyMedium,
                      onTapUrl: (url) async {
                        // 打开链接
                        try {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('无法打开链接')),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('打开链接失败: $e')),
                            );
                          }
                        }
                        return true;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ]
                // 纯文本正文（如果没有 HTML）
                else if (body.plainText != null && body.plainText!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      body.plainText!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),

                // 无正文
                if ((body.htmlBody == null || body.htmlBody!.isEmpty) &&
                    (body.plainText == null || body.plainText!.isEmpty))
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '（无正文）',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // 附件列表
        FutureBuilder<MessageBody?>(
          future: ref.read(databaseProvider).messageDao.getBody(message.id),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final attachments = AttachmentUtils.parseAttachments(
                snapshot.data!.attachmentsMeta,
              );
              return AttachmentList(attachments: attachments);
            }
            return const SizedBox.shrink();
          },
        ),
      ],
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
