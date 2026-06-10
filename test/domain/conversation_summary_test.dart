import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:everyemail/data/local/database/app_database.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:everyemail/domain/enums/message_enums.dart';
import 'package:everyemail/domain/models/conversation_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// `groupConversations` 的聚合行为回归。
///
/// 不变量：按 `(accountId, threadKey)` 归并、threadKey 为空退化为单封、会话按
/// 最新邮件排序、参与者去重且最旧→最新、self 显示为「我」、跨账户不串。
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const seenBit = 1; // 1 << MessageFlag.seen.index (seen.index == 0)

  Future<void> seedAccount(String id, String email) async {
    await db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: id,
        email: email,
        displayName: email,
        accountType: AccountType.gmailOAuth,
        authType: AuthType.oauth,
      ),
    );
  }

  Future<void> seedFolder(String id, String accountId, FolderType type) async {
    await db.folderDao.upsertFolder(
      FoldersCompanion.insert(
        id: id,
        accountId: accountId,
        remoteId: id,
        displayName: id,
        folderType: type,
      ),
    );
  }

  Future<Message> seedMessage({
    required String id,
    required String accountId,
    required String folderId,
    required DateTime date,
    String? threadKey,
    String? fromName,
    String? fromEmail,
    bool seen = true,
    bool hasAttachments = false,
  }) async {
    await db.messageDao.upsertMessage(
      MessagesCompanion.insert(
        id: id,
        accountId: accountId,
        folderId: folderId,
        date: date,
        threadKey: Value(threadKey),
        fromName: Value(fromName),
        fromEmail: Value(fromEmail),
        flagsBitmask: Value(seen ? seenBit : 0),
        hasAttachments: Value(hasAttachments),
      ),
    );
    return (await db.messageDao.getMessage(id))!;
  }

  test('同 threadKey 归并；按最新排序；计数与参与者（最旧→最新去重）', () async {
    await seedAccount('acc', 'me@x.com');
    await seedFolder('inbox', 'acc', FolderType.inbox);
    await seedFolder('sent', 'acc', FolderType.sent);

    // 会话 T1：三封跨文件夹（含一封已发送），其中最新一封未读。
    await seedMessage(
      id: 't1-a',
      accountId: 'acc',
      folderId: 'inbox',
      date: DateTime(2026, 1, 1, 9),
      threadKey: 'T1',
      fromName: 'Alice',
      fromEmail: 'alice@x.com',
    );
    await seedMessage(
      id: 't1-b',
      accountId: 'acc',
      folderId: 'sent',
      date: DateTime(2026, 1, 1, 10),
      threadKey: 'T1',
      fromName: '我',
      fromEmail: 'me@x.com',
    );
    await seedMessage(
      id: 't1-c',
      accountId: 'acc',
      folderId: 'inbox',
      date: DateTime(2026, 1, 1, 11),
      threadKey: 'T1',
      fromName: 'Bob',
      fromEmail: 'bob@x.com',
      seen: false,
      hasAttachments: true,
    );
    // 另一条更早的会话 T2，单封。
    await seedMessage(
      id: 't2-a',
      accountId: 'acc',
      folderId: 'inbox',
      date: DateTime(2026, 1, 1, 8),
      threadKey: 'T2',
      fromName: 'Carol',
      fromEmail: 'carol@x.com',
    );

    final messages = await db.messageDao.watchAccountMessages('acc').first;
    final groups = groupConversations(
      messages,
      selfEmails: {'me@x.com'},
    );

    expect(groups, hasLength(2));

    // T1 最新（11:00）排在前。
    final t1 = groups.first;
    expect(t1.latest.id, 't1-c');
    expect(t1.messageCount, 3);
    expect(t1.hasUnread, isTrue);
    expect(t1.hasAttachments, isTrue);
    // 参与者最旧→最新去重，self → 「我」。
    expect(t1.participants, ['Alice', '我', 'Bob']);

    final t2 = groups.last;
    expect(t2.latest.id, 't2-a');
    expect(t2.messageCount, 1);
    expect(t2.hasUnread, isFalse);
    expect(t2.participants, ['Carol']);
  });

  test('threadKey 为空：每封自成一条会话', () async {
    await seedAccount('acc', 'me@x.com');
    await seedFolder('inbox', 'acc', FolderType.inbox);

    await seedMessage(
      id: 'm1',
      accountId: 'acc',
      folderId: 'inbox',
      date: DateTime(2026, 1, 2),
      fromEmail: 'a@x.com',
    );
    await seedMessage(
      id: 'm2',
      accountId: 'acc',
      folderId: 'inbox',
      date: DateTime(2026, 1, 1),
      fromEmail: 'b@x.com',
    );

    final messages = await db.messageDao.watchAccountMessages('acc').first;
    final groups = groupConversations(messages, selfEmails: {});

    expect(groups, hasLength(2));
    expect(groups.map((g) => g.latest.id), ['m1', 'm2']);
    expect(groups.every((g) => g.messageCount == 1), isTrue);
  });

  test('跨账户即便 threadKey 相同也不串', () async {
    await seedAccount('acc-a', 'a@x.com');
    await seedAccount('acc-b', 'b@x.com');
    await seedFolder('inbox-a', 'acc-a', FolderType.inbox);
    await seedFolder('inbox-b', 'acc-b', FolderType.inbox);

    final m1 = await seedMessage(
      id: 'a1',
      accountId: 'acc-a',
      folderId: 'inbox-a',
      date: DateTime(2026, 1, 1, 10),
      threadKey: 'SHARED',
      fromEmail: 'x@x.com',
    );
    final m2 = await seedMessage(
      id: 'b1',
      accountId: 'acc-b',
      folderId: 'inbox-b',
      date: DateTime(2026, 1, 1, 9),
      threadKey: 'SHARED',
      fromEmail: 'y@x.com',
    );

    // 手工组装成混合列表（日期降序），模拟统一视图的数据源。
    final groups = groupConversations([m1, m2], selfEmails: {});

    expect(groups, hasLength(2));
    expect(groups.map((g) => g.messageCount), [1, 1]);
  });
}
