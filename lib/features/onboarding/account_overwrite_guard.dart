import 'package:flutter/material.dart';

import '../../data/local/database/app_database.dart';

class AccountOverwriteDecision {
  const AccountOverwriteDecision._({
    required this.shouldContinue,
    this.existingAccount,
  });

  const AccountOverwriteDecision.createNew() : this._(shouldContinue: true);

  const AccountOverwriteDecision.overwrite(Account account)
    : this._(shouldContinue: true, existingAccount: account);

  const AccountOverwriteDecision.cancel(Account account)
    : this._(shouldContinue: false, existingAccount: account);

  final bool shouldContinue;
  final Account? existingAccount;
}

Future<AccountOverwriteDecision> confirmAccountOverwrite({
  required BuildContext context,
  required AppDatabase db,
  required String email,
}) async {
  final existing = await db.accountDao.getAccountByEmail(email);
  if (existing == null) {
    return const AccountOverwriteDecision.createNew();
  }
  if (!context.mounted) {
    return AccountOverwriteDecision.cancel(existing);
  }

  final displayEmail = email.trim().isEmpty ? existing.email : email.trim();
  final overwrite = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('账户已存在'),
      content: Text(
        '已添加 $displayEmail。是否覆盖该账户的登录凭据和服务器信息？'
        '账户名称、颜色、排序和本地邮件会保留。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('覆盖'),
        ),
      ],
    ),
  );

  if (overwrite == true) {
    return AccountOverwriteDecision.overwrite(existing);
  }
  return AccountOverwriteDecision.cancel(existing);
}
