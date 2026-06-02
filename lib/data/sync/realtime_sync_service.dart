import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../domain/models/account_config.dart';
import 'sync_service.dart';

/// 实时同步服务。
///
/// 使用 Delta Query + 智能轮询实现接近实时的邮件同步。
///
/// 特点：
/// - 不需要服务器
/// - 动态调整同步频率
/// - 根据应用状态优化电池使用
class RealtimeSyncService {
  RealtimeSyncService(this._syncService);

  final SyncService _syncService;
  Timer? _syncTimer;
  Duration _currentInterval = const Duration(seconds: 30);
  AccountConfig? _currentAccount;
  int _consecutiveEmptySyncs = 0;

  /// 同步频率配置。
  static const Duration minInterval = Duration(seconds: 30);
  static const Duration maxInterval = Duration(minutes: 15);
  static const Duration foregroundInterval = Duration(seconds: 30);
  static const Duration backgroundInterval = Duration(minutes: 5);

  /// 启动实时同步。
  void start(AccountConfig account, {Duration? interval}) {
    stop(); // 停止现有的定时器

    _currentAccount = account;
    _currentInterval = interval ?? foregroundInterval;

    debugPrint('=== 启动实时同步 ===');
    debugPrint('账户: ${account.email}');
    debugPrint('同步间隔: ${_currentInterval.inSeconds} 秒');

    // 立即执行一次同步
    _performSync();

    // 启动定时器
    _syncTimer = Timer.periodic(_currentInterval, (timer) {
      _performSync();
    });
  }

  /// 执行同步。
  Future<void> _performSync() async {
    if (_currentAccount == null) return;

    try {
      debugPrint('执行增量同步...');
      final startTime = DateTime.now();

      await _syncService.syncAccount(_currentAccount!);

      final duration = DateTime.now().difference(startTime);
      debugPrint('同步完成，耗时: ${duration.inMilliseconds}ms');

      // 根据同步结果调整频率
      _adjustIntervalAfterSync(true);
    } catch (e) {
      debugPrint('同步失败: $e');
      _adjustIntervalAfterSync(false);
    }
  }

  /// 根据同步结果调整间隔。
  void _adjustIntervalAfterSync(bool success) {
    if (!success) {
      // 同步失败，降低频率
      _consecutiveEmptySyncs++;
      if (_consecutiveEmptySyncs >= 3) {
        _slowDown();
      }
      return;
    }

    // TODO: 检查是否有新邮件
    // 这里需要 SyncService 返回是否有新数据
    // 暂时使用简单的策略：每 5 次同步后降低一次频率
    _consecutiveEmptySyncs++;
    if (_consecutiveEmptySyncs >= 5) {
      _slowDown();
    }
  }

  /// 降低同步频率。
  void _slowDown() {
    final newInterval = Duration(
      seconds: min(_currentInterval.inSeconds * 2, maxInterval.inSeconds),
    );

    if (newInterval != _currentInterval) {
      debugPrint('降低同步频率: ${_currentInterval.inSeconds}s → ${newInterval.inSeconds}s');
      _currentInterval = newInterval;
      _consecutiveEmptySyncs = 0;

      // 重启定时器
      if (_currentAccount != null) {
        start(_currentAccount!, interval: _currentInterval);
      }
    }
  }

  /// 加快同步频率（有新邮件时）。
  void speedUp() {
    if (_currentInterval != foregroundInterval) {
      debugPrint('加快同步频率: ${_currentInterval.inSeconds}s → ${foregroundInterval.inSeconds}s');
      _currentInterval = foregroundInterval;
      _consecutiveEmptySyncs = 0;

      // 重启定时器
      if (_currentAccount != null) {
        start(_currentAccount!, interval: _currentInterval);
      }
    }
  }

  /// 切换到前台模式。
  void switchToForeground() {
    if (_currentAccount != null) {
      debugPrint('切换到前台同步模式');
      start(_currentAccount!, interval: foregroundInterval);
    }
  }

  /// 切换到后台模式。
  void switchToBackground() {
    if (_currentAccount != null) {
      debugPrint('切换到后台同步模式');
      start(_currentAccount!, interval: backgroundInterval);
    }
  }

  /// 停止实时同步。
  void stop() {
    if (_syncTimer != null) {
      debugPrint('停止实时同步');
      _syncTimer?.cancel();
      _syncTimer = null;
    }
  }

  /// 手动触发同步。
  Future<void> syncNow() async {
    if (_currentAccount != null) {
      debugPrint('手动触发同步');
      await _performSync();
      // 手动同步后恢复快速频率
      speedUp();
    }
  }

  /// 是否正在运行。
  bool get isRunning => _syncTimer != null && _syncTimer!.isActive;

  /// 当前同步间隔。
  Duration get currentInterval => _currentInterval;
}

/// 实时同步管理器 Mixin。
///
/// 在 StatefulWidget 中使用，自动管理实时同步的生命周期。
mixin RealtimeSyncManager<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  RealtimeSyncService? _realtimeSyncService;

  /// 初始化实时同步。
  void initRealtimeSync(RealtimeSyncService service, AccountConfig account) {
    _realtimeSyncService = service;
    WidgetsBinding.instance.addObserver(this);
    _realtimeSyncService?.start(account);
  }

  /// 停止实时同步。
  void stopRealtimeSync() {
    _realtimeSyncService?.stop();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // 应用回到前台
        debugPrint('应用回到前台');
        _realtimeSyncService?.switchToForeground();
        break;
      case AppLifecycleState.paused:
        // 应用进入后台
        debugPrint('应用进入后台');
        _realtimeSyncService?.switchToBackground();
        break;
      case AppLifecycleState.inactive:
        // 应用不活跃（例如来电）
        debugPrint('应用不活跃');
        break;
      case AppLifecycleState.detached:
        // 应用即将关闭
        debugPrint('应用即将关闭');
        _realtimeSyncService?.stop();
        break;
      case AppLifecycleState.hidden:
        // 应用隐藏
        debugPrint('应用隐藏');
        break;
    }
  }
}
