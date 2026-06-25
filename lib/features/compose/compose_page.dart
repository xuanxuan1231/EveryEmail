import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/providers.dart';
import '../../data/local/database/app_database.dart';
import '../../data/settings/account_settings.dart';
import '../../data/sync/outgoing_attachment_store.dart';
import '../../domain/enums/account_enums.dart';
import '../../domain/models/mail_address.dart';
import '../../domain/models/outgoing_message.dart';
import 'compose_args.dart';

/// 撰写邮件页（新邮件 / 回复 / 全部回复 / 转发 / 编辑草稿共用）。
///
/// 提交即把邮件交给 [SendQueueService] 入队发送；失败由主界面顶栏的发送队列角标
/// 提示与重试。本页不阻塞等待网络，入队后即返回。
class ComposePage extends ConsumerStatefulWidget {
  const ComposePage({this.args, super.key});

  final ComposeArgs? args;

  @override
  ConsumerState<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends ConsumerState<ComposePage> {
  final _toInputController = TextEditingController();
  final _ccInputController = TextEditingController();
  final _bccInputController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  final List<MailAddress> _toRecipients = [];
  final List<MailAddress> _ccRecipients = [];
  final List<MailAddress> _bccRecipients = [];

  String? _selectedAccountId;
  bool _sending = false;
  final List<OutgoingAttachment> _attachments = [];

  ComposeArgs get _args => widget.args ?? const ComposeArgs();

  @override
  void initState() {
    super.initState();
    final args = _args;
    _selectedAccountId = args.accountId;
    _setInitialRecipients(args.to, _toRecipients, _toInputController);
    _setInitialRecipients(args.cc, _ccRecipients, _ccInputController);
    _setInitialRecipients(args.bcc, _bccRecipients, _bccInputController);
    _subjectController.text = args.subject;
    _bodyController.text = args.bodyText;
    _attachments.addAll(args.attachments);
  }

  @override
  void dispose() {
    _toInputController.dispose();
    _ccInputController.dispose();
    _bccInputController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts =
        ref.watch(accountsStreamProvider).value ?? const <Account>[];

    final account = _resolveAccount(accounts);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose(account);
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Symbols.close),
            tooltip: '关闭',
            onPressed: () => _handleClose(account),
          ),
          title: Text(_titleForMode(_args.mode)),
          actions: [
            IconButton(
              icon: const Icon(Symbols.attach_file),
              tooltip: '添加附件',
              onPressed: _sending ? null : _pickAttachments,
            ),
            IconButton(
              icon: const Icon(Symbols.send),
              tooltip: '发送',
              onPressed: _sending || account == null
                  ? null
                  : () => _send(account),
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              icon: const Icon(Symbols.more_vert),
              onSelected: (value) {
                if (value == 'draft' && account != null) {
                  _saveDraftAndClose(account);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'draft',
                  child: Row(
                    children: [
                      Icon(Symbols.drafts),
                      SizedBox(width: 12),
                      Text('存为草稿'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: accounts.isEmpty
            ? Center(
                child: Text(
                  '请先添加一个邮箱账户',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : Column(
                children: [
                  _buildFromRow(theme, accounts, account),
                  const Divider(height: 1),
                  _buildRecipientField(
                    theme,
                    label: '收件人',
                    recipients: _toRecipients,
                    inputController: _toInputController,
                  ),
                  const Divider(height: 1),
                  _buildRecipientField(
                    theme,
                    label: '抄送',
                    recipients: _ccRecipients,
                    inputController: _ccInputController,
                  ),
                  const Divider(height: 1),
                  _buildRecipientField(
                    theme,
                    label: '密送',
                    recipients: _bccRecipients,
                    inputController: _bccInputController,
                  ),
                  const Divider(height: 1),
                  _buildSubjectField(theme),
                  const Divider(height: 1),
                  if (_attachments.isNotEmpty) ...[
                    _buildAttachments(theme),
                    const Divider(height: 1),
                  ],
                  Expanded(child: _buildBodyField(theme)),
                ],
              ),
      ),
    );
  }

  Widget _buildFromRow(
    ThemeData theme,
    List<Account> accounts,
    Account? account,
  ) {
    final label = account == null
        ? '选择发件账户'
        : (account.displayName.trim().isEmpty
              ? account.email
              : '${account.displayName} <${account.email}>');

    return InkWell(
      onTap: accounts.length <= 1
          ? null
          : () => _pickAccount(accounts, account),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              '发件人',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (accounts.length > 1)
              Icon(
                Symbols.expand_more,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientField(
    ThemeData theme, {
    required String label,
    required List<MailAddress> recipients,
    required TextEditingController inputController,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < recipients.length; i++)
                  InputChip(
                    label: Text(recipients[i].email),
                    tooltip: recipients[i].email,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onDeleted: _sending
                        ? null
                        : () => _removeRecipientChip(
                            recipients,
                            inputController,
                            i,
                          ),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 140,
                    maxWidth: 280,
                  ),
                  child: TextField(
                    controller: inputController,
                    enabled: !_sending,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (value) => _handleRecipientInputChanged(
                      recipients: recipients,
                      inputController: inputController,
                      value: value,
                    ),
                    onSubmitted: (_) =>
                        _commitRecipientInput(recipients, inputController),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Padding(padding: const EdgeInsets.only(top: 2), child: trailing),
        ],
      ),
    );
  }

  void _setInitialRecipients(
    List<MailAddress> source,
    List<MailAddress> recipients,
    TextEditingController inputController,
  ) {
    final pending = <MailAddress>[];
    for (final address in source) {
      if (RecipientParsing.isValidEmail(address.email)) {
        recipients.add(address);
      } else {
        pending.add(address);
      }
    }
    inputController.text = RecipientParsing.format(pending);
  }

  void _handleRecipientInputChanged({
    required List<MailAddress> recipients,
    required TextEditingController inputController,
    required String value,
  }) {
    if (value.endsWith(',') || value.endsWith('\n')) {
      _commitRecipientInput(recipients, inputController);
    }
  }

  void _commitRecipientInput(
    List<MailAddress> recipients,
    TextEditingController inputController,
  ) {
    final parsed = RecipientParsing.parse(inputController.text);
    if (parsed.isEmpty) return;

    final valid = <MailAddress>[];
    final pending = <MailAddress>[];
    for (final address in parsed) {
      if (RecipientParsing.isValidEmail(address.email)) {
        valid.add(address);
      } else {
        pending.add(address);
      }
    }
    if (valid.isEmpty) return;

    final pendingText = RecipientParsing.format(pending);
    setState(() {
      recipients.addAll(valid);
      inputController.text = pendingText;
      inputController.selection = TextSelection.collapsed(
        offset: pendingText.length,
      );
    });
  }

  void _removeRecipientChip(
    List<MailAddress> recipients,
    TextEditingController inputController,
    int index,
  ) {
    final wasLastChip = index == recipients.length - 1;
    final removed = recipients[index];
    final restoredText = RecipientParsing.format([removed]);
    final existingText = inputController.text.trim();
    final nextInputText = existingText.isEmpty
        ? restoredText
        : '$restoredText, $existingText';

    setState(() {
      recipients.removeAt(index);
      if (wasLastChip) {
        inputController.text = nextInputText;
        inputController.selection = TextSelection.collapsed(
          offset: nextInputText.length,
        );
      }
    });
  }

  List<MailAddress> _recipientValues(
    List<MailAddress> recipients,
    TextEditingController inputController,
  ) {
    return [...recipients, ...RecipientParsing.parse(inputController.text)];
  }

  String _recipientText(
    List<MailAddress> recipients,
    TextEditingController inputController,
  ) {
    return RecipientParsing.format(
      _recipientValues(recipients, inputController),
    );
  }

  Widget _buildSubjectField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _subjectController,
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '主题',
        ),
        style: theme.textTheme.titleMedium,
      ),
    );
  }

  Widget _buildBodyField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: TextField(
        controller: _bodyController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '正文',
        ),
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
    );
  }

  Account? _resolveAccount(List<Account> accounts) {
    if (accounts.isEmpty) return null;
    for (final a in accounts) {
      if (a.id == _selectedAccountId) return a;
    }
    return accounts.first;
  }

  Color _accountColor(ThemeData theme, Account account) {
    return account.colorValue == null
        ? theme.colorScheme.primary
        : Color(account.colorValue!);
  }

  Future<void> _pickAccount(List<Account> accounts, Account? current) async {
    final picked = await showModalBottomSheet<Account>(
      context: context,
      builder: (context) {
        final sheetTheme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in accounts)
                ListTile(
                  leading: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _accountColor(sheetTheme, a),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sheetTheme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  selected: a.id == current?.id,
                  title: Text(
                    a.displayName.trim().isEmpty ? a.email : a.displayName,
                  ),
                  subtitle: Text(a.email),
                  trailing: a.id == current?.id
                      ? const Icon(Symbols.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(a),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedAccountId = picked.id);
    }
  }

  void _commitAllRecipientInputs() {
    _commitRecipientInput(_toRecipients, _toInputController);
    _commitRecipientInput(_ccRecipients, _ccInputController);
    _commitRecipientInput(_bccRecipients, _bccInputController);
  }

  ({List<MailAddress> to, List<MailAddress> cc, List<MailAddress> bcc})
  _currentRecipients() {
    return (
      to: _recipientValues(_toRecipients, _toInputController),
      cc: _recipientValues(_ccRecipients, _ccInputController),
      bcc: _recipientValues(_bccRecipients, _bccInputController),
    );
  }

  Widget _buildAttachments(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _attachments.length; i++)
            Chip(
              avatar: const Icon(Symbols.attach_file, size: 18),
              label: Text(
                '${_attachments[i].filename}  (${_formatSize(_attachments[i].size)})',
              ),
              onDeleted: _sending ? null : () => _removeAttachment(i),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.pickFiles();
    if (result == null || !mounted) return;
    final accounts =
        ref.read(accountsStreamProvider).value ?? const <Account>[];
    final account = _resolveAccount(accounts);
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      try {
        final att = await OutgoingAttachmentStore.stageFile(
          path,
          filename: file.name,
        );
        if (!mounted) return;
        final next = [..._attachments, att];
        final error = account == null
            ? null
            : _attachmentLimitError(account, next);
        if (error != null) {
          await _deleteAttachmentFile(att);
          _toast(error);
          continue;
        }
        setState(() => _attachments.add(att));
      } catch (e) {
        _toast('添加附件失败：${file.name}');
      }
    }
  }

  Future<void> _removeAttachment(int index) async {
    final att = _attachments[index];
    setState(() => _attachments.removeAt(index));
    // 删除暂存文件（转发/草稿带入的原文件也只是该邮件的副本，可安全删除）。
    try {
      await _deleteAttachmentFile(att);
    } catch (_) {}
  }

  Future<void> _deleteAttachmentFile(OutgoingAttachment att) async {
    final file = File(att.localPath);
    if (await file.exists()) await file.delete();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _send(Account account) async {
    _commitAllRecipientInputs();
    final recipients = _currentRecipients();
    final to = recipients.to;
    final cc = recipients.cc;
    final bcc = recipients.bcc;

    if (to.isEmpty && cc.isEmpty && bcc.isEmpty) {
      _toast('请至少填写一个收件人');
      return;
    }
    final invalid = [
      ...to,
      ...cc,
      ...bcc,
    ].where((a) => !RecipientParsing.isValidEmail(a.email)).toList();
    if (invalid.isNotEmpty) {
      _toast('收件人邮箱格式有误：${invalid.first.email}');
      return;
    }

    setState(() => _sending = true);
    try {
      final settings = await AccountSettingsStore.read(account.id);
      if (!settings.sendEnabled) {
        _toast('该账户已关闭发送');
        return;
      }
      final attachmentError = _attachmentLimitError(account, _attachments);
      if (attachmentError != null) {
        _toast(attachmentError);
        return;
      }

      await ref
          .read(sendQueueServiceProvider)
          .enqueue(
            account.id,
            _buildMessage(account, to: to, cc: cc, bcc: bcc),
            draftMessageId: _args.draftMessageId,
          );

      if (!mounted) return;
      _toast('正在发送…');
      context.pop();
    } catch (e) {
      _toast('发送失败：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  OutgoingMessage _buildMessage(
    Account account, {
    required List<MailAddress> to,
    required List<MailAddress> cc,
    required List<MailAddress> bcc,
  }) {
    final text = _bodyController.text;
    return OutgoingMessage(
      from: MailAddress(
        email: account.email,
        name: account.displayName.trim().isEmpty ? null : account.displayName,
      ),
      to: to,
      cc: cc,
      bcc: bcc,
      subject: _subjectController.text.trim(),
      text: text,
      html: _textToHtml(text),
      inReplyTo: _args.inReplyTo,
      references: _args.references,
      action: _outgoingAction(_args.mode),
      sourceMessageId: _args.sourceMessageId,
      serverDraftId: _args.serverDraftId,
      attachments: List.of(_attachments),
    );
  }

  OutgoingMessageAction _outgoingAction(ComposeMode mode) {
    return switch (mode) {
      ComposeMode.reply => OutgoingMessageAction.reply,
      ComposeMode.replyAll => OutgoingMessageAction.replyAll,
      ComposeMode.forward => OutgoingMessageAction.forward,
      ComposeMode.newMail ||
      ComposeMode.draft => OutgoingMessageAction.newMessage,
    };
  }

  /// 保存为本地草稿。返回是否成功（用于关闭流程决定能否离开）。
  Future<bool> _saveDraft(Account account) async {
    _commitAllRecipientInputs();
    final attachmentError = _attachmentLimitError(account, _attachments);
    if (attachmentError != null) {
      _toast(attachmentError);
      return false;
    }
    final recipients = _currentRecipients();
    final message = _buildMessage(
      account,
      to: recipients.to,
      cc: recipients.cc,
      bcc: recipients.bcc,
    );
    try {
      final id = await ref
          .read(syncServiceProvider)
          .saveLocalDraft(
            accountId: account.id,
            draftMessageId: _args.draftMessageId,
            message: message,
          );
      if (id == null) {
        _toast('该账户没有草稿文件夹，无法保存草稿');
        return false;
      }
      await ref
          .read(draftSyncQueueServiceProvider)
          .enqueueSave(
            accountId: account.id,
            draftMessageId: id,
            message: message,
          );
      _toast('已保存草稿');
      return true;
    } catch (e) {
      _toast('保存草稿失败：$e');
      return false;
    }
  }

  String? _attachmentLimitError(
    Account account,
    List<OutgoingAttachment> attachments,
  ) {
    if (attachments.isEmpty) return null;
    final limit = _attachmentLimitFor(account);
    final total = attachments.fold<int>(0, (sum, a) => sum + a.size);
    final oversized = attachments
        .where((a) => a.size > limit.singleFileBytes)
        .toList();
    if (oversized.isNotEmpty) {
      return '${oversized.first.filename} 超过单个附件上限 ${_formatSize(limit.singleFileBytes)}';
    }
    if (total > limit.totalBytes) {
      return '附件总大小超过 ${_formatSize(limit.totalBytes)}，请移除部分附件';
    }
    return null;
  }

  ({int singleFileBytes, int totalBytes}) _attachmentLimitFor(Account account) {
    const mib = 1024 * 1024;
    return switch (account.accountType) {
      AccountType.microsoftGraph => (
        singleFileBytes: 150 * mib,
        totalBytes: 150 * mib,
      ),
      AccountType.gmailOAuth || AccountType.genericImap => (
        singleFileBytes: 25 * mib,
        totalBytes: 25 * mib,
      ),
    };
  }

  /// 存草稿并关闭（顶栏「存为草稿」菜单）。
  Future<void> _saveDraftAndClose(Account account) async {
    final saved = await _saveDraft(account);
    if (saved && mounted) context.pop();
  }

  /// 关闭请求：有内容则询问保存草稿 / 放弃 / 取消。
  Future<void> _handleClose(Account? account) async {
    if (_sending || !_isDirty()) {
      if (mounted) context.pop();
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存草稿？'),
        content: const Text('是否保存这封未发送的邮件为草稿？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text('放弃'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('保存草稿'),
          ),
        ],
      ),
    );
    if (action == null || action == 'cancel' || !mounted) return;
    if (action == 'save') {
      if (account == null) {
        _toast('请选择发件账户');
        return;
      }
      final saved = await _saveDraft(account);
      if (saved && mounted) context.pop();
      return;
    }
    if (action == 'discard' && _args.draftMessageId != null) {
      final deleted = await _discardDraft(account);
      if (!deleted) return;
    }
    if (mounted) context.pop();
  }

  Future<bool> _discardDraft(Account? account) async {
    final accountId = account?.id ?? _args.accountId;
    if (accountId == null) {
      _toast('请选择发件账户');
      return false;
    }
    try {
      await ref
          .read(draftSyncQueueServiceProvider)
          .enqueueDelete(
            accountId: accountId,
            draftMessageId: _args.draftMessageId,
            serverDraftId: _args.serverDraftId,
          );
      await ref
          .read(syncServiceProvider)
          .deleteLocalDraft(draftMessageId: _args.draftMessageId);
      // 清理本地暂存附件，避免 outgoing/ 目录残留泄漏（草稿被丢弃后这些副本无人持有）。
      for (final att in _attachments) {
        try {
          await _deleteAttachmentFile(att);
        } catch (_) {}
      }
      _toast('已删除草稿');
      return true;
    } catch (e) {
      _toast('删除草稿失败：$e');
      return false;
    }
  }

  /// 内容是否相对入口参数发生了改动（用于关闭时是否提示存草稿）。
  bool _isDirty() {
    final args = _args;
    if (_attachments.length != args.attachments.length) return true;
    return _recipientText(_toRecipients, _toInputController) !=
            RecipientParsing.format(args.to) ||
        _recipientText(_ccRecipients, _ccInputController) !=
            RecipientParsing.format(args.cc) ||
        _recipientText(_bccRecipients, _bccInputController) !=
            RecipientParsing.format(args.bcc) ||
        _subjectController.text != args.subject ||
        _bodyController.text != args.bodyText;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _titleForMode(ComposeMode mode) {
    switch (mode) {
      case ComposeMode.reply:
        return '回复';
      case ComposeMode.replyAll:
        return '全部回复';
      case ComposeMode.forward:
        return '转发';
      case ComposeMode.draft:
        return '草稿';
      case ComposeMode.newMail:
        return '写邮件';
    }
  }

  /// 从纯文本生成一个 HTML 替代部件：转义 + 换行转 <br>，保留空白。
  /// 让支持 HTML 的客户端有可点链接/可读排版；纯文本客户端回退到 text 部件。
  String _textToHtml(String text) {
    final escaped = const HtmlEscape().convert(text).replaceAll('\n', '<br>\n');
    return '<div style="white-space:pre-wrap;'
        'font-family:-apple-system,Segoe UI,Roboto,sans-serif;'
        'font-size:14px;line-height:1.5;">$escaped</div>';
  }
}
