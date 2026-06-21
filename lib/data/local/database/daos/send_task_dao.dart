import 'package:drift/drift.dart';

import '../../../../domain/enums/message_enums.dart';
import '../app_database.dart';
import '../tables.dart';

part 'send_task_dao.g.dart';

/// 发送队列读写（见 [SendTasks]）。
@DriftAccessor(tables: [SendTasks])
class SendTaskDao extends DatabaseAccessor<AppDatabase>
    with _$SendTaskDaoMixin {
  SendTaskDao(super.db);

  Future<void> insertTask(SendTasksCompanion task) =>
      into(sendTasks).insert(task);

  Future<SendTask?> getTask(String id) =>
      (select(sendTasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 监听全部未完成任务（queued/sending/failed），最旧优先。完成的任务直接删除，
  /// 故此流即「队列里还剩什么」。UI 据此渲染顶栏角标与队列页。
  Stream<List<SendTask>> watchAll() {
    return (select(
      sendTasks,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();
  }

  Future<List<SendTask>> getAll() {
    return (select(
      sendTasks,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
  }

  /// 可立即发送的任务：queued，以及上次运行中残留的 sending（进程被杀导致的孤儿，
  /// 队列单线程处理，故 sending 必为孤儿）。最旧优先。
  Future<List<SendTask>> getSendable() {
    return (select(sendTasks)
          ..where(
            (t) =>
                t.status.equals(SendTaskStatus.queued.index) |
                t.status.equals(SendTaskStatus.sending.index),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> updateStatus(
    String id,
    SendTaskStatus status, {
    String? error,
    bool clearError = false,
  }) {
    return (update(sendTasks)..where((t) => t.id.equals(id))).write(
      SendTasksCompanion(
        status: Value(status),
        lastError: clearError ? const Value(null) : Value.absentIfNull(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 把全部 failed 任务重置为 queued（用户点「全部重试」）。
  Future<void> requeueAllFailed() {
    return (update(sendTasks)
          ..where((t) => t.status.equals(SendTaskStatus.failed.index)))
        .write(
          SendTasksCompanion(
            status: Value(SendTaskStatus.queued),
            lastError: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> incrementAttempts(String id) {
    return customUpdate(
      'UPDATE send_tasks SET attempts = attempts + 1 WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {sendTasks},
    );
  }

  Future<void> remove(String id) =>
      (delete(sendTasks)..where((t) => t.id.equals(id))).go();
}
