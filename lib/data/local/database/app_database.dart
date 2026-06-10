import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../../domain/enums/account_enums.dart';
import '../../../domain/enums/message_enums.dart';
import 'daos/account_dao.dart';
import 'daos/folder_dao.dart';
import 'daos/message_dao.dart';
import 'daos/outbox_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// 应用本地数据库（Drift / SQLite）。
///
/// 是 UI 的唯一读取源：界面通过响应式查询（`watch*`）订阅，网络层只负责写入/刷新。
@DriftDatabase(
  tables: [Accounts, Folders, Messages, MessageBodies, SyncStates, OutboxOps],
  daos: [AccountDao, FolderDao, MessageDao, OutboxDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v2：文件夹新增逐个偏好开关（显示/同步/通知/统一化）。旧行有默认值，自动得 true。
      if (from < 2) {
        await m.addColumn(folders, folders.visible);
        await m.addColumn(folders, folders.syncEnabled);
        await m.addColumn(folders, folders.notificationsEnabled);
        await m.addColumn(folders, folders.unified);
      }
      // v3：Gmail 从 IMAP 切换到 Gmail REST API 后端，新增 gmailMessageId 列。
      if (from < 3) {
        await m.addColumn(messages, messages.gmailMessageId);
        // Gmail 账户在 IMAP 时代缓存的本地数据（imapUid 标识、文件夹路径 remoteId）
        // 与 Gmail API 的 message id / label id 不兼容，沿用会产生重复行。这里一次性
        // 清掉 Gmail 账户（accountType=0 即 gmailOAuth）的缓存，让其经 Gmail API 全量
        // 重建——邮件本是服务端缓存，无数据丢失（仅文件夹级偏好开关会重置为默认）。
        // 迁移期间外键级联未必生效，按依赖顺序显式删除。
        const gmailAccounts = 'SELECT id FROM accounts WHERE account_type = 0';
        await customStatement(
          'DELETE FROM sync_states WHERE folder_id IN '
          '(SELECT id FROM folders WHERE account_id IN ($gmailAccounts))',
        );
        await customStatement(
          'DELETE FROM message_bodies WHERE message_id IN '
          '(SELECT id FROM messages WHERE account_id IN ($gmailAccounts))',
        );
        await customStatement(
          'DELETE FROM messages WHERE account_id IN ($gmailAccounts)',
        );
        await customStatement(
          'DELETE FROM folders WHERE account_id IN ($gmailAccounts)',
        );
      }
      // v4：历史回填（“加载更多”）游标列。旧行默认 backfillCursor=null、backfillDone=false。
      if (from < 4) {
        await m.addColumn(syncStates, syncStates.backfillCursor);
        await m.addColumn(syncStates, syncStates.backfillDone);
      }
      // v5：修正 IMAP 的会话键（thread_key）。历史上 IMAP 误存了 References 头
      // 原文（整条链），同一会话每封键不同、无法归并；现改为取链首根 id。这里仅
      // 针对 IMAP 账户（account_type=2）从既有数据一次性恢复，使会话视图立即可用，
      // 无需重新同步。Gmail(threadId)/Graph(conversationId) 的键无空格、不受影响。
      if (from < 5) {
        const imapAccounts =
            'SELECT id FROM accounts WHERE account_type = 2';
        // 1) 含内部空格的 References 链 → 取首个 token（线程根 id）。
        await customStatement(
          "UPDATE messages SET thread_key = "
          "SUBSTR(TRIM(thread_key), 1, INSTR(TRIM(thread_key), ' ') - 1) "
          "WHERE account_id IN ($imapAccounts) AND TRIM(thread_key) LIKE '% %'",
        );
        // 2) 仍为空但有 Message-ID（无 References 的线程根）→ 退回自身 Message-ID，
        //    使后续回复（其 References 根 = 此 id）能归并到同一会话。
        await customStatement(
          'UPDATE messages SET thread_key = message_id_header '
          'WHERE account_id IN ($imapAccounts) '
          'AND thread_key IS NULL AND message_id_header IS NOT NULL',
        );
      }
    },
    beforeOpen: (details) async {
      // SQLite 默认不启用外键约束；开启后级联删除（账户→文件夹→邮件）才生效。
      await customStatement('PRAGMA foreign_keys = ON');
      await _ensurePerformanceIndexes();
    },
  );

  /// 默认连接：应用文档目录下的 everyemail.sqlite。
  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'everyemail');
  }

  Future<void> _ensurePerformanceIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_folder_date '
      'ON messages(folder_id, date DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_account_date '
      'ON messages(account_id, date DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_account_thread '
      'ON messages(account_id, thread_key)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_folders_type_account '
      'ON folders(folder_type, account_id)',
    );
  }
}
