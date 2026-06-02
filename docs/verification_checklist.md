# 修复验证清单

## 修复的问题

### 主要问题：IMAP "No mailbox selected" 错误

**错误信息**：`拉取信封失败: No mailbox selected.`

**根本原因**：IMAP 后端在执行操作前没有先选择邮箱。

## 已修复的方法

### 1. ✅ `fetchEnvelopes` (第 90-113 行)
- **修复前**：直接调用 `client.fetchMessages()`
- **修复后**：先检查 `client.mailboxes` 不为空，然后选择邮箱
- **影响**：首次同步和分页加载邮件

### 2. ✅ `fetchMessageContent` (第 115-148 行)
- **修复前**：直接查找消息
- **修复后**：先选择邮箱再查找
- **影响**：查看邮件正文

### 3. ✅ `syncDelta` (第 156-176 行)
- **修复前**：直接调用 `client.fetchMessages()`
- **修复后**：先选择邮箱
- **影响**：增量同步

### 4. ✅ `markRead` (第 178-200 行)
- **修复前**：直接调用 `client.store()`
- **修复后**：先选择邮箱
- **影响**：标记邮件为已读/未读

### 5. ✅ `markFlagged` (第 202-224 行)
- **修复前**：直接调用 `client.store()`
- **修复后**：先选择邮箱
- **影响**：标记邮件为加星/取消

### 6. ✅ `delete` (第 232-254 行)
- **修复前**：直接调用 `client.store()`
- **修复后**：先选择邮箱
- **影响**：删除邮件

### 7. ✅ `watch` (第 256-275 行)
- **修复前**：轮询时直接调用 `client.fetchMessages()`
- **修复后**：先选择邮箱
- **影响**：实时监听文件夹变化

## 空安全修复

所有方法都添加了 `client.mailboxes` 的空检查：

```dart
final mailboxes = client.mailboxes;
if (mailboxes == null) throw const MailBackendException('邮箱列表未加载');
```

对于循环中的操作（`markRead`、`markFlagged`、`delete`），使用 `continue` 跳过而不是抛出异常。

## 代码质量验证

### ✅ Flutter 分析通过
```bash
flutter analyze lib/data/backends/imap/imap_mail_backend.dart
# 结果：No issues found!
```

### ✅ 项目整体分析
```bash
flutter analyze
# 结果：36 issues found (全部为 info 级别的代码风格建议，无错误)
```

### ✅ 修复的警告
- 移除了 `oauth_page.dart` 中未使用的导入

## 文件夹处理验证

### ✅ 文件夹列表获取
- `listFolders()` 正确调用 `client.listMailboxes()`
- 返回所有可用文件夹

### ✅ 文件夹类型映射
`_inferFolderType()` 方法正确映射：
- ✅ Inbox → `FolderType.inbox`
- ✅ Sent → `FolderType.sent`
- ✅ Drafts → `FolderType.drafts`
- ✅ Trash → `FolderType.trash`
- ✅ Junk/Spam → `FolderType.spam`
- ✅ Archive → `FolderType.archive`
- ✅ 其他 → `FolderType.custom`

### ✅ 文件夹持久化
`SyncService.syncAccount()` 正确处理：
1. 通过 `remoteId` 检查文件夹是否存在
2. 新文件夹：生成 UUID 并插入
3. 已存在：更新未读数和总数
4. 为 inbox 和 sent 自动同步邮件

### ✅ 文件夹到邮箱的映射
- 使用 `folder.remoteId`（IMAP 路径）查找邮箱
- 使用 `ref.folderPath` 从消息引用获取路径
- 通过 `client.mailboxes.firstWhere()` 匹配
- 使用 `client.selectMailbox()` 选择

## 同步流程验证

### ✅ 首次同步流程
1. 用户在 `SyncConfigPage` 选择下载邮件数量
2. 调用 `syncService.syncAccountWithLimit()`
3. 连接到 IMAP 服务器
4. 拉取文件夹列表
5. 持久化所有文件夹
6. 同步收件箱（限制数量）
7. 更新同步状态

