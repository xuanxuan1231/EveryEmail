import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings/imap_realtime_settings.dart';
import '../data/sync/realtime_sync_service.dart';
import '../data/sync/sync_service.dart';
import '../domain/enums/account_enums.dart';
import '../domain/models/account_config.dart';
import 'providers.dart';

/// 入站实时同步协调器。
///
/// 挂在 [FcmBootstrap] 同层（ProviderScope 内、MaterialApp 上）。职责：
/// - 应用回到前台/启动：对所有账户做一次兜底同步；并为 IMAP 账户启动实时机制
///   （IDLE 或前台自适应轮询，由 [ImapRealtimeSettings] 决定）。
/// - 进入后台：停止所有 IDLE/轮询，省电、释放长连接。
///
/// Graph 账户**不轮询**——靠 FCM 静默数据消息推送触发同步，这里只做一次兜底
/// （捕获应用被杀期间漏掉的 updated 推送）。
class RealtimeSyncCoordinator extends ConsumerStatefulWidget {
  const RealtimeSyncCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RealtimeSyncCoordinator> createState() =>
      _RealtimeSyncCoordinatorState();
}

class _RealtimeSyncCoordinatorState
    extends ConsumerState<RealtimeSyncCoordinator> with WidgetsBindingObserver {
  /// 每 IMAP 账户的 IDLE 事件订阅。
  final Map<String, StreamSubscription<dynamic>> _idleSubs = {};

  /// 每 IMAP 账户的前台轮询器（polling 模式）。
  final Map<String, RealtimeSyncService> _pollers = {};

  /// 自增代际：每次 start/stop 翻一次，异步流程据此判断自身是否已过期，
  /// 避免 resume/pause 快速切换时旧流程把新状态搅乱。
  int _generation = 0;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 首帧后启动，避免阻塞首屏。
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_start());
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_stop());
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _start() async {
    if (_active) return;
    _active = true;
    final gen = ++_generation;

    final syncService = ref.read(syncServiceProvider);
    final db = ref.read(databaseProvider);

    final List<dynamic> rows;
    try {
      rows = await db.accountDao.getAccounts();
    } catch (e) {
      debugPrint('RealtimeSyncCoordinator: 读取账户失败: $e');
      return;
    }
    if (gen != _generation) return; // 期间已 stop

    for (final row in rows) {
      if (gen != _generation) return;
      try {
        final account = await syncService.accountConfigFor(row.id as String);
        await _startAccountRealtime(syncService, account, gen);
      } catch (e) {
        debugPrint('RealtimeSyncCoordinator: 启动账户实时失败: $e');
      }
    }
  }

  Future<void> _startAccountRealtime(
    SyncService syncService,
    AccountConfig account,
    int gen,
  ) async {
    // Graph：不轮询，靠 FCM 静默推送；这里只做一次兜底同步。
    if (account.type == AccountType.microsoftGraph) {
      syncService.requestSync(account);
      return;
    }

    // IMAP：按设置启动 IDLE（默认）或前台自适应轮询。
    final mode = await ImapRealtimeSettings.read();
    if (gen != _generation) return;

    if (mode == ImapRealtimeMode.polling) {
      final poller = RealtimeSyncService(syncService);
      _pollers[account.id] = poller;
      poller.start(account); // 内部立即同步一次 + 自适应定时
      return;
    }

    // IDLE 模式：先同步一次（建立连接 + 列文件夹，IDLE 需要先选中收件箱），再监听事件。
    try {
      await syncService.syncAccount(account);
      if (gen != _generation) return;
      final stream = await syncService.watchAccountInbox(account);
      if (stream == null || gen != _generation) return;
      _idleSubs[account.id] = stream.listen(
        (_) => syncService.requestSync(account),
        onError: (Object e) => debugPrint('IMAP IDLE 事件错误: $e'),
      );
    } catch (e) {
      debugPrint('启动 IMAP IDLE 失败（${account.email}）: $e');
    }
  }

  Future<void> _stop() async {
    _active = false;
    _generation++;
    for (final sub in _idleSubs.values) {
      await sub.cancel();
    }
    _idleSubs.clear();
    for (final poller in _pollers.values) {
      poller.stop();
    }
    _pollers.clear();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
