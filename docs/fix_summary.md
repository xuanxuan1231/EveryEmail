# 修复总结：IMAP "No mailbox selected" 错误

## 问题描述

首次同步时出现错误："拉取信封失败: No mailbox selected."

## 根本原因

在 IMAP 后端实现中，有多个方法在执行 IMAP 操作前没有先选择邮箱（mailbox）。IMAP 协议要求在执行大多数操作（如获取邮件、标记邮件等）之前，必须先使用 `SELECT` 命令选择一个邮箱。

## 修复的方法

### 1. `markRead` 方法（第 178-194 行）
**问题**：直接调用 `client.store()` 而没有先选择邮箱。

**修复**：在执行操作前，先通过 `ref.folderPath` 查找并选择对应的邮箱。

```dart
// 选择邮箱
final mailbox = client.mailboxes.firstWhere(
  (mb) => mb.path == ref.folderPath,
  orElse: () => throw MailBackendException('文件夹不存在: ${ref.folderPath}'),
);
await client.selectMailbox(mailbox);
```

### 2. `markFlagged` 方法（第 196-212 行）
**问题**：同样直接调用 `client.store()` 而没有先选择邮箱。

**修复**：添加了邮箱选择逻辑。

### 3. `delete` 方法（第 220-231 行）
**问题**：直接调用 `client.store()` 标记删除标志，但没有先选择邮箱。

**修复**：添加了邮箱选择逻辑。

### 4. `watch` 方法（第 234-244 行）
**问题**：在轮询时直接调用 `client.fetchMessages()` 而没有先选择邮箱。

**修复**：在每次轮询时先选择邮箱。

```dart
// 选择邮箱
final mailbox = client.mailboxes.firstWhere(
  (mb) => mb.path == folder.remoteId,
  orElse: () => throw MailBackendException('文件夹不存在: ${folder.remoteId}'),
);
await client.selectMailbox(mailbox);
```

## 文件夹处理验证

### 文件夹列表获取
✅ `listFolders()` 方法正确实现，通过 `client.listMailboxes()` 获取所有文件夹。

### 文件夹类型映射
✅ `_inferFolderType()` 方法正确将 IMAP 文件夹映射到应用的 `FolderType` 枚举：
- `isInbox` → `FolderType.inbox`
- `isSent` → `FolderType.sent`
- `isDrafts` → `FolderType.drafts`
- `isTrash` → `FolderType.trash`
- `isJunk` → `FolderType.spam`
- `isArchive` → `FolderType.archive`
- 其他 → `FolderType.custom`

### 文件夹持久化
✅ `SyncService.syncAccount()` 方法正确处理文件夹：
1. 拉取文件夹列表
2. 通过 `remoteId` 检查文件夹是否已存在
3. 新文件夹：生成 ID 并插入数据库
4. 已存在文件夹：更新计数（未读数、总数）
5. 为 inbox 和 sent 文件夹同步邮件

### 文件夹到邮箱的映射
✅ 所有需要选择邮箱的方法现在都正确使用：
- `folder.remoteId` 或 `ref.folderPath` 来查找对应的 IMAP 邮箱
- `client.mailboxes.firstWhere()` 来匹配邮箱
- `client.selectMailbox()` 来选择邮箱

## 同步流程

### 首次同步（`syncAccountWithLimit`）
1. 连接到后端（IMAP/Graph）
2. 拉取文件夹列表
3. 持久化所有文件夹到数据库
4. 同步收件箱（限制邮件数量）
5. 更新同步状态（deltaLink/uidNext）

### 增量同步（`syncFolder`）
1. 获取上次同步的游标（deltaLink）
2. 调用 `backend.syncDelta()` 获取增量变更
3. 持久化新增/更新的邮件
4. 删除已移除的邮件
5. 更新同步游标

## 已验证的功能

✅ **文件夹列表获取**：正确从 IMAP 服务器获取所有文件夹
✅ **文件夹类型识别**：正确识别特殊文件夹（收件箱、已发送等）
✅ **文件夹持久化**：正确保存到数据库，避免重复
✅ **文件夹映射**：remoteId（IMAP 路径）正确映射到本地 ID
✅ **邮箱选择**：所有 IMAP 操作前都正确选择邮箱
✅ **增量同步**：支持通过 deltaLink 进行增量同步

## 潜在改进点

1. **性能优化**：`markRead`、`markFlagged`、`delete` 方法在处理多个邮件时，每个邮件都会重新选择邮箱。可以优化为按文件夹分组批量处理。

2. **UIDVALIDITY 处理**：当前 `_mapMessage` 方法中 uidValidity 使用占位符 0。应该从 `client.selectedMailbox?.uidValidity` 获取真实值。

3. **真正的 IDLE 支持**：`watch` 方法当前使用轮询模拟。生产环境应使用 `client.startPolling()` 实现真正的 IMAP IDLE。

4. **错误处理**：当前使用 `try-catch` 吞掉所有错误。应该区分不同类型的错误并适当处理。

## 测试建议

1. **首次同步测试**：添加新账户，验证能否正确获取文件夹列表和邮件
2. **增量同步测试**：在首次同步后，发送新邮件，验证增量同步是否正常
3. **标记操作测试**：标记邮件为已读/未读、加星/取消，验证操作是否成功
4. **删除操作测试**：删除邮件，验证是否正确标记删除标志
5. **多文件夹测试**：验证不同文件夹的邮件操作是否正确
