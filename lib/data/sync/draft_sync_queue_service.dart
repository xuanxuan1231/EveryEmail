// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/id_generator.dart' as id_gen;
import '../../domain/enums/account_enums.dart';
import '../../domain/enums/message_enums.dart';
import '../../domain/models/outgoing_message.dart';
import '../backends/mail_backend.dart';
import '../local/database/app_database.dart';
import '../settings/account_settings.dart';
import 'sync_service.dart';

/// 草稿同步队列：本地草稿先保存成功，再异步同步到服务端草稿箱。
class DraftSyncQueueService {
  DraftSyncQueueService({
    required AppDatabase db,
    required SyncService syncService,
  }) : _db = db,
       _syncService = syncService {
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (online) unawaited(processQueue());
    });
  }

  final AppDatabase _db;
  final SyncService _syncService;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _timer;
  bool _processing = false;

  Stream<List<DraftSyncTask>> watchTasks() {
    return _db.draftSyncTaskDao.watchAll();
  }

  Future<void> enqueueSave({
    required String accountId,
    required String draftMessageId,
    required OutgoingMessage message,
  }) async {
    await _db.draftSyncTaskDao.removeSaveTasksForDraft(draftMessageId);
    await _db.draftSyncTaskDao.insertTask(
      DraftSyncTasksCompanion.insert(
        id: id_gen.generateId(),
        accountId: accountId,
        opType: 'save',
        draftMessageId: Value(draftMessageId),
        payload: Value(message.encode()),
        serverDraftId: Value(message.serverDraftId),
      ),
    );
    unawaited(processQueue());
  }

  Future<void> enqueueDelete({
    required String accountId,
    String? draftMessageId,
    String? serverDraftId,
  }) async {
    if (draftMessageId != null) {
      await _db.draftSyncTaskDao.removeAllForDraft(draftMessageId);
    }
    if (serverDraftId == null || serverDraftId.isEmpty) return;
    await _db.draftSyncTaskDao.insertTask(
      DraftSyncTasksCompanion.insert(
        id: id_gen.generateId(),
        accountId: accountId,
        opType: 'delete',
        draftMessageId: Value(draftMessageId),
        serverDraftId: Value(serverDraftId),
      ),
    );
    unawaited(processQueue());
  }

  Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;
    _timer?.cancel();
    _timer = null;
    try {
      final tasks = await _db.draftSyncTaskDao.getRunnable();
      for (final task in tasks) {
        final settings = await AccountSettingsStore.read(task.accountId);
        if (!settings.draftSyncAutoRetry) continue;
        await _processOne(task, settings);
      }
    } catch (e) {
      debugPrint('DraftSyncQueueService.processQueue 失败: $e');
    } finally {
      _processing = false;
      await _scheduleNextRun();
    }
  }

  Future<void> _processOne(DraftSyncTask task, AccountSettings settings) async {
    await _db.draftSyncTaskDao.updateStatus(
      task.id,
      DraftSyncTaskStatus.syncing,
      clearError: true,
    );
    try {
      switch (task.opType) {
        case 'save':
          await _syncSave(task);
        case 'delete':
          await _syncDelete(task);
        default:
          await _db.draftSyncTaskDao.remove(task.id);
      }
    } catch (e) {
      final nextAttemptAt = DateTime.now().add(settings.draftSyncRetryInterval);
      await _db.draftSyncTaskDao.incrementAttempts(task.id);
      await _db.draftSyncTaskDao.updateStatus(
        task.id,
        DraftSyncTaskStatus.failed,
        error: _friendlyError(e),
        nextAttemptAt: nextAttemptAt,
      );
    }
  }

  Future<void> _syncSave(DraftSyncTask task) async {
    final payload = task.payload;
    final draftMessageId = task.draftMessageId;
    if (payload == null || draftMessageId == null) {
      await _db.draftSyncTaskDao.remove(task.id);
      return;
    }

    final message = OutgoingMessage.decode(payload);
    final saved = await _syncService.saveServerDraft(
      accountId: task.accountId,
      message: message,
    );
    if (saved != null) {
      await _writeSavedDraft(task.accountId, draftMessageId, saved);
    }
    await _db.draftSyncTaskDao.remove(task.id);
  }

  Future<void> _syncDelete(DraftSyncTask task) async {
    await _syncService.deleteServerDraft(
      accountId: task.accountId,
      serverDraftId: task.serverDraftId,
    );
    await _db.draftSyncTaskDao.remove(task.id);
  }

  Future<void> _writeSavedDraft(
    String accountId,
    String draftMessageId,
    SavedDraft saved,
  ) async {
    final account = await _syncService.accountConfigFor(accountId);
    final imapDraft = account.type == AccountType.genericImap
        ? _parseImapDraftId(saved.draftId)
        : null;
    await (_db.update(
      _db.messages,
    )..where((t) => t.id.equals(draftMessageId))).write(
      MessagesCompanion(
        graphMessageId: Value(
          account.type == AccountType.microsoftGraph ? saved.messageId : null,
        ),
        gmailMessageId: Value(
          account.type == AccountType.gmailOAuth ? saved.messageId : null,
        ),
        imapUid: Value(imapDraft?.uid),
        imapUidValidity: Value(imapDraft?.uidValidity),
        serverDraftId: Value(saved.draftId),
        threadKey: Value(saved.threadId),
      ),
    );
  }

  Future<void> _scheduleNextRun() async {
    _timer?.cancel();
    final tasks = await _db.draftSyncTaskDao.watchAll().first;
    DateTime? next;
    final now = DateTime.now();
    for (final task in tasks) {
      final settings = await AccountSettingsStore.read(task.accountId);
      if (!settings.draftSyncAutoRetry) continue;
      final at = task.nextAttemptAt ?? now;
      if (next == null || at.isBefore(next)) next = at;
    }
    if (next == null) return;
    final delay = next.isBefore(now) ? Duration.zero : next.difference(now);
    _timer = Timer(delay, () => unawaited(processQueue()));
  }

  ({int uidValidity, int uid})? _parseImapDraftId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final uidValidity = int.tryParse(parts[0]);
    final uid = int.tryParse(parts[1]);
    if (uidValidity == null || uid == null) return null;
    return (uidValidity: uidValidity, uid: uid);
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    return text.length > 300 ? '${text.substring(0, 300)}...' : text;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    unawaited(_connSub?.cancel());
    _connSub = null;
  }
}
