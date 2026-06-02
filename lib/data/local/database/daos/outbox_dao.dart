import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'outbox_dao.g.dart';

/// 发件箱 / 待推送变更队列读写。
@DriftAccessor(tables: [OutboxOps])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// 监听某账户的待处理操作（最旧优先）。
  Stream<List<OutboxOp>> watchPending(String accountId) {
    return (select(outboxOps)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<OutboxOp>> getPending() {
    return (select(outboxOps)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<int> enqueue(OutboxOpsCompanion op) {
    return into(outboxOps).insert(op);
  }

  Future<void> markFailed(int id, String error) {
    return (update(outboxOps)..where((t) => t.id.equals(id))).write(
      OutboxOpsCompanion(
        attempts: const Value.absent(),
        lastError: Value(error),
      ),
    );
  }

  Future<void> incrementAttempts(int id) {
    return customUpdate(
      'UPDATE outbox_ops SET attempts = attempts + 1 WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {outboxOps},
    );
  }

  Future<void> remove(int id) {
    return (delete(outboxOps)..where((t) => t.id.equals(id))).go();
  }
}
