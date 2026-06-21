import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:everyemail/data/local/database/app_database.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:everyemail/domain/enums/message_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// 草稿同步队列 DAO 行为回归。
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'acc-1',
        email: 'me@example.com',
        displayName: '我',
        accountType: AccountType.genericImap,
        authType: AuthType.password,
      ),
    );
  });

  tearDown(() async => db.close());

  Future<void> insert(
    String id, {
    DraftSyncTaskStatus? status,
    DateTime? nextAttemptAt,
    String draftMessageId = 'draft-1',
    String opType = 'save',
  }) {
    return db.draftSyncTaskDao.insertTask(
      DraftSyncTasksCompanion.insert(
        id: id,
        accountId: 'acc-1',
        opType: opType,
        draftMessageId: Value(draftMessageId),
        payload: const Value('{}'),
        status: status == null ? const Value.absent() : Value(status),
        nextAttemptAt: Value(nextAttemptAt),
      ),
    );
  }

  test('getRunnable 只返回到期任务', () async {
    final now = DateTime(2026, 1, 1, 12);
    await insert('ready');
    await insert('failed-ready', status: DraftSyncTaskStatus.failed);
    await insert(
      'future',
      status: DraftSyncTaskStatus.failed,
      nextAttemptAt: now.add(const Duration(minutes: 5)),
    );

    final runnable = await db.draftSyncTaskDao.getRunnable(now: now);
    expect(runnable.map((t) => t.id).toSet(), {'ready', 'failed-ready'});
  });

  test('updateStatus 写入错误与下一次重试时间', () async {
    await insert('t1');
    final next = DateTime(2026, 1, 1, 12, 5);

    await db.draftSyncTaskDao.updateStatus(
      't1',
      DraftSyncTaskStatus.failed,
      error: 'offline',
      nextAttemptAt: next,
    );

    final task = (await db.draftSyncTaskDao.watchAll().first).single;
    expect(task.status, DraftSyncTaskStatus.failed);
    expect(task.lastError, 'offline');
    expect(task.nextAttemptAt, next);
  });

  test('removeSaveTasksForDraft 只删除同草稿的保存任务', () async {
    await insert('save-1', draftMessageId: 'draft-1');
    await insert('delete-1', draftMessageId: 'draft-1', opType: 'delete');
    await insert('save-2', draftMessageId: 'draft-2');

    await db.draftSyncTaskDao.removeSaveTasksForDraft('draft-1');

    final remaining = await db.draftSyncTaskDao.watchAll().first;
    expect(remaining.map((t) => t.id).toSet(), {'delete-1', 'save-2'});
  });
}
