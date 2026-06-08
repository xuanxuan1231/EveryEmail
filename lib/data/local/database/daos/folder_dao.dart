import 'package:drift/drift.dart';

import '../../../../domain/enums/message_enums.dart';
import '../../../../domain/models/unified_mailbox.dart';
import '../app_database.dart';
import '../tables.dart';

part 'folder_dao.g.dart';

/// 文件夹读写。
@DriftAccessor(tables: [Folders])
class FolderDao extends DatabaseAccessor<AppDatabase> with _$FolderDaoMixin {
  FolderDao(super.db);

  /// 监听某账户的文件夹列表（按排序序号）。
  Stream<List<Folder>> watchFolders(String accountId) {
    return (select(folders)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .watch();
  }

  Future<List<Folder>> getFolders(String accountId) {
    return (select(folders)..where((t) => t.accountId.equals(accountId))).get();
  }

  /// 监听统一账户下固定统一化文件夹的摘要。
  ///
  /// 统一文件夹不是数据库行；这里把所有真实账户中相同语义角色、且开启了
  /// 「统一化」的文件夹计数汇总到 [UnifiedMailbox.folders]。
  Stream<List<UnifiedMailboxFolder>> watchUnifiedFolders() {
    final unifiedTypes = UnifiedMailbox.folders.map((f) => f.type).toList();
    final query = select(folders)
      ..where((t) {
        final expressions = unifiedTypes.map((type) {
          return t.folderType.equals(type.index);
        }).toList();
        return expressions.reduce((a, b) => a | b) & t.unified.equals(true);
      });

    return query.watch().map((rows) {
      return UnifiedMailbox.folders.map((unifiedFolder) {
        final sourceRows = rows.where((row) {
          return row.folderType == unifiedFolder.type;
        }).toList();
        final sourceAccountIds = sourceRows.map((row) => row.accountId).toSet();
        final unreadCount = sourceRows.fold<int>(
          0,
          (sum, row) => sum + row.unreadCount,
        );
        final totalCount = sourceRows.fold<int>(
          0,
          (sum, row) => sum + row.totalCount,
        );

        return unifiedFolder.copyWith(
          unreadCount: unreadCount,
          totalCount: totalCount,
          sourceAccountCount: sourceAccountIds.length,
        );
      }).toList();
    });
  }

  Future<Folder?> getFolder(String id) {
    return (select(folders)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 按后端原生标识查找（同步对账时把远端文件夹映射到本地行）。
  Future<Folder?> getByRemoteId(String accountId, String remoteId) {
    return (select(folders)..where(
          (t) => t.accountId.equals(accountId) & t.remoteId.equals(remoteId),
        ))
        .getSingleOrNull();
  }

  Future<void> upsertFolder(FoldersCompanion folder) {
    return into(folders).insertOnConflictUpdate(folder);
  }

  Future<void> upsertFolders(List<FoldersCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(folders, rows);
    });
  }

  Future<void> updateCounts(String id, {int? unread, int? total}) {
    return (update(folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(
        unreadCount: unread == null ? const Value.absent() : Value(unread),
        totalCount: total == null ? const Value.absent() : Value(total),
      ),
    );
  }

  /// 更新单个文件夹的用户偏好开关。未传入的参数保持原值。
  Future<void> updateFolderFlags(
    String id, {
    bool? visible,
    bool? syncEnabled,
    bool? notificationsEnabled,
    bool? unified,
  }) {
    return (update(folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(
        visible: visible == null ? const Value.absent() : Value(visible),
        syncEnabled: syncEnabled == null
            ? const Value.absent()
            : Value(syncEnabled),
        notificationsEnabled: notificationsEnabled == null
            ? const Value.absent()
            : Value(notificationsEnabled),
        unified: unified == null ? const Value.absent() : Value(unified),
      ),
    );
  }

  /// 同步对账时使用：用远端最新值覆盖类型、名称和计数。
  /// 旧版 Graph 后端没有 select wellKnownName，所有文件夹被错误写为 custom；
  /// 升级后需要重写类型，否则 inbox 永远不会被识别。
  Future<void> updateFromRemote(
    String id, {
    required String displayName,
    required FolderType folderType,
    required int unreadCount,
    required int totalCount,
    required int sortIndex,
  }) {
    return (update(folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(
        displayName: Value(displayName),
        folderType: Value(folderType),
        unreadCount: Value(unreadCount),
        totalCount: Value(totalCount),
        sortIndex: Value(sortIndex),
      ),
    );
  }
}
