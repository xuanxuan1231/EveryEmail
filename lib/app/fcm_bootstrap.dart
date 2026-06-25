import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/notification_channels.dart';
import '../data/local/database/app_database.dart';
import 'providers.dart';

/// FCM 后台消息处理器。
///
/// 新邮件(created)走 notification 消息，由系统/GMS 直接弹到托盘，**不会进入此
/// handler**；updated 静默 data 消息会进来，但后台 isolate 没有 Riverpod 容器、
/// 无法触发同步，留给应用回前台时 RealtimeSyncCoordinator 的 resume 兜底同步。
/// 仍需保留一个顶层 handler 以满足 [FirebaseMessaging.onBackgroundMessage] 注册。
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('后台消息: ${message.messageId} data=${message.data}');
}

/// 应用启动后异步完成 Firebase 初始化、FCM token 注册、Microsoft 订阅启用，
/// 并接好前台/点击的消息监听器。
///
/// 必须放在 [ProviderScope] 内：需要 ref.read(webhookManagerProvider)。
/// 放在 [MaterialApp] 之上：不能依赖路由或主题，否则首屏会被阻塞。
class FcmBootstrap extends ConsumerStatefulWidget {
  const FcmBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FcmBootstrap> createState() => _FcmBootstrapState();
}

class _FcmBootstrapState extends ConsumerState<FcmBootstrap> {
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  @override
  void initState() {
    super.initState();
    // Play Services 异常或离线时这里可能挂很久——一定要异步，不能阻塞首屏。
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 请求权限并检查授予结果。Android 13+ 必须 authorized 才会显示通知。
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('通知权限状态: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ 用户拒绝了通知权限，推送将不会显示。请到系统设置开启。');
      }

      final manager = ref.read(webhookManagerProvider);
      final gmailManager = ref.read(gmailWatchManagerProvider);

      // 启动时把所有 Microsoft 账户的订阅续上 / 缺失的建上。
      // 不 await：subscribe 是远端往返，不阻塞前台 UI。
      unawaited(manager.enableForAllMicrosoftAccounts());

      // 同样为所有 Gmail 账户建立 watch（Worker 端幂等 upsert，续订交给 Worker Cron）。
      unawaited(gmailManager.enableForAllGmailAccounts());

      // 拿到 token 后给所有账户注册到 Worker（FCM 注册端点与 provider 无关）。
      final fcmToken = await messaging.getToken();
      debugPrint('FCM Token: $fcmToken');
      if (fcmToken != null) {
        ref.read(fcmTokenProvider.notifier).state = fcmToken;
        unawaited(manager.registerFcmTokenForAllMicrosoftAccounts(fcmToken));
        unawaited(gmailManager.registerFcmTokenForAllGmailAccounts(fcmToken));
      }

      // token 刷新（应用升级、Play Services 重启等）：重新注册。
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token 刷新: $newToken');
        ref.read(fcmTokenProvider.notifier).state = newToken;
        unawaited(
          ref
              .read(webhookManagerProvider)
              .registerFcmTokenForAllMicrosoftAccounts(newToken),
        );
        unawaited(
          ref
              .read(gmailWatchManagerProvider)
              .registerFcmTokenForAllGmailAccounts(newToken),
        );
      });

      // 前台收到推送：
      // - created notification 消息：前台系统不自动弹，但邮件列表是 Drift 响应式流，
      //   触发同步后会自动刷新，无需手动弹通知。
      // - updated 静默 data 消息：同样触发增量同步。
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        debugPrint('前台消息: ${message.messageId} data=${message.data}');
        unawaited(manager.handlePushNotification(message.data));
      });

      // 用户点击系统通知进入：触发同步，确保打开后立即看到新邮件。
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('通知点击: ${message.messageId} data=${message.data}');
        unawaited(manager.handlePushNotification(message.data));
      });

      // 冷启动：应用是通过点击通知打开的，补一次同步。
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        debugPrint('冷启动通知: ${initial.messageId} data=${initial.data}');
        unawaited(manager.handlePushNotification(initial.data));
      }
    } catch (e, st) {
      debugPrint('FCM 初始化失败（不影响主流程）: $e\n$st');
    }
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 账户列表变化（增、删、改名）时重新同步通知渠道。渠道不依赖 Firebase，独立于上面的
    // FCM 流程；放在这里只为复用 FcmBootstrap 的生命周期位置。首次数据到达也会触发一次。
    ref.listen<AsyncValue<List<Account>>>(accountsProvider, (_, next) {
      next.whenData(_syncNotificationChannels);
    });
    return widget.child;
  }

  void _syncNotificationChannels(List<Account> accounts) {
    unawaited(
      NotificationChannels.sync([
        for (final account in accounts)
          (
            id: account.id,
            name: account.displayName.trim().isNotEmpty
                ? account.displayName
                : account.email,
          ),
      ]),
    );
  }
}
