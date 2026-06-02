import 'package:dio/dio.dart';

/// Webhook 服务 - 管理 Microsoft Graph 订阅和推送通知。
///
/// 通过 Cloudflare Worker 接收 Graph API 的 webhook 通知，
/// 并通过 FCM 推送到移动应用，实现真正的实时同步。
class WebhookService {
  WebhookService({
    required this.workerUrl,
  }) : _dio = Dio(BaseOptions(
          baseUrl: workerUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  final String workerUrl;
  final Dio _dio;

  /// 创建订阅。
  ///
  /// [accessToken] - 用户的 Graph API access token
  /// [userId] - 用户 ID
  /// [accountId] - 账户 ID
  /// [resource] - 要订阅的资源（默认：收件箱）
  Future<SubscriptionResult> createSubscription({
    required String accessToken,
    required String userId,
    required String accountId,
    String? resource,
  }) async {
    try {
      final response = await _dio.post(
        '/api/subscribe',
        data: {
          'accessToken': accessToken,
          'userId': userId,
          'accountId': accountId,
          'resource': resource ?? '/me/mailFolders(\'Inbox\')/messages',
        },
      );

      return SubscriptionResult(
        success: true,
        subscriptionId: response.data['subscriptionId'] as String,
        expirationDateTime: DateTime.parse(
          response.data['expirationDateTime'] as String,
        ),
      );
    } on DioException catch (e) {
      return SubscriptionResult(
        success: false,
        error: e.message ?? 'Failed to create subscription',
      );
    }
  }

  /// 续订订阅。
  ///
  /// 订阅最长有效期 3 天，需要定期续订。
  /// 建议每 2 天调用一次。
  Future<SubscriptionResult> renewSubscription({
    required String accessToken,
    required String subscriptionId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/renew',
        data: {
          'accessToken': accessToken,
          'subscriptionId': subscriptionId,
        },
      );

      return SubscriptionResult(
        success: true,
        subscriptionId: subscriptionId,
        expirationDateTime: DateTime.parse(
          response.data['expirationDateTime'] as String,
        ),
      );
    } on DioException catch (e) {
      return SubscriptionResult(
        success: false,
        error: e.message ?? 'Failed to renew subscription',
      );
    }
  }

  /// 删除订阅。
  Future<bool> deleteSubscription({
    required String accessToken,
    required String subscriptionId,
    required String userId,
  }) async {
    try {
      await _dio.post(
        '/api/unsubscribe',
        data: {
          'accessToken': accessToken,
          'subscriptionId': subscriptionId,
          'userId': userId,
        },
      );
      return true;
    } on DioException catch (e) {
      print('Failed to delete subscription: ${e.message}');
      return false;
    }
  }

  /// 注册 FCM token。
  ///
  /// 在获取到 FCM token 后调用，用于接收推送通知。
  Future<bool> registerFCMToken({
    required String userId,
    required String accountId,
    required String fcmToken,
  }) async {
    try {
      await _dio.post(
        '/api/register-fcm',
        data: {
          'userId': userId,
          'accountId': accountId,
          'fcmToken': fcmToken,
        },
      );
      return true;
    } on DioException catch (e) {
      print('Failed to register FCM token: ${e.message}');
      return false;
    }
  }

  /// 注销 FCM token。
  ///
  /// 删除账户时调用，清理 Worker KV 里的 `fcm:userId:accountId` 映射。
  Future<bool> unregisterFCMToken({
    required String userId,
    required String accountId,
  }) async {
    try {
      await _dio.post(
        '/api/unregister-fcm',
        data: {
          'userId': userId,
          'accountId': accountId,
        },
      );
      return true;
    } on DioException catch (e) {
      print('Failed to unregister FCM token: ${e.message}');
      return false;
    }
  }

  /// 健康检查。
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.data['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }
}

/// 订阅结果。
class SubscriptionResult {
  const SubscriptionResult({
    required this.success,
    this.subscriptionId,
    this.expirationDateTime,
    this.error,
  });

  final bool success;
  final String? subscriptionId;
  final DateTime? expirationDateTime;
  final String? error;
}
