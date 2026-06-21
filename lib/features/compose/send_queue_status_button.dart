import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/providers.dart';
import '../../domain/enums/message_enums.dart';

/// 主界面顶栏的发送队列状态按钮。
///
/// 队列为空时不显示。有失败任务时以**红色角标**醒目提示失败数（持续可见直到清空）；
/// 否则以主色角标显示排队/发送中的任务数。点击进入发送队列页查看与重试。
class SendQueueStatusButton extends ConsumerWidget {
  const SendQueueStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(sendQueueTasksProvider).value ?? const [];
    if (tasks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final failed = tasks
        .where((t) => t.status == SendTaskStatus.failed)
        .length;
    final hasFailure = failed > 0;

    final icon = IconButton(
      icon: Icon(
        hasFailure ? Symbols.error : Symbols.outbox,
        color: hasFailure ? theme.colorScheme.error : null,
      ),
      tooltip: hasFailure ? '$failed 封发送失败' : '发送队列（${tasks.length}）',
      onPressed: () => context.push('/send-queue'),
    );

    return Badge(
      label: Text('${hasFailure ? failed : tasks.length}'),
      backgroundColor: hasFailure ? theme.colorScheme.error : null,
      offset: const Offset(-6, 6),
      child: icon,
    );
  }
}
