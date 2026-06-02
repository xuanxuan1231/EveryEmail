import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/models/mail_attachment.dart';

/// 附件列表组件。
class AttachmentList extends StatelessWidget {
  const AttachmentList({
    required this.attachments,
    super.key,
  });

  final List<MailAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.attach_file,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              '附件 (${attachments.length})',
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...attachments.map((attachment) => _AttachmentItem(attachment: attachment)),
      ],
    );
  }
}

/// 单个附件项。
class _AttachmentItem extends StatelessWidget {
  const _AttachmentItem({
    required this.attachment,
  });

  final MailAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    attachment.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 文件信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.filename ?? '未命名附件',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          attachment.formattedSize,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          attachment.extension.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 下载按钮
              IconButton(
                icon: Icon(
                  attachment.localPath != null ? Icons.check_circle : Icons.download,
                  color: attachment.localPath != null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => _handleDownload(context),
                tooltip: attachment.localPath != null ? '已下载' : '下载',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (attachment.localPath != null) {
      // 打开本地文件
      _openFile(context, attachment.localPath!);
    } else {
      // 提示下载
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('点击下载按钮下载 ${attachment.filename ?? "附件"}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleDownload(BuildContext context) {
    if (attachment.localPath != null) {
      // 已下载，打开文件
      _openFile(context, attachment.localPath!);
    } else {
      // TODO: 实现下载功能
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('下载功能待实现：${attachment.filename ?? "附件"}'),
          action: SnackBarAction(
            label: '确定',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _openFile(BuildContext context, String path) async {
    try {
      final uri = Uri.file(path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开文件')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件失败: $e')),
        );
      }
    }
  }
}
