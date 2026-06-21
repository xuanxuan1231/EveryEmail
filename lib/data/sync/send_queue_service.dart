// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/id_generator.dart' as id_gen;
import '../../domain/enums/account_enums.dart';
import '../../domain/enums/message_enums.dart';
import '../../domain/models/outgoing_message.dart';
import '../backends/mail_backend.dart';
import '../local/database/app_database.dart';
import 'sync_service.dart';

/// 发送队列服务：撰写/回复/转发提交的邮件在此排队、发送、失败重试。
///
/// 刻意独立于 [SyncService.flushOutbox]（后者只回推已读/移动/删除）。发送是「直接
/// 发送 + 失败入队重试」：[enqueue] 落库后立即 [processQueue]；失败则任务转 failed，
/// 由主界面顶栏红点提示，并在恢复网络 / 回到前台 / 用户手动时重试。
class SendQueueService {
  SendQueueService({required AppDatabase db, required SyncService syncService})
    : _db = db,
      _syncService = syncService {
    // 网络恢复即重试：失败任务重新入队并连同排队中的一起发送。
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (online) unawaited(retryAll());
    });
  }

  final AppDatabase _db;
  final SyncService _syncService;

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  /// 串行处理标志：保证同一时刻只有一轮发送在跑，避免并发触碰后端连接 / 重复发送。
  bool _processing = false;

  /// 监听全部未完成任务（顶栏角标与队列页消费）。
  Stream<List<SendTask>> watchTasks() => _db.sendTaskDao.watchAll();

  /// 入队一封待发送邮件并立即尝试发送。返回任务 id。
  ///
  /// [draftMessageId]：若由本地草稿发出，发送成功后一并删除该草稿。
  Future<String> enqueue(
    String accountId,
    OutgoingMessage message, {
    String? draftMessageId,
  }) async {
    final id = id_gen.generateId();
    await _db.sendTaskDao.insertTask(
      SendTasksCompanion.insert(
        id: id,
        accountId: accountId,
        payload: message.encode(),
        draftMessageId: Value(draftMessageId),
      ),
    );
    unawaited(processQueue());
    return id;
  }

  /// 处理队列：逐个发送所有可发送任务（queued + 残留 sending）。串行执行，并在
  /// 一轮发完后再取一次——覆盖发送期间新入队的任务，避免它们滞留到下次触发。
  Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      while (true) {
        final tasks = await _db.sendTaskDao.getSendable();
        if (tasks.isEmpty) break;
        for (final task in tasks) {
          await _sendOne(task);
        }
      }
    } catch (e) {
      debugPrint('SendQueueService.processQueue 失败: $e');
    } finally {
      _processing = false;
    }
  }

  Future<void> _sendOne(SendTask task) async {
    await _db.sendTaskDao.updateStatus(
      task.id,
      SendTaskStatus.sending,
      clearError: true,
    );
    OutgoingMessage message;
    try {
      message = OutgoingMessage.decode(task.payload);
    } catch (e) {
      // 载荷损坏不可恢复：直接丢弃，避免坏任务永久占据队列。
      debugPrint('SendQueueService: 任务载荷损坏，丢弃 ${task.id}: $e');
      await _db.sendTaskDao.remove(task.id);
      return;
    }

    late final AccountType accountType;
    try {
      final account = await _syncService.accountConfigFor(task.accountId);
      accountType = account.type;
      await _syncService.sendViaBackend(account, message);
    } catch (e) {
      await _db.sendTaskDao.incrementAttempts(task.id);
      await _db.sendTaskDao.updateStatus(
        task.id,
        SendTaskStatus.failed,
        error: _friendlyError(e),
      );
      return;
    }

    try {
      await _onSent(task, message, accountType: accountType);
    } catch (e) {
      debugPrint('SendQueueService: 已发送任务清理失败 ${task.id}: $e');
    }
  }

  /// 发送成功的清理：删除关联草稿、清理附件临时文件、移除任务。
  Future<void> _onSent(
    SendTask task,
    OutgoingMessage message, {
    required AccountType accountType,
  }) async {
    await _db.sendTaskDao.remove(task.id);

    final draftId = task.draftMessageId;
    if (accountType == AccountType.genericImap && draftId != null) {
      try {
        await _syncService.deleteServerDraft(
          accountId: task.accountId,
          serverDraftId: message.serverDraftId,
        );
      } catch (e) {
        debugPrint('SendQueueService: IMAP 服务端草稿清理失败: $e');
      }
    }
    if (draftId != null) {
      await _db.messageDao.deleteMessages([draftId]);
    }
    await _deleteAttachmentFiles(message);
  }

  /// 重试单个任务（用户在队列页点「重试」）。
  Future<void> retry(String id) async {
    await _db.sendTaskDao.updateStatus(
      id,
      SendTaskStatus.queued,
      clearError: true,
    );
    unawaited(processQueue());
  }

  /// 重试全部失败任务（顶栏 / 队列页「全部重试」）。
  Future<void> retryAll() async {
    await _db.sendTaskDao.requeueAllFailed();
    unawaited(processQueue());
  }

  /// 取消并移除任务。若任务不关联草稿，连带清理其附件临时文件；关联草稿则保留
  /// （附件仍由草稿持有，用户可继续编辑）。
  Future<void> cancel(String id) async {
    final task = await _db.sendTaskDao.getTask(id);
    if (task == null) return;
    await _db.sendTaskDao.remove(id);
    if (task.draftMessageId == null) {
      try {
        await _deleteAttachmentFiles(OutgoingMessage.decode(task.payload));
      } catch (_) {}
    }
  }

  Future<void> _deleteAttachmentFiles(OutgoingMessage message) async {
    for (final att in message.attachments) {
      try {
        final file = File(att.localPath);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // 清理失败不致命。
      }
    }
  }

  String _friendlyError(Object e) {
    final (category, detail) = _classifyError(e);
    final text = detail.length > 1200
        ? '${detail.substring(0, 1200)}...'
        : detail;
    return '$category：$text';
  }

  (String, String) _classifyError(Object e) {
    if (e is MailAuthException) return ('认证失败', _backendErrorDetail(e));
    if (e is MailConnectionException) return ('网络错误', _backendErrorDetail(e));
    if (e is MailBackendException) {
      final cause = e.cause;
      if (cause is DioException) {
        final status = cause.response?.statusCode;
        final detail = _backendErrorDetail(e);
        if (status == 401 || status == 403) return ('认证失败', detail);
        if (status == 408 || status == 429) return ('网络错误', detail);
        if (status != null && status >= 500) return ('服务端错误', detail);
        if (_isDioNetworkError(cause)) return ('网络错误', detail);
      }
      if (e.message.contains('附件')) return ('附件错误', _backendErrorDetail(e));
      return ('发送失败', _backendErrorDetail(e));
    }
    final text = e.toString();
    if (text.contains('附件')) return ('附件错误', text);
    if (text.contains('SocketException') || text.contains('Timeout')) {
      return ('网络错误', text);
    }
    return ('发送失败', text);
  }

  String _backendErrorDetail(MailBackendException e) {
    final cause = e.cause;
    if (cause is DioException) {
      return '${e.message}；${_dioErrorDetail(cause)}';
    }
    if (cause == null) return e.message;
    return '${e.message}；原因：$cause';
  }

  String _dioErrorDetail(DioException e) {
    final parts = <String>[];
    final status = e.response?.statusCode;
    if (status != null) parts.add('HTTP $status');
    parts.add('类型 ${e.type.name}');

    final method = e.requestOptions.method;
    final uri = e.requestOptions.uri;
    parts.add('$method ${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}');

    final responseData = e.response?.data;
    if (responseData != null) {
      parts.add('响应 ${_stringifyErrorData(responseData)}');
    }
    final rawError = e.error;
    if (rawError != null) parts.add('底层错误 $rawError');
    if (e.message != null && e.message!.trim().isNotEmpty) {
      parts.add('Dio ${e.message}');
    }
    return parts.join('；');
  }

  String _stringifyErrorData(Object data) {
    String text;
    try {
      text = data is String ? data : jsonEncode(data);
    } catch (_) {
      text = data.toString();
    }
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 800 ? '${text.substring(0, 800)}...' : text;
  }

  bool _isDioNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  void dispose() {
    unawaited(_connSub?.cancel());
    _connSub = null;
  }
}
