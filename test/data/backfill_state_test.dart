import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:everyemail/data/local/database/app_database.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:everyemail/domain/enums/message_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// 历史回填游标状态机的回归测试（`MessageDao.updateBackfillState`）。
///
/// 关键不变量：回填游标的推进/置底**绝不能清空增量同步游标 `deltaLink`**，
/// 否则下一次同步会被当作全新文件夹全量重建，正是要修的“缺邮件”类问题。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedFolder() async {
    await db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'acc-1',
        email: 'me@gmail.com',
        displayName: '我',
        accountType: AccountType.gmailOAuth,
        authType: AuthType.oauth,
      ),
    );
    await db.folderDao.upsertFolder(
      FoldersCompanion.insert(
        id: 'folder-1',
        accountId: 'acc-1',
        remoteId: 'INBOX',
        displayName: '收件箱',
        folderType: FolderType.inbox,
      ),
    );
  }

  test('无 syncState 行时：补插一行并写入回填游标', () async {
    await seedFolder();

    await db.messageDao.updateBackfillState('folder-1', cursor: 'token-1');

    final state = await db.messageDao.getSyncState('folder-1');
    expect(state, isNotNull);
    expect(state!.backfillCursor, 'token-1');
    expect(state.backfillDone, isFalse);
    // 增量游标本就没有，应保持 null（不被误置）。
    expect(state.deltaLink, isNull);
  });

  test('已有 deltaLink：推进回填游标不清空增量游标', () async {
    await seedFolder();
    await db.messageDao.upsertSyncState(
      SyncStatesCompanion.insert(
        folderId: 'folder-1',
        deltaLink: const Value('history-999'),
      ),
    );

    await db.messageDao.updateBackfillState('folder-1', cursor: 'token-2');

    final state = await db.messageDao.getSyncState('folder-1');
    expect(state!.deltaLink, 'history-999'); // 关键：未被清空
    expect(state.backfillCursor, 'token-2');
    expect(state.backfillDone, isFalse);
  });

  test('置底：done=true，且不动 deltaLink', () async {
    await seedFolder();
    await db.messageDao.upsertSyncState(
      SyncStatesCompanion.insert(
        folderId: 'folder-1',
        deltaLink: const Value('history-999'),
      ),
    );
    await db.messageDao.updateBackfillState('folder-1', cursor: 'token-3');

    await db.messageDao.updateBackfillState('folder-1', done: true);

    final state = await db.messageDao.getSyncState('folder-1');
    expect(state!.backfillDone, isTrue);
    expect(state.deltaLink, 'history-999'); // 关键：未被清空
  });
}
