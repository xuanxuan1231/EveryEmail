// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_task_dao.dart';

// ignore_for_file: type=lint
mixin _$SendTaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $SendTasksTable get sendTasks => attachedDatabase.sendTasks;
  SendTaskDaoManager get managers => SendTaskDaoManager(this);
}

class SendTaskDaoManager {
  final _$SendTaskDaoMixin _db;
  SendTaskDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$SendTasksTableTableManager get sendTasks =>
      $$SendTasksTableTableManager(_db.attachedDatabase, _db.sendTasks);
}
