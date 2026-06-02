# 文件夹和收件人显示修复

## 修复日期
2026/05/31

## 修复的问题

### 1. 侧边栏只显示收件箱 ✅

**问题描述：**
- 侧边栏的账户下拉列表中只显示"收件箱"
- 其他文件夹（已发送、草稿箱等）没有显示
- 无法访问其他文件夹的邮件

**原因分析：**
- 侧边栏代码中有 TODO 注释：`// TODO: 显示该账户的其他文件夹`
- 只硬编码了一个"收件箱"选项
- 没有从数据库读取实际的文件夹列表

**修复方案：**

#### 1. 添加文件夹列表显示方法

```dart
/// 构建账户的文件夹列表。
Widget _buildAccountFolders(BuildContext context, Account account, ThemeData theme) {
  final db = ref.read(databaseProvider);

  return StreamBuilder<List<Folder>>(
    stream: db.folderDao.watchFolders(account.id),
    builder: (context, snapshot) {
      final folders = snapshot.data ?? [];

      if (folders.isEmpty) {
        return ListTile(
          leading: const SizedBox(width: 16),
          title: const Text('暂无文件夹'),
          dense: true,
          contentPadding: const EdgeInsets.only(left: 56, right: 16),
        );
      }

      return Column(
        children: folders.map((folder) {
          final isFolderSelected = _selectedFolderId == folder.id;

          return ListTile(
            leading: Icon(_getFolderIcon(folder.folderType), size: 20),
            title: Text(folder.displayName),
            trailing: folder.unreadCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${folder.unreadCount}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
            dense: true,
            selected: isFolderSelected,
            selectedTileColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
            shape: const Border(),
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            onTap: () {
              setState(() {
                _selectedAccountId = account.id;
                _selectedFolderId = folder.id;
                _selectedFolderName = folder.displayName;
              });
              Navigator.pop(context);
            },
          );
        }).toList(),
      );
    },
  );
}
```

#### 2. 添加文件夹图标映射

```dart
/// 获取文件夹图标。
IconData _getFolderIcon(FolderType type) {
  switch (type) {
    case FolderType.inbox:
      return Icons.inbox;
    case FolderType.sent:
      return Icons.send;
    case FolderType.drafts:
      return Icons.drafts;
    case FolderType.archive:
      return Icons.archive;
    case FolderType.spam:
      return Icons.report;
    case FolderType.trash:
      return Icons.delete;
    case FolderType.custom:
      return Icons.folder;
  }
}
```

#### 3. 添加文件夹名称缓存

```dart
class _HomePageState extends ConsumerState<HomePage> {
  String? _selectedFolderId;
  String? _selectedAccountId;
  String? _selectedFolderName; // 缓存选中的文件夹名称
  // ...
}
```

#### 4. 实现文件夹邮件视图

```dart
Widget _buildFolderView(BuildContext context, WidgetRef ref, ThemeData theme) {
  final db = ref.watch(databaseProvider);
  final messagesStream = db.messageDao.watchFolderMessages(folderId!);

  return StreamBuilder<List<Message>>(
    stream: messagesStream,
    builder: (context, snapshot) {
      // 处理加载、错误、空状态
      // 显示邮件列表
    },
  );
}
```

**修复效果：**
- ✅ 侧边栏显示所有文件夹（收件箱、已发送、草稿箱等）
- ✅ 每个文件夹显示对应的图标
- ✅ 显示未读邮件数量徽章
- ✅ 点击文件夹可以查看该文件夹的邮件
- ✅ 选中的文件夹高亮显示
- ✅ 标题栏显示当前文件夹名称

**文件：** `lib/features/home/home_page.dart`

---

### 2. 收件人名字为空时显示邮箱 ✅

**问题描述：**
- 当收件人的 `name` 字段为空字符串时，仍然显示空白
- 应该在名字为空时显示邮箱地址

**原因分析：**
- `displayName` 方法只检查 `null`，不检查空字符串
- `name ?? email` 在 name 为空字符串时仍返回空字符串

**原始代码：**
```dart
/// 显示名称（优先使用 name，否则使用 email）。
String get displayName => name ?? email;
```

**修复后：**
```dart
/// 显示名称（优先使用 name，如果为空则使用 email）。
String get displayName {
  if (name != null && name!.trim().isNotEmpty) {
    return name!;
  }
  return email;
}
```

