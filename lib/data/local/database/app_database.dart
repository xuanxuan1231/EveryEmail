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
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // SQLite 默认不启用外键约束；开启后级联删除（账户→文件夹→邮件）才生效。
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// 默认连接：应用文档目录下的 everyemail.sqlite。
  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'everyemail');
  }
}
