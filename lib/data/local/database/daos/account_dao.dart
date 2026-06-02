import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'account_dao.g.dart';

/// 账户读写。
@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  /// 监听全部账户（按排序序号）。
  Stream<List<Account>> watchAccounts() {
    return (select(accounts)
          ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
        .watch();
  }

  Future<List<Account>> getAccounts() => select(accounts).get();

  Future<Account?> getAccount(String id) {
    return (select(accounts)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertAccount(AccountsCompanion account) {
    return into(accounts).insert(account);
  }

  Future<void> upsertAccount(AccountsCompanion account) {
    return into(accounts).insertOnConflictUpdate(account);
  }

  Future<void> deleteAccount(String id) {
    return (delete(accounts)..where((t) => t.id.equals(id))).go();
  }
}
