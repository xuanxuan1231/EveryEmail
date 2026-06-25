import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/providers.dart';
import '../../data/local/database/app_database.dart';
import '../../data/sync/send_queue_service.dart';
import '../../domain/enums/message_enums.dart';
import '../../domain/models/outgoing_message.dart';

/// 发送队列页：列出排队中 / 发送中 / 失败的待发送邮件，可单条重试/取消，
/// 或一键重试全部失败任务。任务发送成功后自动从列表消失。
class SendQueuePage extends ConsumerWidget {
  const SendQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasks = ref.watch(sendQueueTasksProvider).value ?? const <SendTask>[];
    final hasFailure = tasks.any((t) => t.status == SendTaskStatus.failed);
    final service = ref.read(sendQueueServiceProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('发送队列'),
        actions: [
          if (hasFailure)
            TextButton.icon(
              onPressed: () => service.retryAll(manual: true),
              icon: const Icon(Symbols.refresh),
              label: const Text('全部重试'),
            ),
        ],
      ),
      body: tasks.isEmpty
          ? _buildEmpty(theme)
          : ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _SendTaskTile(task: tasks[index], service: service),
            ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Symbols.outbox,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '发送队列为空',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SendTaskTile extends StatelessWidget {
  const _SendTaskTile({required this.task, required this.service});

  final SendTask task;
  final SendQueueService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    OutgoingMessage? message;
    try {
      message = OutgoingMessage.decode(task.payload);
    } catch (_) {
      message = null;
    }

    final subject = (message?.subject.trim().isNotEmpty ?? false)
        ? message!.subject
        : '(无主题)';
    final recipients = message == null
        ? ''
        : message.to.map((a) => a.displayName).join(', ');
    final attachmentCount = message?.attachments.length ?? 0;
    final isFailed = task.status == SendTaskStatus.failed;
    final statusLabel = _statusLabel(task, attachmentCount: attachmentCount);

    return ListTile(
      leading: _statusIcon(theme, task.status),
      title: Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recipients.isNotEmpty)
            Text(
              '收件人: $recipients',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            statusLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isFailed
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: isFailed ? 4 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      isThreeLine: isFailed || recipients.isNotEmpty || attachmentCount > 0,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFailed && task.lastError != null)
            IconButton(
              icon: const Icon(Symbols.info),
              tooltip: '错误详情',
              onPressed: () => _showErrorDetails(context, statusLabel),
            ),
          if (isFailed)
            IconButton(
              icon: const Icon(Symbols.refresh),
              tooltip: '重试',
              onPressed: () => service.retry(task.id),
            ),
          IconButton(
            icon: const Icon(Symbols.close),
            tooltip: '取消',
            onPressed: () => service.cancel(task.id),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDetails(BuildContext context, String error) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发送失败详情'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(child: SelectableText(error)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: error));
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('复制'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(ThemeData theme, SendTaskStatus status) {
    switch (status) {
      case SendTaskStatus.queued:
        return Icon(
          Symbols.schedule,
          color: theme.colorScheme.onSurfaceVariant,
        );
      case SendTaskStatus.sending:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      case SendTaskStatus.failed:
        return Icon(Symbols.error, color: theme.colorScheme.error);
    }
  }

  String _statusLabel(SendTask task, {required int attachmentCount}) {
    final attempts = task.attempts == 0 ? '' : '，已尝试 ${task.attempts} 次';
    final attachments = attachmentCount == 0 ? '' : '，$attachmentCount 个附件';
    switch (task.status) {
      case SendTaskStatus.queued:
        return '等待发送$attachments';
      case SendTaskStatus.sending:
        return '正在发送$attachments…';
      case SendTaskStatus.failed:
        return '${task.lastError ?? '发送失败：未知错误'}$attempts$attachments';
    }
  }
}
