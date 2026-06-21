// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft_sync_task_dao.dart';

// ignore_for_file: type=lint
mixin _$DraftSyncTaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $DraftSyncTasksTable get draftSyncTasks => attachedDatabase.draftSyncTasks;
  DraftSyncTaskDaoManager get managers => DraftSyncTaskDaoManager(this);
}

class DraftSyncTaskDaoManager {
  final _$DraftSyncTaskDaoMixin _db;
  DraftSyncTaskDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$DraftSyncTasksTableTableManager get draftSyncTasks =>
      $$DraftSyncTasksTableTableManager(
        _db.attachedDatabase,
        _db.draftSyncTasks,
      );
}
