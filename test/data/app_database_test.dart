import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:everyemail/data/local/database/app_database.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:everyemail/domain/enums/message_enums.dart';
import 'package:everyemail/domain/models/unified_mailbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('账户增删查 + 响应式监听', () async {
    final emitted = <int>[];
    final sub = db.accountDao.watchAccounts().listen((rows) {
      emitted.add(rows.length);
    });

    await db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'acc-1',
        email: 'me@example.com',
        displayName: '我',
        accountType: AccountType.genericImap,
        authType: AuthType.password,
      ),
    );

    final accounts = await db.accountDao.getAccounts();
    expect(accounts, hasLength(1));
    expect(accounts.single.email, 'me@example.com');

    await db.accountDao.deleteAccount('acc-1');
    expect(await db.accountDao.getAccounts(), isEmpty);

    await pumpEventQueue();
    // 初始空 -> 1 -> 删除回 0
    expect(emitted.last, 0);
    await sub.cancel();
  });

  test('文件夹级联删除：删账户应清空其文件夹', () async {
    await db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'acc-1',
        email: 'me@example.com',
        displayName: '我',
        accountType: AccountType.genericImap,
        authType: AuthType.password,
      ),
    );
    await db.folderDao.upsertFolder(
      FoldersCompanion.insert(
        id: 'f-inbox',
        accountId: 'acc-1',
        remoteId: 'INBOX',
        displayName: '收件箱',
        folderType: FolderType.inbox,
      ),
    );

    expect(await db.folderDao.getFolders('acc-1'), hasLength(1));

    await db.accountDao.deleteAccount('acc-1');
    expect(await db.folderDao.getFolders('acc-1'), isEmpty);
  });

  test('邮件 upsert / 标志位更新 / 按文件夹监听排序', () async {
    await db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'acc-1',
        email: 'me@example.com',
        displayName: '我',
        accountType: AccountType.genericImap,
        authType: AuthType.password,
      ),
    );
    await db.folderDao.upsertFolder(
      FoldersCompanion.insert(
        id: 'f-inbox',
        accountId: 'acc-1',
        remoteId: 'INBOX',
        displayName: '收件箱',
        folderType: FolderType.inbox,
      ),
    );

    await db.messageDao.upsertMessages([
      MessagesCompanion.insert(
        id: 'm-1',
        accountId: 'acc-1',
        folderId: 'f-inbox',
        date: DateTime(2026, 5, 1),
      ),
      MessagesCompanion.insert(
        id: 'm-2',
        accountId: 'acc-1',
        folderId: 'f-inbox',
        date: DateTime(2026, 5, 20),
      ),
    ]);

    final list = await db.messageDao.watchFolderMessages('f-inbox').first;
    expect(list.map((m) => m.id), ['m-2', 'm-1']); // 日期倒序

    const seenBit = 1 << 0;
    await db.messageDao.updateFlags('m-1', seenBit);
    final m1 = await db.messageDao.getMessage('m-1');
    expect(m1!.flagsBitmask & seenBit, seenBit);
  });

  test('统一文件夹按特殊文件夹类型聚合真实账户邮件', () async {
    await db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'acc-1',
        email: 'me@example.com',
        displayName: '我',
        accountType: AccountType.genericImap,
        authType: AuthType.password,
      ),
    );
    await db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'acc-2',
        email: 'work@example.com',
        displayName: '工作',
        accountType: AccountType.genericImap,
        authType: AuthType.password,
      ),
    );

    await db.folderDao.upsertFolders([
      FoldersCompanion.insert(
        id: 'f-1-inbox',
        accountId: 'acc-1',
        remoteId: 'INBOX',
        displayName: '收件箱',
        folderType: FolderType.inbox,
        unreadCount: const Value(2),
        totalCount: const Value(2),
      ),
      FoldersCompanion.insert(
        id: 'f-1-sent',
        accountId: 'acc-1',
        remoteId: 'Sent',
        displayName: '已发送',
        folderType: FolderType.sent,
        totalCount: const Value(1),
      ),
      FoldersCompanion.insert(
        id: 'f-2-inbox',
        accountId: 'acc-2',
        remoteId: 'INBOX',
        displayName: '收件箱',
        folderType: FolderType.inbox,
        unreadCount: const Value(1),
        totalCount: const Value(1),
      ),
      FoldersCompanion.insert(
        id: 'f-2-custom',
        accountId: 'acc-2',
        remoteId: 'Work',
        displayName: 'Work',
        folderType: FolderType.custom,
        unreadCount: const Value(9),
        totalCount: const Value(9),
      ),
    ]);

    await db.messageDao.upsertMessages([
      MessagesCompanion.insert(
        id: 'm-inbox-old',
        accountId: 'acc-1',
        folderId: 'f-1-inbox',
        date: DateTime(2026, 5, 1),
      ),
      MessagesCompanion.insert(
        id: 'm-inbox-new',
        accountId: 'acc-2',
        folderId: 'f-2-inbox',
        date: DateTime(2026, 5, 20),
      ),
      MessagesCompanion.insert(
        id: 'm-sent',
        accountId: 'acc-1',
        folderId: 'f-1-sent',
        date: DateTime(2026, 5, 10),
      ),
      MessagesCompanion.insert(
        id: 'm-custom',
        accountId: 'acc-2',
        folderId: 'f-2-custom',
        date: DateTime(2026, 5, 30),
      ),
    ]);

    final inbox = await db.messageDao
        .watchUnifiedFolderMessages(FolderType.inbox)
        .first;
    expect(inbox.map((item) => item.message.id), [
      'm-inbox-new',
      'm-inbox-old',
    ]);
    expect(inbox.map((item) => item.accountEmail), [
      'work@example.com',
      'me@example.com',
    ]);

    final sent = await db.messageDao
        .watchUnifiedFolderMessages(FolderType.sent)
        .first;
    expect(sent.map((item) => item.message.id), ['m-sent']);

    final summaries = await db.folderDao.watchUnifiedFolders().first;
    expect(summaries.map((folder) => folder.id), [
      for (final folder in UnifiedMailbox.folders) folder.id,
    ]);
    expect(summaries.any((folder) => folder.type == FolderType.custom), false);

    final inboxSummary = summaries.singleWhere(
      (folder) => folder.type == FolderType.inbox,
    );
    expect(inboxSummary.unreadCount, 3);
    expect(inboxSummary.totalCount, 3);
    expect(inboxSummary.sourceAccountCount, 2);

    final draftsSummary = summaries.singleWhere(
      (folder) => folder.type == FolderType.drafts,
    );
    expect(draftsSummary.sourceAccountCount, 0);
  });

  test('同步游标读写', () async {
    await db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'acc-1',
        email: 'me@example.com',
        displayName: '我',
        accountType: AccountType.genericImap,
        authType: AuthType.password,
      ),
    );
    await db.folderDao.upsertFolder(
      FoldersCompanion.insert(
        id: 'f-inbox',
        accountId: 'acc-1',
        remoteId: 'INBOX',
        displayName: '收件箱',
        folderType: FolderType.inbox,
      ),
    );

    await db.messageDao.upsertSyncState(
      SyncStatesCompanion.insert(
        folderId: 'f-inbox',
        uidValidity: const Value(42),
        uidNext: const Value(100),
      ),
    );

    final state = await db.messageDao.getSyncState('f-inbox');
    expect(state!.uidValidity, 42);
    expect(state.uidNext, 100);
  });
}
