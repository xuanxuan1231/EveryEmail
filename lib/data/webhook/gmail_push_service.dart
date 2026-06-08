import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Gmail 推送服务 —— 通过 Cloudflare Worker 管理 Gmail API `users.watch` 生命周期。
///
/// 与 [WebhookService]（Microsoft Graph）等价，但 Gmail 没有直接 webhook：Worker 用
/// 账户 refresh token 调 `users.watch` 把变更绑定到 Pub/Sub topic，Pub/Sub 再 push
/// 回 Worker 解析内容并发 FCM。watch 的续订由 Worker 的 Cron 负责，这里只管建立/停止。
///
/// FCM token 的注册/注销与 provider 无关（`/api/register-fcm`），仍复用 [WebhookService]。
class GmailPushService {
  GmailPushService({
    required this.workerUrl,
  }) : _dio = Dio(BaseOptions(
          baseUrl: workerUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  final String workerUrl;
  final Dio _dio;

  /// 建立（或重建）Gmail watch。
  ///
  /// [refreshToken] 会被 Worker 加密后存入 KV，供 App 被杀时服务端拉取邮件内容。
  /// [userId]/[accountId] 在本应用中相等；[email] 用于 Pub/Sub 通知的 emailAddress 反查。
  Future<GmailWatchResult> startWatch({
    required String refreshToken,
    required String userId,
    required String accountId,
    required String email,
  }) async {
    try {
      final response = await _dio.post(
        '/api/gmail/watch',
        data: {
          'refreshToken': refreshToken,
          'userId': userId,
          'accountId': accountId,
          'email': email,
        },
      );

      return GmailWatchResult(
        success: true,
        historyId: response.data['historyId']?.toString(),
        expiration: response.data['expiration']?.toString(),
      );
    } on DioException catch (e) {
      return GmailWatchResult(
        success: false,
        error: _dioErrorMessage(e, 'Failed to start Gmail watch'),
      );
    }
  }

  /// 停止 Gmail watch。Worker 仅在该邮箱再无设备注册时才真正调 `users.stop`。
  Future<bool> stopWatch({
    required String userId,
    required String accountId,
    required String email,
  }) async {
    try {
      await _dio.post(
        '/api/gmail/stop',
        data: {
          'userId': userId,
          'accountId': accountId,
          'email': email,
        },
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        'Failed to stop Gmail watch: ${_dioErrorMessage(e, 'Failed to stop Gmail watch')}',
      );
      return false;
    }
  }

  String _dioErrorMessage(DioException e, String fallback) {
    final response = e.response;
    if (response == null) {
      return e.message ?? fallback;
    }

    final data = response.data;
    if (data is Map) {
      final details = data['details'];
      if (details != null && details.toString().isNotEmpty) {
        return details.toString();
      }

      final error = data['error'];
      if (error != null && error.toString().isNotEmpty) {
        return error.toString();
      }
    }

    if (data != null && data.toString().isNotEmpty) {
      return data.toString();
    }

    return e.message ?? fallback;
  }
}

/// Gmail watch 建立结果。
class GmailWatchResult {
  const GmailWatchResult({
    required this.success,
    this.historyId,
    this.expiration,
    this.error,
  });

  final bool success;
  final String? historyId;

  /// watch 过期时间（毫秒 epoch 字符串）。Worker Cron 会在到期前续订。
  final String? expiration;
  final String? error;
}
