import 'package:drift/drift.dart';

import '../../../../domain/enums/message_enums.dart';
import '../app_database.dart';
import '../tables.dart';

part 'draft_sync_task_dao.g.dart';

/// 草稿同步队列读写（见 [DraftSyncTasks]）。
@DriftAccessor(tables: [DraftSyncTasks])
class DraftSyncTaskDao extends DatabaseAccessor<AppDatabase>
    with _$DraftSyncTaskDaoMixin {
  DraftSyncTaskDao(super.db);

  Future<void> insertTask(DraftSyncTasksCompanion task) {
    return into(draftSyncTasks).insert(task);
  }

  Future<List<DraftSyncTask>> getRunnable({DateTime? now}) {
    final at = now ?? DateTime.now();
    return (select(draftSyncTasks)
          ..where(
            (t) =>
                (t.status.equals(DraftSyncTaskStatus.queued.index) |
                    t.status.equals(DraftSyncTaskStatus.syncing.index) |
                    t.status.equals(DraftSyncTaskStatus.failed.index)) &
                (t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(at)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Stream<List<DraftSyncTask>> watchAll() {
    return (select(
      draftSyncTasks,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();
  }

  Future<void> updateStatus(
    String id,
    DraftSyncTaskStatus status, {
    String? error,
    DateTime? nextAttemptAt,
    bool clearError = false,
  }) {
    return (update(draftSyncTasks)..where((t) => t.id.equals(id))).write(
      DraftSyncTasksCompanion(
        status: Value(status),
        lastError: clearError ? const Value(null) : Value.absentIfNull(error),
        nextAttemptAt: Value(nextAttemptAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> incrementAttempts(String id) {
    return customUpdate(
      'UPDATE draft_sync_tasks SET attempts = attempts + 1 WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {draftSyncTasks},
    );
  }

  Future<void> remove(String id) {
    return (delete(draftSyncTasks)..where((t) => t.id.equals(id))).go();
  }

  Future<void> removeSaveTasksForDraft(String draftMessageId) {
    return (delete(draftSyncTasks)..where(
          (t) =>
              t.draftMessageId.equals(draftMessageId) & t.opType.equals('save'),
        ))
        .go();
  }

  Future<void> removeAllForDraft(String draftMessageId) {
    return (delete(
      draftSyncTasks,
    )..where((t) => t.draftMessageId.equals(draftMessageId))).go();
  }
}