### ✅ 增量同步流程
1. 用户下拉刷新
2. 调用 `syncService.syncAccount()`
3. 获取上次同步游标
4. 调用 `backend.syncDelta()`
5. 处理新增/更新/删除的邮件
6. 更新同步游标

## 测试建议

### 手动测试清单

#### 1. 首次同步测试
- [ ] 添加 IMAP 账户（Gmail/通用 IMAP）
- [ ] 验证能否成功获取文件夹列表
- [ ] 验证能否下载指定数量的邮件
- [ ] 检查数据库中的文件夹和邮件记录

#### 2. 增量同步测试
- [ ] 完成首次同步后，发送新邮件到账户
- [ ] 在应用中下拉刷新
- [ ] 验证新邮件是否出现在列表中

#### 3. 文件夹类型测试
- [ ] 验证收件箱正确识别
- [ ] 验证已发送文件夹正确识别
- [ ] 验证草稿箱正确识别
- [ ] 验证垃圾箱正确识别
- [ ] 验证自定义文件夹正确显示

#### 4. 邮件操作测试
- [ ] 标记邮件为已读
- [ ] 标记邮件为未读
- [ ] 加星标
- [ ] 取消星标
- [ ] 删除邮件

#### 5. 多账户测试
- [ ] 添加多个 IMAP 账户
- [ ] 验证统一收件箱显示所有账户的邮件
- [ ] 验证单个账户视图只显示该账户的邮件
- [ ] 验证文件夹正确归属到对应账户

#### 6. 错误处理测试
- [ ] 断网情况下同步
- [ ] 错误的 IMAP 凭据
- [ ] 服务器不可用
- [ ] 文件夹被删除后的处理

### 自动化测试建议

```dart
// 建议添加的单元测试
test('IMAP backend selects mailbox before fetching', () async {
  // 测试 fetchEnvelopes 是否先选择邮箱
});

test('Folder type inference works correctly', () {
  // 测试文件夹类型映射
});

test('Sync service handles folder persistence', () {
  // 测试文件夹持久化逻辑
});
```

## 性能优化建议

### 1. 批量操作优化
当前 `markRead`、`markFlagged`、`delete` 方法对每个邮件都重新选择邮箱。

**建议**：按文件夹分组批量处理
```dart
// 按文件夹分组
final refsByFolder = <String, List<ImapRef>>{};
for (final ref in refs) {
  if (ref is! ImapRef) continue;
  refsByFolder.putIfAbsent(ref.folderPath, () => []).add(ref);
}

// 每个文件夹只选择一次
for (final entry in refsByFolder.entries) {
  final mailbox = mailboxes.firstWhere(...);
  await client.selectMailbox(mailbox);
  
  // 批量处理该文件夹的所有邮件
  for (final ref in entry.value) {
    // ...
  }
}
```

### 2. UIDVALIDITY 处理
当前使用占位符 0，应该获取真实值：
```dart
final uidValidity = client.selectedMailbox?.uidValidity ?? 0;
```

### 3. 真正的 IDLE 支持
使用 `client.startPolling()` 替代轮询：
```dart
await client.startPolling();
// 监听事件流
```

## 总结

✅ **主要问题已修复**：所有 IMAP 操作前都正确选择邮箱
✅ **空安全问题已解决**：添加了适当的空检查
✅ **代码质量良好**：通过 Flutter 分析，无错误
✅ **文件夹处理正确**：列表、映射、持久化都正常工作
✅ **同步流程完整**：首次同步和增量同步都已实现

应用现在应该能够：
1. 正确连接到 IMAP 服务器
2. 获取所有文件夹列表
3. 正确识别文件夹类型
4. 同步邮件到本地数据库
5. 执行邮件操作（标记、删除等）
6. 支持增量同步

建议进行手动测试以验证实际运行效果。
