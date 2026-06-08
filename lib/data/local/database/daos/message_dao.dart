import 'package:drift/drift.dart';

import '../../../../domain/enums/message_enums.dart';
import '../app_database.dart';
import '../message_with_account.dart';
import '../tables.dart';

part 'message_dao.g.dart';

/// 邮件信封与正文读写。UI 主要消费 `watchFolderMessages`。
@DriftAccessor(tables: [Messages, MessageBodies, SyncStates, Folders, Accounts])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(super.db);

  /// 监听某文件夹的邮件列表（按日期倒序）。
  Stream<List<Message>> watchFolderMessages(
    String folderId, {
    int limit = 100,
  }) {
    return (select(messages)
          ..where((t) => t.folderId.equals(folderId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit))
        .watch();
  }

  /// 监听统一收件箱：聚合所有账户的 inbox 类型文件夹的邮件。
  Stream<List<MessageWithAccount>> watchUnifiedInbox({int limit = 100}) {
    return watchUnifiedFolderMessages(FolderType.inbox, limit: limit);
  }

  /// 监听统一账户下某个统一文件夹的邮件。
  ///
  /// 统一文件夹不复制邮件；这里按文件夹语义角色聚合所有真实账户中开启了
  /// 「统一化」的来源文件夹。
  Stream<List<MessageWithAccount>> watchUnifiedFolderMessages(
    FolderType folderType, {
    int limit = 100,
  }) {
    // 联表查询：Messages JOIN Folders JOIN Accounts
    final query =
        select(messages).join([
            innerJoin(folders, folders.id.equalsExp(messages.folderId)),
            innerJoin(accounts, accounts.id.equalsExp(messages.accountId)),
          ])
          ..where(
            folders.folderType.equals(folderType.index) &
                folders.unified.equals(true),
          )
          ..orderBy([OrderingTerm.desc(messages.date)])
          ..limit(limit);

    return query.watch().map((rows) {
      return rows.map((row) {
        return MessageWithAccount(
          message: row.readTable(messages),
          accountId: row.readTable(accounts).id,
          accountEmail: row.readTable(accounts).email,
          accountDisplayName: row.readTable(accounts).displayName,
          folderType: row.readTable(folders).folderType,
          accountColorValue: row.readTable(accounts).colorValue,
        );
      }).toList();
    });
  }

  /// 获取单条邮件。
  Future<Message?> getMessage(String id) {
    return (select(messages)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 监听单条邮件（用于实时更新）。
  Stream<Message?> watchMessage(String id) {
    return (select(
      messages,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// 监听某账户所有文件夹的邮件（用于账户级视图）。
  Stream<List<Message>> watchAccountMessages(
    String accountId, {
    int limit = 100,
  }) {
    return (select(messages)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit))
        .watch();
  }

  /// 按 IMAP UID 查找（同步对账）。
  Future<Message?> getByImapUid(String folderId, int uid) {
    return (select(messages)
          ..where((t) => t.folderId.equals(folderId) & t.imapUid.equals(uid)))
        .getSingleOrNull();
  }

  /// 按 Graph message id 查找（同步对账）。
  Future<Message?> getByGraphId(String accountId, String graphId) {
    return (select(messages)..where(
          (t) =>
              t.accountId.equals(accountId) & t.graphMessageId.equals(graphId),
        ))
        .getSingleOrNull();
  }

  /// 按 Gmail message id 查找（同步对账）。
  Future<Message?> getByGmailId(String accountId, String gmailId) {
    return (select(messages)..where(
          (t) =>
              t.accountId.equals(accountId) & t.gmailMessageId.equals(gmailId),
        ))
        .getSingleOrNull();
  }

  /// 文件夹内最大 UID（增量起点）。
  Future<int?> maxImapUid(String folderId) async {
    final expr = messages.imapUid.max();
    final query = selectOnly(messages)
      ..addColumns([expr])
      ..where(messages.folderId.equals(folderId));
    final row = await query.getSingleOrNull();
    return row?.read(expr);
  }

  Future<void> upsertMessage(MessagesCompanion message) {
    return into(messages).insertOnConflictUpdate(message);
  }

  Future<void> upsertMessages(List<MessagesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(messages, rows);
    });
  }

  Future<void> updateFlags(String id, int flagsBitmask) {
    return (update(messages)..where((t) => t.id.equals(id))).write(
      MessagesCompanion(flagsBitmask: Value(flagsBitmask)),
    );
  }

  Future<void> moveMessage(String id, String folderId) {
    return (update(messages)..where((t) => t.id.equals(id))).write(
      MessagesCompanion(folderId: Value(folderId)),
    );
  }

  Future<void> deleteMessages(List<String> ids) {
    return (delete(messages)..where((t) => t.id.isIn(ids))).go();
  }

  /// 删除某文件夹内不在给定 UID 集合中的邮件（处理 expunge）。
  Future<void> deleteImapUidsNotIn(String folderId, List<int> keepUids) {
    return (delete(messages)..where(
          (t) => t.folderId.equals(folderId) & t.imapUid.isNotIn(keepUids),
        ))
        .go();
  }

  // —— 正文 ——
  Stream<MessageBody?> watchBody(String messageId) {
    return (select(
      messageBodies,
    )..where((t) => t.messageId.equals(messageId))).watchSingleOrNull();
  }

  Future<MessageBody?> getBody(String messageId) {
    return (select(
      messageBodies,
    )..where((t) => t.messageId.equals(messageId))).getSingleOrNull();
  }

  Future<void> upsertBody(MessageBodiesCompanion body) {
    return into(messageBodies).insertOnConflictUpdate(body);
  }

  /// 仅更新正文行的附件元数据 JSON（附件下载完成后回写 localPath），不触碰其它列。
  Future<void> updateAttachmentsMeta(String messageId, String meta) {
    return (update(messageBodies)..where((t) => t.messageId.equals(messageId)))
        .write(MessageBodiesCompanion(attachmentsMeta: Value(meta)));
  }

  /// 某文件夹中"尚无正文（或仅信封、未下载）"的邮件 id，按日期倒序。
  ///
  /// 供后台预取取最新 N 封：左连接 [MessageBodies]，筛掉已下载的（有正文行
  /// 且 fetchState 非 notDownloaded），其余按 date 倒序取前 [limit]。
  Future<List<String>> messageIdsNeedingBody(
    String folderId, {
    int limit = 25,
  }) async {
    final query =
        select(messages).join([
            leftOuterJoin(
              messageBodies,
              messageBodies.messageId.equalsExp(messages.id),
            ),
          ])
          ..where(
            messages.folderId.equals(folderId) &
                (messageBodies.messageId.isNull() |
                    messageBodies.fetchState.equals(
                      BodyFetchState.notDownloaded.index,
                    )),
          )
          ..orderBy([OrderingTerm.desc(messages.date)])
          ..limit(limit);

    final rows = await query.get();
    return rows.map((row) => row.readTable(messages).id).toList();
  }

  // —— 同步游标 ——
  Future<SyncState?> getSyncState(String folderId) {
    return (select(
      syncStates,
    )..where((t) => t.folderId.equals(folderId))).getSingleOrNull();
  }

  Future<void> upsertSyncState(SyncStatesCompanion state) {
    return into(syncStates).insertOnConflictUpdate(state);
  }

  /// 搜索邮件（按主题、发件人、预览内容）。
  Future<List<MessageWithAccount>> searchMessages(
    String query, {
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final searchPattern = '%${query.toLowerCase()}%';

    // 联表查询：Messages JOIN Folders JOIN Accounts
    final queryBuilder =
        select(messages).join([
            innerJoin(folders, folders.id.equalsExp(messages.folderId)),
            innerJoin(accounts, accounts.id.equalsExp(messages.accountId)),
          ])
          ..where(
            messages.subject.lower().like(searchPattern) |
                messages.fromName.lower().like(searchPattern) |
                messages.fromEmail.lower().like(searchPattern) |
                messages.preview.lower().like(searchPattern),
          )
          ..orderBy([OrderingTerm.desc(messages.date)])
          ..limit(limit);

    final rows = await queryBuilder.get();

    return rows.map((row) {
      return MessageWithAccount(
        message: row.readTable(messages),
        accountId: row.readTable(accounts).id,
        accountEmail: row.readTable(accounts).email,
        accountDisplayName: row.readTable(accounts).displayName,
        folderType: row.readTable(folders).folderType,
        accountColorValue: row.readTable(accounts).colorValue,
      );
    }).toList();
  }

  /// 搜索特定账户的邮件。
  Future<List<Message>> searchAccountMessages(
    String accountId,
    String query, {
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final searchPattern = '%${query.toLowerCase()}%';

    return await (select(messages)
          ..where(
            (t) =>
                t.accountId.equals(accountId) &
                (t.subject.lower().like(searchPattern) |
                    t.fromName.lower().like(searchPattern) |
                    t.fromEmail.lower().like(searchPattern) |
                    t.preview.lower().like(searchPattern)),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit))
        .get();
  }
}
