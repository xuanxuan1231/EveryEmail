import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/providers.dart';
import '../../../data/local/database/app_database.dart';
import '../../../domain/enums/message_enums.dart';

/// 文件夹选择器对话框。
class FolderPickerDialog extends ConsumerWidget {
  const FolderPickerDialog({
    required this.accountId,
    this.currentFolderId,
    super.key,
  });

  final String accountId;
  final String? currentFolderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Symbols.folder, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('选择文件夹', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Symbols.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 文件夹列表
            Flexible(
              child: FutureBuilder<List<Folder>>(
                future: db.folderDao.getFolders(accountId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '加载失败: ${snapshot.error}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    );
                  }

                  final folders = snapshot.data ?? [];
                  if (folders.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '没有可用的文件夹',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      final isCurrent = folder.id == currentFolderId;

                      return ListTile(
                        leading: Icon(
                          _getFolderIcon(folder.folderType),
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          folder.displayName,
                          style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isCurrent ? theme.colorScheme.primary : null,
                          ),
                        ),
                        subtitle: folder.totalCount > 0
                            ? Text('${folder.totalCount} 封邮件')
                            : null,
                        trailing: isCurrent
                            ? Icon(
                                Symbols.check,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        enabled: !isCurrent,
                        onTap: isCurrent
                            ? null
                            : () => Navigator.of(context).pop(folder),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFolderIcon(FolderType type) {
    switch (type) {
      case FolderType.inbox:
        return Symbols.inbox;
      case FolderType.sent:
        return Symbols.send;
      case FolderType.drafts:
        return Symbols.drafts;
      case FolderType.archive:
        return Symbols.archive;
      case FolderType.spam:
        return Symbols.report;
      case FolderType.trash:
        return Symbols.delete;
      case FolderType.custom:
        return Symbols.folder;
    }
  }
}

/// 显示文件夹选择器。
Future<Folder?> showFolderPicker(
  BuildContext context, {
  required String accountId,
  String? currentFolderId,
}) {
  return showDialog<Folder>(
    context: context,
    builder: (context) => FolderPickerDialog(
      accountId: accountId,
      currentFolderId: currentFolderId,
    ),
  );
}
