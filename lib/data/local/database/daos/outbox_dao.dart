import 'package:drift/drift.dart';

import '../../../../domain/enums/message_enums.dart';
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

  /// 取某账户的待处理操作，按 createdAt 升序（最旧优先）。
  Future<List<OutboxOp>> getPendingForAccount(String accountId) {
    return (select(outboxOps)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<int> enqueue(OutboxOpsCompanion op) {
    return into(outboxOps).insert(op);
  }

  /// 删除该账户中针对同一 [messageId] 且属于 [flag] 语义的所有待推送条目。
  /// 用于"先 markRead 后立刻 markUnread"这类用户撤销场景：保留最新意图即可。
  Future<void> removeForMessage(
    String accountId,
    String messageId,
    MessageFlag flag,
  ) async {
    final opTypes = switch (flag) {
      MessageFlag.seen => const ['markRead', 'markUnread'],
      MessageFlag.flagged => const ['flag', 'unflag'],
      _ => const <String>[],
    };
    if (opTypes.isEmpty) return;
    // payload 是 JSON 字符串，含 "messageId":"<id>"。简单 LIKE 匹配足够，
    // 因为 messageId 是 ULID/GUID，不会与其它字段碰撞。
    await (delete(outboxOps)
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.opType.isIn(opTypes) &
              t.payload.like('%"messageId":"$messageId"%')))
        .go();
  }

  Future<void> markFailed(int id, String error) {
    // 同时累计 attempts，让上层能根据次数决定是否丢弃。
    return customUpdate(
      'UPDATE outbox_ops SET attempts = attempts + 1, last_error = ? '
      'WHERE id = ?',
      variables: [Variable.withString(error), Variable.withInt(id)],
      updates: {outboxOps},
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
