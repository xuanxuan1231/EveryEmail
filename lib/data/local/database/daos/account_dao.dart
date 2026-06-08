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
    return (select(accounts)..orderBy([
          (t) => OrderingTerm.asc(t.sortIndex),
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.email),
        ]))
        .watch();
  }

  Future<List<Account>> getAccounts() {
    return (select(accounts)..orderBy([
          (t) => OrderingTerm.asc(t.sortIndex),
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.email),
        ]))
        .get();
  }

  Future<Account?> getAccount(String id) {
    return (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertAccount(AccountsCompanion account) {
    return into(accounts).insert(account);
  }

  Future<void> upsertAccount(AccountsCompanion account) {
    return into(accounts).insertOnConflictUpdate(account);
  }

  Future<void> updateProfile(
    String id, {
    String? displayName,
    Value<int?> colorValue = const Value.absent(),
  }) {
    return (update(accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(
        displayName: displayName == null
            ? const Value.absent()
            : Value(displayName),
        colorValue: colorValue,
      ),
    );
  }

  Future<void> deleteAccount(String id) {
    return (delete(accounts)..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateSortOrder(List<String> accountIds) {
    return transaction(() async {
      for (var index = 0; index < accountIds.length; index++) {
        await (update(accounts)..where((t) => t.id.equals(accountIds[index])))
            .write(AccountsCompanion(sortIndex: Value(index)));
      }
    });
  }
}