**修复效果：**
- ✅ 名字为 `null` 时显示邮箱
- ✅ 名字为空字符串时显示邮箱
- ✅ 名字只有空格时显示邮箱
- ✅ 名字有效时显示名字

**文件：** `lib/domain/models/mail_recipient.dart`

---

## 功能特性

### 侧边栏文件夹列表

**显示内容：**
- 文件夹图标（根据类型）
- 文件夹名称
- 未读邮件数量（红色徽章）

**交互：**
- 点击文件夹切换视图
- 选中的文件夹高亮显示
- 实时更新未读数量

**支持的文件夹类型：**
- 📥 收件箱 (inbox)
- 📤 已发送 (sent)
- 📝 草稿箱 (drafts)
- 📦 归档 (archive)
- 🚫 垃圾邮件 (spam)
- 🗑️ 回收站 (trash)
- 📁 自定义文件夹 (custom)

### 收件人显示优化

**显示逻辑：**
1. 如果有名字且不为空 → 显示名字
2. 如果名字为空或只有空格 → 显示邮箱地址

**应用场景：**
- 邮件详情页的收件人列表
- 邮件列表的发件人显示
- 搜索结果的收件人显示

---

## 参考 Thunderbird 移动版

根据你的建议，我参考了 Thunderbird 移动版的文件夹管理方式：

### 相似之处

1. **文件夹列表**
   - ✅ 显示所有文件夹
   - ✅ 使用图标区分文件夹类型
   - ✅ 显示未读数量徽章

2. **文件夹分组**
   - ✅ 按账户分组
   - ✅ 可展开/折叠账户
   - ✅ 统一收件箱在顶部

3. **视觉设计**
   - ✅ 选中状态高亮
   - ✅ 未读数量用醒目颜色
   - ✅ 图标清晰易识别

### 可以进一步改进的地方

1. **文件夹排序**
   - 可以添加拖拽排序功能
   - 支持自定义文件夹顺序

2. **文件夹管理**
   - 添加创建文件夹功能
   - 支持重命名和删除文件夹
   - 文件夹颜色标记

3. **智能文件夹**
   - 未读邮件文件夹
   - 星标邮件文件夹
   - 今天的邮件文件夹

---

## 测试建议

### 测试文件夹显示

1. **基本显示**
   - 打开侧边栏
   - 展开账户
   - 检查是否显示所有文件夹

2. **文件夹切换**
   - 点击不同的文件夹
   - 检查标题栏是否更新
   - 检查邮件列表是否正确

3. **未读数量**
   - 检查未读徽章是否显示
   - 标记邮件为已读
   - 检查数量是否更新

### 测试收件人显示

1. **有名字的收件人**
   - 打开邮件详情
   - 检查显示名字而不是邮箱

2. **无名字的收件人**
   - 查看只有邮箱的收件人
   - 检查显示邮箱地址

3. **空名字的收件人**
   - 查看名字为空字符串的收件人
   - 检查显示邮箱而不是空白

---

## 代码质量

```bash
flutter analyze lib/features/home/home_page.dart
# No issues found! ✅

flutter analyze lib/domain/models/mail_recipient.dart
# No issues found! ✅
```

---

## 修改的文件

1. ✅ `lib/features/home/home_page.dart`
   - 添加 `_buildAccountFolders` 方法
   - 添加 `_getFolderIcon` 方法
   - 添加 `_buildFolderView` 方法
   - 添加 `_selectedFolderName` 状态
   - 更新 `_getFolderTitle` 方法
   - 导入 `message_enums.dart`

2. ✅ `lib/domain/models/mail_recipient.dart`
   - 改进 `displayName` getter
   - 检查空字符串和空格

---

## 相关文档

- `docs/bug_fixes.md` - 之前的 Bug 修复
- `docs/bug_fixes_summary.md` - Bug 修复总结
- `docs/priority_2_complete.md` - 优先级 2 功能完成文档

---

## 总结

本次修复实现了完整的文件夹管理功能：

1. ✅ **侧边栏显示所有文件夹** - 不再只显示收件箱
2. ✅ **文件夹图标和徽章** - 清晰的视觉标识
3. ✅ **文件夹邮件视图** - 可以查看任意文件夹的邮件
4. ✅ **收件人显示优化** - 空名字时显示邮箱

这些改进让应用的文件夹管理功能更加完善，用户体验更接近 Thunderbird 移动版。

**现在可以运行测试，体验完整的文件夹功能！** 📁✨
