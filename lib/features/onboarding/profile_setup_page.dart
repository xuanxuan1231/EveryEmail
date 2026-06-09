import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/local/database/app_database.dart';
import '../settings/widgets/account_profile_editors.dart';

/// 完善账户信息页面。
///
/// 在密码验证 / OAuth 完成、账户已写入数据库之后，首次同步之前插入这一步，
/// 让用户先修改名称、颜色与头像（邮箱与服务器属登录身份，保持只读）。
/// 「下一步」把名称/颜色落库后再进入同步设置页。
class AccountProfileSetupPage extends ConsumerStatefulWidget {
  const AccountProfileSetupPage({
    required this.email,
    required this.accountId,
    super.key,
  });

  final String email;
  final String accountId;

  @override
  ConsumerState<AccountProfileSetupPage> createState() =>
      _AccountProfileSetupPageState();
}

class _AccountProfileSetupPageState
    extends ConsumerState<AccountProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  /// 本地草稿配色（null 表示用主题默认色）。首帧由账户当前值注入一次。
  int? _selectedColor;
  bool _seeded = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Account? _findAccount(List<Account>? accounts, String accountId) {
    if (accounts == null) return null;
    for (final account in accounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final account = _findAccount(accountsAsync.value, widget.accountId);

    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('完善信息')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 首帧用账户当前名称/颜色注入草稿，之后交给用户编辑。
    if (!_seeded) {
      _seeded = true;
      _nameController.text = account.displayName;
      _selectedColor = account.colorValue;
    }

    final settings = ref.watch(accountSettingsProvider(account.id));
    final draftName = _nameController.text.trim();
    final previewAccount = account.copyWith(
      displayName: draftName.isEmpty ? account.displayName : draftName,
      colorValue: Value(_selectedColor),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('完善信息')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Text('完善账户信息', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              '设置账户的名称、颜色和头像，稍后也可在设置中修改。',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // 头像预览（点击编辑）
            Center(
              child: Column(
                children: [
                  InkWell(
                    onTap: () => showAccountAvatarSheet(
                      context,
                      account: account,
                      settings: settings,
                    ),
                    customBorder: const CircleBorder(),
                    child: AccountAvatar(
                      account: previewAccount,
                      settings: settings,
                      radius: 44,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => showAccountAvatarSheet(
                      context,
                      account: account,
                      settings: settings,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('编辑头像'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 名称
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '账户显示名称',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '账户名称不能为空';
                }
                return null;
              },
              enabled: !_isSaving,
            ),
            const SizedBox(height: 24),

            // 颜色
            Text(
              '颜色',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AccountColorDot(
                  color: theme.colorScheme.primary,
                  selected: _selectedColor == null,
                  tooltip: '默认',
                  onTap: _isSaving
                      ? () {}
                      : () => setState(() => _selectedColor = null),
                ),
                for (final value in kAccountColorValues)
                  AccountColorDot(
                    color: Color(value),
                    selected: _selectedColor == value,
                    tooltip: '#${value.toRadixString(16).toUpperCase()}',
                    onTap: _isSaving
                        ? () {}
                        : () => setState(() => _selectedColor = value),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // 邮箱（只读）
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.email, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 2),
                        Text(
                          '邮箱与服务器设置不可更改',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 下一步
            FilledButton(
              onPressed: _isSaving ? null : () => _continue(account),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('下一步'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continue(Account account) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .updateAccountProfile(
            account.id,
            displayName: _nameController.text.trim(),
            colorValue: Value(_selectedColor),
          );

      if (!mounted) return;
      context.push(
        '/onboarding/sync-config?email=${Uri.encodeComponent(widget.email)}'
        '&accountId=${Uri.encodeComponent(account.id)}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }
}
