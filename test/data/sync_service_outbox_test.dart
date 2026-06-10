import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:everyemail/data/auth/oauth_service.dart';
import 'package:everyemail/data/local/database/app_database.dart';
import 'package:everyemail/data/secure/token_store.dart';
import 'package:everyemail/data/sync/sync_service.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:everyemail/domain/enums/message_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// 回归测试：标记已读/未读必须为各后端正确入队 outbox。
///
/// 历史 bug：`setMessageFlag` 的远端引用判断只认 graphMessageId / imapUid，
/// 漏了 Gmail 的 gmailMessageId，导致 Gmail 邮件标记已读时只改本地、从不入队，
/// 已读状态永远不会回推 Gmail 服务端。
void main() {
  late AppDatabase db;
  late SyncService sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // setMessageFlag 只读写本地 DB、不触网，tokenStore/oauthService 仅为满足构造。
    sync = SyncService(
      db: db,
      tokenStore: TokenStore(),
      oauthService: OAuthService(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// 写入一个账户 + 一个文件夹，返回 folderId。
  Future<String> seedAccountAndFolder() async {
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
    return 'folder-1';
  }

  test('Gmail 邮件标记已读：入队 markRead 且携带 gmail ref', () async {
    final folderId = await seedAccountAndFolder();
    await db.messageDao.upsertMessage(
      MessagesCompanion.insert(
        id: 'msg-1',
        accountId: 'acc-1',
        folderId: folderId,
        date: DateTime(2026, 1, 1),
        // Gmail 专属：只有 gmailMessageId，imapUid / graphMessageId 均为空。
        gmailMessageId: const Value('gmail-abc'),
      ),
    );

    await sync.setMessageFlag('msg-1', flag: MessageFlag.seen, value: true);

    // 1) 本地标志位已置位。
    final msg = await db.messageDao.getMessage('msg-1');
    final seenBit = 1 << MessageFlag.seen.index;
    expect(msg!.flagsBitmask & seenBit, seenBit);

    // 2) outbox 入队了一条 markRead，且 ref 指向正确的 Gmail message id。
    final pending = await db.outboxDao.getPendingForAccount('acc-1');
    expect(pending, hasLength(1));
    expect(pending.single.opType, 'markRead');

    final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
    expect(payload['messageId'], 'msg-1');
    final ref = payload['ref'] as Map<String, dynamic>;
    expect(ref['type'], 'gmail');
    expect(ref['messageId'], 'gmail-abc');
    expect(ref['labelId'], 'INBOX');
  });

  test('Gmail 邮件标记未读：入队 markUnread', () async {
    final folderId = await seedAccountAndFolder();
    final seenBit = 1 << MessageFlag.seen.index;
    await db.messageDao.upsertMessage(
      MessagesCompanion.insert(
        id: 'msg-2',
        accountId: 'acc-1',
        folderId: folderId,
        date: DateTime(2026, 1, 1),
        gmailMessageId: const Value('gmail-xyz'),
        flagsBitmask: Value(seenBit), // 初始已读
      ),
    );

    await sync.setMessageFlag('msg-2', flag: MessageFlag.seen, value: false);

    final msg = await db.messageDao.getMessage('msg-2');
    expect(msg!.flagsBitmask & seenBit, 0);

    final pending = await db.outboxDao.getPendingForAccount('acc-1');
    expect(pending, hasLength(1));
    expect(pending.single.opType, 'markUnread');
  });

  test('无远端引用（本地草稿）：仅更新本地、不入队', () async {
    final folderId = await seedAccountAndFolder();
    await db.messageDao.upsertMessage(
      MessagesCompanion.insert(
        id: 'msg-local',
        accountId: 'acc-1',
        folderId: folderId,
        date: DateTime(2026, 1, 1),
        // gmail/graph/imap 标识全为空 —— 没有远端引用。
      ),
    );

    await sync.setMessageFlag('msg-local', flag: MessageFlag.seen, value: true);

    final msg = await db.messageDao.getMessage('msg-local');
    final seenBit = 1 << MessageFlag.seen.index;
    expect(msg!.flagsBitmask & seenBit, seenBit);

    final pending = await db.outboxDao.getPendingForAccount('acc-1');
    expect(pending, isEmpty);
  });

  test('先已读后立刻未读：去重，仅保留最新意图', () async {
    final folderId = await seedAccountAndFolder();
    await db.messageDao.upsertMessage(
      MessagesCompanion.insert(
        id: 'msg-3',
        accountId: 'acc-1',
        folderId: folderId,
        date: DateTime(2026, 1, 1),
        gmailMessageId: const Value('gmail-321'),
      ),
    );

    await sync.setMessageFlag('msg-3', flag: MessageFlag.seen, value: true);
    await sync.setMessageFlag('msg-3', flag: MessageFlag.seen, value: false);

    final pending = await db.outboxDao.getPendingForAccount('acc-1');
    expect(pending, hasLength(1));
    expect(pending.single.opType, 'markUnread');
  });

  test('标记已读即时把文件夹未读角标 -1，标未读 +1，不低于 0', () async {
    final folderId = await seedAccountAndFolder();
    // 文件夹初始未读为服务端基线 2。
    await db.folderDao.updateCounts(folderId, unread: 2);
    await db.messageDao.upsertMessage(
      MessagesCompanion.insert(
        id: 'msg-u',
        accountId: 'acc-1',
        folderId: folderId,
        date: DateTime(2026, 1, 1),
        gmailMessageId: const Value('gmail-u'),
        // 初始未读（seen 位未置）。
      ),
    );

    await sync.setMessageFlag('msg-u', flag: MessageFlag.seen, value: true);
    expect((await db.folderDao.getFolder(folderId))!.unreadCount, 1);

    await sync.setMessageFlag('msg-u', flag: MessageFlag.seen, value: false);
    expect((await db.folderDao.getFolder(folderId))!.unreadCount, 2);

    // 再标未读已是未读→无变化（bitmask 未变，早返回，不再 +1）。
    await sync.setMessageFlag('msg-u', flag: MessageFlag.seen, value: false);
    expect((await db.folderDao.getFolder(folderId))!.unreadCount, 2);
  });

  test('标星不影响未读角标', () async {
    final folderId = await seedAccountAndFolder();
    await db.folderDao.updateCounts(folderId, unread: 3);
    await db.messageDao.upsertMessage(
      MessagesCompanion.insert(
        id: 'msg-star',
        accountId: 'acc-1',
        folderId: folderId,
        date: DateTime(2026, 1, 1),
        gmailMessageId: const Value('gmail-star'),
      ),
    );

    await sync.setMessageFlag('msg-star', flag: MessageFlag.flagged, value: true);

    expect((await db.folderDao.getFolder(folderId))!.unreadCount, 3);
  });

  test('删除未读邮件：文件夹未读角标 -1', () async {
    final folderId = await seedAccountAndFolder();
    await db.folderDao.updateCounts(folderId, unread: 2);
    await db.messageDao.upsertMessage(
      MessagesCompanion.insert(
        id: 'msg-del',
        accountId: 'acc-1',
        folderId: folderId,
        date: DateTime(2026, 1, 1),
        gmailMessageId: const Value('gmail-del'),
      ),
    );

    await sync.deleteMessage('msg-del');

    expect((await db.folderDao.getFolder(folderId))!.unreadCount, 1);
  });
}
