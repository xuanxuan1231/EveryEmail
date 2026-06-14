import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Android IMAP 后台实时同步前台服务。
///
/// 它本身不做同步逻辑；同步仍由主 isolate 中的 IMAP IDLE/轮询负责。服务的作用是
/// 在应用进入后台后保持进程、网络和 CPU 唤醒锁，尽量让 IDLE 长连接继续收到事件。
class ImapForegroundService {
  const ImapForegroundService._();

  static const int _serviceId = 7001;
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'imap_realtime_sync',
        channelName: 'IMAP 实时同步',
        channelDescription: '保持 IMAP 连接以接收新邮件。',
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5 * 60 * 1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
    _initialized = true;
  }

  static Future<bool> start({required int accountCount}) async {
    if (kIsWeb || !Platform.isAndroid || accountCount <= 0) return false;

    try {
      await ensureInitialized();
      await _requestNotificationPermissionIfNeeded();
      final title = 'EveryEmail 正在同步 IMAP';
      final text = accountCount == 1
          ? '保持 1 个邮箱的实时连接'
          : '保持 $accountCount 个邮箱的实时连接';

      final ServiceRequestResult result;
      if (await FlutterForegroundTask.isRunningService) {
        result = await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
          callback: imapForegroundTaskStartCallback,
        );
      } else {
        result = await FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: const [ForegroundServiceTypes.dataSync],
          notificationTitle: title,
          notificationText: text,
          notificationInitialRoute: '/',
          callback: imapForegroundTaskStartCallback,
        );
      }
      if (result is ServiceRequestFailure) {
        debugPrint('IMAP 前台服务启动失败: ${result.error}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('IMAP 前台服务启动异常: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        final result = await FlutterForegroundTask.stopService();
        if (result is ServiceRequestFailure) {
          debugPrint('IMAP 前台服务停止失败: ${result.error}');
        }
      }
    } catch (e) {
      debugPrint('IMAP 前台服务停止异常: $e');
    }
  }

  static Future<void> _requestNotificationPermissionIfNeeded() async {
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }
}

@pragma('vm:entry-point')
void imapForegroundTaskStartCallback() {
  FlutterForegroundTask.setTaskHandler(_ImapForegroundTaskHandler());
}

class _ImapForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _touch(timestamp);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _touch(timestamp);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  void _touch(DateTime timestamp) {
    unawaited(
      FlutterForegroundTask.updateService(
        notificationTitle: 'EveryEmail 正在同步 IMAP',
        notificationText: '上次保活 ${_formatTime(timestamp)}',
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
