import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:open_filex/open_filex.dart';

import '../../../app/providers.dart';
import '../../../domain/models/mail_attachment.dart';

/// 附件列表组件。
class AttachmentList extends StatelessWidget {
  const AttachmentList({
    required this.attachments,
    required this.messageId,
    super.key,
  });

  final List<MailAttachment> attachments;

  /// 所属邮件的本地 id，用于按需下载附件字节。
  final String messageId;

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
              Symbols.attach_file,
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
        ...attachments.map(
          (attachment) => _AttachmentItem(
            key: ValueKey(attachment.partId),
            attachment: attachment,
            messageId: messageId,
          ),
        ),
      ],
    );
  }
}

/// 单个附件项。点按/下载按钮：未下载则取字节存本地，已下载则打开本地文件。
class _AttachmentItem extends ConsumerStatefulWidget {
  const _AttachmentItem({
    required this.attachment,
    required this.messageId,
    super.key,
  });

  final MailAttachment attachment;
  final String messageId;

  @override
  ConsumerState<_AttachmentItem> createState() => _AttachmentItemState();
}

class _AttachmentItemState extends ConsumerState<_AttachmentItem> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attachment = widget.attachment;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: _downloading ? null : _onPrimaryAction,
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

              // 下载 / 打开 按钮（下载中显示进度）
              _buildTrailing(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(ThemeData theme) {
    if (_downloading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final downloaded = widget.attachment.localPath != null;
    return IconButton(
      icon: Icon(
        downloaded ? Symbols.check_circle : Symbols.download,
        color: downloaded
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      onPressed: _onPrimaryAction,
      tooltip: downloaded ? '打开' : '下载',
    );
  }

  Future<void> _onPrimaryAction() async {
    final path = widget.attachment.localPath;
    if (path != null) {
      await _openFile(path);
    } else {
      await _download();
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      // 下载完成后由 SyncService 把 localPath 写回 attachmentsMeta，详情页 watchBody
      // 会响应式重建本组件，按钮自动切换为"打开"。
      await ref
          .read(syncServiceProvider)
          .downloadAttachment(
            messageId: widget.messageId,
            partId: widget.attachment.partId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已下载 ${widget.attachment.filename ?? "附件"}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下载失败: $e')));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openFile(String path) async {
    // open_filex 在 Android 上经内置 FileProvider 以 content:// 打开应用私有目录的
    // 文件（url_launcher 的 file:// 在 Android 会被系统拦），并在各平台调用默认应用。
    // 传 MIME 提示帮 Android 选对应用；通用 octet-stream 则留空，让其按扩展名推断。
    final mime = widget.attachment.mimeType;
    final result = await OpenFilex.open(
      path,
      type: (mime.isEmpty || mime == 'application/octet-stream') ? null : mime,
    );
    if (!mounted || result.type == ResultType.done) return;
    final message = switch (result.type) {
      ResultType.noAppToOpen => '没有可打开此类文件的应用',
      ResultType.fileNotFound => '文件不存在，请重新下载',
      ResultType.permissionDenied => '无权限打开文件',
      _ => '打开文件失败: ${result.message}',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
