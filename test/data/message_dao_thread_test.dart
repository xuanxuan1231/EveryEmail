import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:everyemail/data/local/database/app_database.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:everyemail/domain/enums/message_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// `MessageDao.watchThread` 回归：整个账户内同 threadKey 的邮件跨文件夹聚合、
/// 按日期升序、且不串其它账户。
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedAccount(String id) => db.accountDao.upsertAccount(
    AccountsCompanion.insert(
      id: id,
      email: '$id@x.com',
      displayName: id,
      accountType: AccountType.genericImap,
      authType: AuthType.password,
    ),
  );

  Future<void> seedFolder(String id, String accountId, FolderType type) =>
      db.folderDao.upsertFolder(
        FoldersCompanion.insert(
          id: id,
          accountId: accountId,
          remoteId: id,
          displayName: id,
          folderType: type,
        ),
      );

  Future<void> seedMessage({
    required String id,
    required String accountId,
    required String folderId,
    required DateTime date,
    String? threadKey,
  }) => db.messageDao.upsertMessage(
    MessagesCompanion.insert(
      id: id,
      accountId: accountId,
      folderId: folderId,
      date: date,
      threadKey: Value(threadKey),
    ),
  );

  test('跨文件夹聚合同账户同 threadKey，按日期升序', () async {
    await seedAccount('acc');
    await seedFolder('inbox', 'acc', FolderType.inbox);
    await seedFolder('sent', 'acc', FolderType.sent);

    // 同一会话 <root>：收件箱两封 + 已发送一封，乱序插入。
    await seedMessage(
      id: 'c',
      accountId: 'acc',
      folderId: 'inbox',
      date: DateTime(2026, 1, 1, 12),
      threadKey: '<root>',
    );
    await seedMessage(
      id: 'a',
      accountId: 'acc',
      folderId: 'inbox',
      date: DateTime(2026, 1, 1, 10),
      threadKey: '<root>',
    );
    await seedMessage(
      id: 'b',
      accountId: 'acc',
      folderId: 'sent',
      date: DateTime(2026, 1, 1, 11),
      threadKey: '<root>',
    );
    // 另一会话，不应混入。
    await seedMessage(
      id: 'other',
      accountId: 'acc',
      folderId: 'inbox',
      date: DateTime(2026, 1, 1, 13),
      threadKey: '<other>',
    );

    final thread = await db.messageDao.watchThread('acc', '<root>').first;

    expect(thread.map((m) => m.id), ['a', 'b', 'c']); // 升序，跨 inbox/sent
  });

  test('不串其它账户（threadKey 相同也隔离）', () async {
    await seedAccount('acc-a');
    await seedAccount('acc-b');
    await seedFolder('in-a', 'acc-a', FolderType.inbox);
    await seedFolder('in-b', 'acc-b', FolderType.inbox);

    await seedMessage(
      id: 'a1',
      accountId: 'acc-a',
      folderId: 'in-a',
      date: DateTime(2026, 1, 1),
      threadKey: '<shared>',
    );
    await seedMessage(
      id: 'b1',
      accountId: 'acc-b',
      folderId: 'in-b',
      date: DateTime(2026, 1, 1),
      threadKey: '<shared>',
    );

    final thread = await db.messageDao.watchThread('acc-a', '<shared>').first;

    expect(thread.map((m) => m.id), ['a1']);
  });
}
