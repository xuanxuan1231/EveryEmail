import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings/imap_realtime_settings.dart';
import '../data/settings/account_settings.dart';
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
    extends ConsumerState<RealtimeSyncCoordinator>
    with WidgetsBindingObserver {
  /// 每 IMAP 账户的 IDLE 事件订阅。
  final Map<String, StreamSubscription<dynamic>> _idleSubs = {};

  /// 每 IMAP 账户的前台轮询器（polling 模式）。
  final Map<String, RealtimeSyncService> _pollers = {};

  /// 自增代际：每次 start/stop 翻一次，异步流程据此判断自身是否已过期，
  /// 避免 resume/pause 快速切换时旧流程把新状态搅乱。
  int _generation = 0;
  bool _active = false;

  /// 周期性刷新定时器：持续前台时让 OAuth IMAP 长连接在 token 过期前重连。
  Timer? _refreshTimer;

  /// 刷新检查间隔。实际是否重连由 [SyncService.isBackendStale]（OAuth 新鲜期 ~40min）
  /// 决定，间隔取得比新鲜期小，保证过期后能较快被检出并在 token 寿命内重连。
  static const Duration _staleCheckInterval = Duration(minutes: 10);

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

    // 启动周期刷新（持续前台时让 OAuth 长连接在 token 过期前重连）。pause 时 _stop 取消。
    _refreshTimer ??= Timer.periodic(
      _staleCheckInterval,
      (_) => unawaited(_refreshStaleConnections()),
    );

    final syncService = ref.read(syncServiceProvider);
    final db = ref.read(databaseProvider);

    // 实例化正文预取服务，确保其 onFolderSynced 回调在首次同步前已挂接到
    // SyncService（否则首轮同步的批量预取会丢失）。
    ref.read(bodyPrefetchServiceProvider);

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
    final accountSettings = await AccountSettingsStore.read(account.id);
    if (!accountSettings.receiveEnabled) return;
    if (!accountSettings.realtimeSyncEnabled) {
      syncService.requestSync(account);
      return;
    }

    // Graph 与 Gmail（REST API 后端）：不轮询/不 IDLE，靠 FCM 静默推送触发同步；
    // 这里只做一次兜底同步（捕获应用被杀期间漏掉的推送）。Gmail 的实时推送由
    // users.watch + Pub/Sub → Worker → FCM 提供，与 Graph 同一套处理链路。
    if (account.type == AccountType.microsoftGraph ||
        account.type == AccountType.gmailOAuth) {
      syncService.requestSync(account);
      return;
    }

    // IMAP（含 Gmail OAuth）：回前台时若 OAuth 连接已过新鲜期，先主动重连拉新 token
    // 再继续。enough_mail 的自动重连只复用旧 token，长时间后台后会在过期连接上认证
    // 失败且不自愈，故必须走完整重连。密码连接 isBackendStale 恒为 false，不受影响。
    if (syncService.isBackendStale(account)) {
      try {
        await syncService.reconnectBackend(account);
      } catch (e) {
        debugPrint('回前台重连 IMAP 失败（${account.email}）: $e');
      }
      if (gen != _generation) return;
    }

    // IMAP：按账户设置启动 IDLE（默认）或前台自适应轮询。
    final mode = await ImapRealtimeSettings.readForAccount(account.id);
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
    _refreshTimer?.cancel();
    _refreshTimer = null;
    for (final sub in _idleSubs.values) {
      await sub.cancel();
    }
    _idleSubs.clear();
    for (final poller in _pollers.values) {
      poller.stop();
    }
    _pollers.clear();
  }

  /// 周期刷新：持续前台时，IDLE 长连接一旦超过 OAuth 新鲜期就主动重连刷新 token
  /// 并重建监听。enough_mail 的自动重连复用旧 token，连接寿命超过 token（~1h）后会
  /// 认证失败且不自愈——本方法在 token 寿命内抢先重连规避之。仅处理 OAuth 账户
  /// （[SyncService.isBackendStale] 对密码连接恒为 false）。
  Future<void> _refreshStaleConnections() async {
    if (!_active) return;
    final gen = _generation;
    final syncService = ref.read(syncServiceProvider);

    // IDLE 账户：重连会重建 client、令旧订阅失效，故须撤旧监听 → 重连 → 重挂监听。
    for (final accountId in _idleSubs.keys.toList()) {
      if (gen != _generation) return;
      final AccountConfig account;
      try {
        account = await syncService.accountConfigFor(accountId);
      } catch (_) {
        continue;
      }
      if (!syncService.isBackendStale(account)) continue;

      try {
        await _idleSubs.remove(accountId)?.cancel();
        await syncService.reconnectBackend(account);
        if (gen != _generation) return;
        final stream = await syncService.watchAccountInbox(account);
        if (stream == null || gen != _generation) return;
        _idleSubs[accountId] = stream.listen(
          (_) => syncService.requestSync(account),
          onError: (Object e) => debugPrint('IMAP IDLE 事件错误: $e'),
        );
        // 重连间隙可能漏掉变更，触发一次兜底同步。
        syncService.requestSync(account);
      } catch (e) {
        debugPrint('周期刷新 IMAP IDLE 连接失败: $e');
      }
    }

    // 轮询账户：无持久 IDLE，重连后由轮询器自行继续同步，无需重挂监听。
    for (final accountId in _pollers.keys.toList()) {
      if (gen != _generation) return;
      try {
        final account = await syncService.accountConfigFor(accountId);
        if (syncService.isBackendStale(account)) {
          await syncService.reconnectBackend(account);
        }
      } catch (e) {
        debugPrint('周期刷新 IMAP 轮询连接失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
