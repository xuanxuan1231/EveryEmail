import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/settings/worker_settings.dart';

Future<void> showWorkerUrlEditor(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _WorkerUrlEditorSheet(),
  );
}

class _WorkerUrlEditorSheet extends ConsumerStatefulWidget {
  const _WorkerUrlEditorSheet();

  @override
  ConsumerState<_WorkerUrlEditorSheet> createState() =>
      _WorkerUrlEditorSheetState();
}

class _WorkerUrlEditorSheetState extends ConsumerState<_WorkerUrlEditorSheet> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(workerSettingsProvider).workerBaseUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('推送服务 Worker', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'OAuth 兑换、实时推送、FCM 注册会使用这个 Worker。Gmail 推送会把 refresh token 交给该 Worker 加密存储；请只使用你信任的地址。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            enabled: !_isSaving,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Worker URL',
              hintText: WorkerSettings.defaults.workerBaseUrl,
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => unawaited(_save()),
          ),
          const SizedBox(height: 12),
          Text(
            '保存后会先撤销旧 Worker 上已有的 Graph/Gmail 推送订阅和 FCM 映射，再在新地址重新创建。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        _controller.text =
                            WorkerSettings.defaults.workerBaseUrl;
                        setState(() => _errorText = null);
                      },
                child: const Text('恢复默认'),
              ),
              const Spacer(),
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : () => unawaited(_save()),
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    String normalized;
    try {
      normalized = WorkerSettings.normalizeWorkerBaseUrl(_controller.text);
    } on FormatException catch (e) {
      setState(() => _errorText = e.message);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref
          .read(workerSettingsProvider.notifier)
          .setWorkerBaseUrl(normalized);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = '保存失败：$e';
      });
    }
  }
}
