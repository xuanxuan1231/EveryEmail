import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:everyemail/data/local/database/app_database.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:everyemail/domain/enums/message_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// 发送队列 DAO 行为回归。
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

  Future<void> insert(String id, {SendTaskStatus? status}) {
    return db.sendTaskDao.insertTask(
      SendTasksCompanion.insert(
        id: id,
        accountId: 'acc-1',
        payload: '{"id":"$id"}',
        status: status == null ? const Value.absent() : Value(status),
      ),
    );
  }

  test('insertTask 默认状态为 queued，getTask 可取回', () async {
    await insert('t1');
    final task = await db.sendTaskDao.getTask('t1');
    expect(task, isNotNull);
    expect(task!.status, SendTaskStatus.queued);
    expect(task.attempts, 0);
  });

  test('getSendable 含 queued 与残留 sending，排除 failed', () async {
    await insert('q', status: SendTaskStatus.queued);
    await insert('s', status: SendTaskStatus.sending);
    await insert('f', status: SendTaskStatus.failed);

    final sendable = await db.sendTaskDao.getSendable();
    expect(sendable.map((t) => t.id).toSet(), {'q', 's'});
  });

  test('updateStatus 写入状态与错误，clearError 清空', () async {
    await insert('t1');
    await db.sendTaskDao.updateStatus(
      't1',
      SendTaskStatus.failed,
      error: '网络错误',
    );
    var task = await db.sendTaskDao.getTask('t1');
    expect(task!.status, SendTaskStatus.failed);
    expect(task.lastError, '网络错误');

    await db.sendTaskDao.updateStatus(
      't1',
      SendTaskStatus.queued,
      clearError: true,
    );
    task = await db.sendTaskDao.getTask('t1');
    expect(task!.status, SendTaskStatus.queued);
    expect(task.lastError, isNull);
  });

  test('requeueAllFailed 把所有 failed 重置为 queued', () async {
    await insert('f1', status: SendTaskStatus.failed);
    await insert('f2', status: SendTaskStatus.failed);
    await insert('q1', status: SendTaskStatus.queued);

    await db.sendTaskDao.requeueAllFailed();

    final all = await db.sendTaskDao.getAll();
    expect(all.every((t) => t.status == SendTaskStatus.queued), isTrue);
  });

  test('incrementAttempts 累加，remove 删除', () async {
    await insert('t1');
    await db.sendTaskDao.incrementAttempts('t1');
    await db.sendTaskDao.incrementAttempts('t1');
    expect((await db.sendTaskDao.getTask('t1'))!.attempts, 2);

    await db.sendTaskDao.remove('t1');
    expect(await db.sendTaskDao.getTask('t1'), isNull);
  });

  test('watchAll 反映插入与删除', () async {
    expect((await db.sendTaskDao.watchAll().first), isEmpty);
    await insert('t1');
    await insert('t2');
    expect((await db.sendTaskDao.watchAll().first).length, 2);
  });
}
