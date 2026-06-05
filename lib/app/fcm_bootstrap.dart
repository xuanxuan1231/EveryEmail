import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// FCM 默认通知渠道 id。必须三方对齐：
/// - 本文件创建的 [AndroidNotificationChannel]
/// - AndroidManifest meta-data com.google.firebase.messaging.default_notification_channel_id
/// - Worker payload android.notification.channel_id
const String kDefaultChannelId = 'everyemail_default';

/// FCM 初始化的后台消息处理器。
///
/// 注意：后台 isolate 没有 Riverpod 容器，这里只做最小处理。
/// - created 通知消息：应用在后台/被杀时由系统托盘自动显示，无需手动弹。
/// - updated 静默数据消息：后台不弹通知（符合预期）；完整增量同步交给下次回前台时
///   由 RealtimeSyncCoordinator 的 resume 兜底同步统一拉起（保证级后台同步需平台后台任务）。
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('后台消息: ${message.messageId} data=${message.data}');
}

/// 应用启动后异步完成 Firebase 初始化、通知渠道创建、FCM token 注册、
/// Microsoft 订阅启用，并接好前台/后台点击的消息监听器。
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
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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

      // 1. 先把本地通知插件和渠道建好——后续前台弹通知、以及让系统
      //    认得 Worker payload 里的 channel_id 都依赖这个渠道存在。
      await _initLocalNotifications();

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2. 请求权限并检查授予结果。Android 13+ 必须 authorized 才会显示通知。
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

      // 3. 启动时把所有 Microsoft 账户的订阅续上 / 缺失的建上。
      //    不 await：subscribe 是远端往返，不阻塞前台 UI。
      unawaited(manager.enableForAllMicrosoftAccounts());

      // 4. 拿到 token 后给所有 Microsoft 账户注册到 Worker。
      final fcmToken = await messaging.getToken();
      debugPrint('FCM Token: $fcmToken');
      if (fcmToken != null) {
        ref.read(fcmTokenProvider.notifier).state = fcmToken;
        unawaited(manager.registerFcmTokenForAllMicrosoftAccounts(fcmToken));
      }

      // 5. 后续 token 刷新（应用升级、Play Services 重启等）：重新注册。
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token 刷新: $newToken');
        ref.read(fcmTokenProvider.notifier).state = newToken;
        unawaited(manager.registerFcmTokenForAllMicrosoftAccounts(newToken));
      });

      // 6. 前台收到推送：
      //    - 新邮件（notification 消息）：FCM 前台**不会**自动弹托盘，需手动弹 + 同步。
      //    - 静默数据消息（updated 已读/标志变更）：不弹通知，仅触发增量同步。
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        debugPrint('前台消息: ${message.messageId} data=${message.data}');
        final isSilent =
            message.notification == null || message.data['silent'] == 'true';
        if (!isSilent) {
          _showLocalNotification(message);
        }
        // 不论是否静默都触发同步——静默数据消息正是为触发同步而来。
        unawaited(manager.handlePushNotification(message.data));
      });

      // 7. 用户从通知点进来：触发同步，确保打开后立刻看到新邮件。
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('通知点击: ${message.messageId} data=${message.data}');
        unawaited(manager.handlePushNotification(message.data));
      });

      // 8. 冷启动：应用是通过点击通知打开的，补一次同步。
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        debugPrint('冷启动通知: ${initial.messageId} data=${initial.data}');
        unawaited(manager.handlePushNotification(initial.data));
      }
    } catch (e, st) {
      debugPrint('FCM 初始化失败（不影响主流程）: $e\n$st');
    }
  }

  /// 初始化本地通知插件并创建默认渠道。
  Future<void> _initLocalNotifications() async {
    // 用 launcher icon 作为通知小图标：res 里没有专门的 ic_notification。
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // 前台本地通知被点击：交给 WebhookManager 触发同步。
        final accountId = response.payload;
        if (accountId != null && accountId.isNotEmpty) {
          unawaited(
            ref
                .read(webhookManagerProvider)
                .handlePushNotification({'accountId': accountId}),
          );
        }
      },
    );

    // 创建渠道（已存在则无副作用）。IMPORTANCE_HIGH 才会浮动横幅 + 声音。
    const channel = AndroidNotificationChannel(
      kDefaultChannelId,
      '新邮件',
      description: '推送新邮件到达通知',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 前台手动弹一条本地通知。
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? '新邮件';
    final body = notification?.body ?? '您有新邮件';
    final accountId = message.data['accountId'] as String?;
    final emailMessageId = message.data['messageId'] as String?;

    const androidDetails = AndroidNotificationDetails(
      kDefaultChannelId,
      '新邮件',
      channelDescription: '推送新邮件到达通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    _localNotifications.show(
      // 用邮件 messageId 派生通知 id：同一封邮件若被重复推送会覆盖而非堆叠。
      // 没有邮件 id 时退回 FCM messageId hashCode，再退回时间戳，保证每条独立。
      id: (emailMessageId != null && emailMessageId.isNotEmpty)
          ? emailMessageId.hashCode
          : message.messageId?.hashCode ??
              DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: accountId,
    );
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
