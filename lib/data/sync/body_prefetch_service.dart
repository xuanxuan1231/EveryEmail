// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../domain/enums/message_enums.dart';
import '../local/database/app_database.dart';
import 'sync_service.dart';

/// 邮件正文预取服务：让"点开即见内容"成为常态。
///
/// 在用户点开之前把正文下到本地（写入 [MessageBodies]），详情页便走纯本地读。
/// 真正的下载与并发控制都委托给 [SyncService]：每封正文经由账户串行队列，
/// 后台预取走低优先级、用户点开走高优先级。本服务只负责"何时、为谁"入队 +
/// 去重 + 连接感知（计费网络下不做批量后台预取）。
///
/// 触发来源：
/// - 同步落库后（[SyncService.onFolderSynced]）：收件箱最新若干封批量预取。
/// - 列表滚动可见项：[enqueueVisible]。
/// - 手指点击列表项：[enqueueOnTap]（高优先级，与转场动画重叠）。
class BodyPrefetchService {
  BodyPrefetchService({
    required SyncService syncService,
    required AppDatabase db,
    required bool Function() isPrefetchEnabled,
  }) : _syncService = syncService,
       _db = db,
       _isPrefetchEnabled = isPrefetchEnabled {
    _connSub = Connectivity().onConnectivityChanged.listen(
      (results) => _connectivity = results,
      onError: (_) {},
    );
    unawaited(_refreshConnectivity());
  }

  final SyncService _syncService;
  final AppDatabase _db;
  final bool Function() _isPrefetchEnabled;

  /// 同步后批量预取每文件夹的最新封数上限（"均衡"档）。
  static const int _folderBatchLimit = 25;

  /// 正在下载中的 messageId，避免同一封被重复入队（已下完的由 DB 查重兜底）。
  final Set<String> _inFlight = <String>{};

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  List<ConnectivityResult> _connectivity = const [];

  Future<void> _refreshConnectivity() async {
    try {
      _connectivity = await Connectivity().checkConnectivity();
    } catch (_) {
      // 读取失败时保持保守（视为计费网络），不做批量后台预取。
    }
  }

  /// 当前是否为非计费网络（Wi‑Fi / 以太网）。VPN 等会掩盖底层链路，保守视为计费。
  bool get _isUnmetered =>
      _connectivity.contains(ConnectivityResult.wifi) ||
      _connectivity.contains(ConnectivityResult.ethernet);

  /// 低优先级后台预取是否允许（设置开 + 非计费网络）。
  bool get _backgroundAllowed => _isPrefetchEnabled() && _isUnmetered;

  /// [SyncService.onFolderSynced] 回调：收件箱同步落库后批量预取最新正文。
  void handleFolderSynced(String folderId, FolderType folderType) {
    if (folderType != FolderType.inbox) return;
    unawaited(enqueueForFolder(folderId));
  }

  /// 批量预取某文件夹最新 [limit] 封中尚缺正文的邮件（后台、低优先级）。
  Future<void> enqueueForFolder(
    String folderId, {
    int limit = _folderBatchLimit,
  }) async {
    if (!_backgroundAllowed) return;
    final List<String> ids;
    try {
      ids = await _db.messageDao.messageIdsNeedingBody(folderId, limit: limit);
    } catch (e) {
      debugPrint('BodyPrefetch: 查询待预取失败: $e');
      return;
    }
    // 入队前再判一次：异步查询期间网络/设置可能已变。
    if (!_backgroundAllowed) return;
    for (final id in ids) {
      unawaited(_prefetch(id, highPriority: false));
    }
  }

  /// 列表滚动到（近）可见的邮件：后台、低优先级预取。
  void enqueueVisible(String messageId) {
    if (!_backgroundAllowed) return;
    unawaited(_prefetch(messageId, highPriority: false));
  }

  /// 用户点击/按下列表项：高优先级抢先下载，与导航转场重叠。
  ///
  /// 属于明确的用户意图，不受"自动预取"开关与计费网络限制（详情页本就会按需下载，
  /// 这里只是提前到点击瞬间触发，省去转场后的等待）。
  void enqueueOnTap(String messageId) {
    unawaited(_prefetch(messageId, highPriority: true));
  }

  Future<void> _prefetch(String messageId, {required bool highPriority}) async {
    if (_inFlight.contains(messageId)) return;

    // 已下载的直接跳过，避免无谓占用队列槽位。
    try {
      final existing = await _db.messageDao.getBody(messageId);
      if (existing != null &&
          existing.fetchState != BodyFetchState.notDownloaded) {
        return;
      }
    } catch (_) {
      // 查重失败不致命，继续尝试下载（SyncService 内部仍会再查一次）。
    }

    _inFlight.add(messageId);
    try {
      if (highPriority) {
        await _syncService.fetchMessageBody(messageId);
      } else {
        await _syncService.prefetchMessageBody(messageId);
      }
    } catch (e) {
      // 预取失败不打扰用户：下次同步 / 可见 / 点开会再次触发。
      debugPrint('BodyPrefetch: 预取正文失败($messageId): $e');
    } finally {
      _inFlight.remove(messageId);
    }
  }

  void dispose() {
    unawaited(_connSub?.cancel());
    _connSub = null;
    _inFlight.clear();
  }
}
