import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/settings/app_font_settings.dart';
import '../../data/settings/imap_realtime_settings.dart';

/// 应用设置页。目前承载 IMAP 实时同步方式开关。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  ImapRealtimeMode? _mode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await ImapRealtimeSettings.read();
    if (mounted) setState(() => _mode = mode);
  }

  Future<void> _setIdle(bool useIdle) async {
    final mode = useIdle ? ImapRealtimeMode.idle : ImapRealtimeMode.polling;
    setState(() => _mode = mode);
    await ImapRealtimeSettings.write(mode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存，下次回到前台/重启应用后生效')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'IMAP 实时同步',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          SwitchListTile(
            title: const Text('IMAP IDLE 实时同步'),
            subtitle: const Text(
              '开：保持长连接，新邮件与已读/标志变更近实时（推荐）。\n'
              '关：仅前台定时增量轮询，更省电但有延迟。',
            ),
            value: _mode == ImapRealtimeMode.idle,
            onChanged: _mode == null ? null : _setIdle,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Microsoft 账户通过推送（含静默数据消息）实时同步，不受此设置影响。',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '字体',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          SwitchListTile(
            title: const Text('使用 Google Sans Flex 字体'),
            subtitle: const Text(
              '开：全应用（含正文）改用内置的 Google Sans Flex 字体，代替系统字体。\n'
              '关：使用系统默认字体。',
            ),
            value: ref.watch(appFontProvider) == AppFont.googleSansFlex,
            onChanged: (useFlex) => ref
                .read(appFontProvider.notifier)
                .set(useFlex ? AppFont.googleSansFlex : AppFont.system),
          ),
        ],
      ),
    );
  }
}
