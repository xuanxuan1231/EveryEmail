# Bug 修复文档

## 修复日期
2026/05/31

## 修复的问题

### 1. 收件人 JSON 解析错误 ✅

**问题描述：**
- 收件人数据在数据库中存储的 JSON 格式不正确
- `_encodeRecipients` 方法生成的字符串缺少外层方括号
- 没有正确转义特殊字符（引号、换行符）

**原始代码：**
```dart
String _encodeRecipients(List<dynamic> recipients) {
  // 简化：存储为 JSON 字符串
  return recipients.map((r) => '{"name":"${r.name ?? ''}","email":"${r.email}"}').join(',');
}
```

**问题：**
- 生成的格式：`{"name":"A","email":"a@x.com"},{"name":"B","email":"b@x.com"}`
- 缺少外层 `[]`，不是有效的 JSON 数组
- 没有转义特殊字符

**修复后：**
```dart
String _encodeRecipients(List<dynamic> recipients) {
  if (recipients.isEmpty) return '[]';

  // 正确的 JSON 数组格式
  final jsonList = recipients.map((r) {
    final name = (r.name ?? '').replaceAll('"', '\\"').replaceAll('\n', ' ');
    final email = (r.email ?? '').replaceAll('"', '\\"');
    return '{"name":"$name","email":"$email"}';
  }).join(',');

  return '[$jsonList]';
}
```

**修复效果：**
- 生成正确的 JSON 数组格式：`[{"name":"A","email":"a@x.com"},{"name":"B","email":"b@x.com"}]`
- 正确转义引号和换行符
- 空数组返回 `[]`

**文件：** `lib/data/sync/sync_service.dart:238-248`

---

### 2. 未读/已读状态更新不及时 ✅

**问题描述：**
- 标记邮件为未读或切换星标后，UI 不会立即更新
- 需要返回列表页再进入才能看到变化

**原因分析：**
- 邮件详情页使用 `FutureBuilder` 加载数据
- `FutureBuilder` 只在初始化时加载一次
- 更新数据库后不会触发重新加载

**修复方案：**
1. 在 `MessageDao` 中添加 `watchMessage` 方法，返回 Stream
2. 将详情页的 `FutureBuilder` 改为 `StreamBuilder`
3. 数据库更新后自动触发 UI 刷新

**修改 1：添加 watchMessage 方法**
```dart
// lib/data/local/database/daos/message_dao.dart

/// 监听单条邮件（用于实时更新）。
Stream<Message?> watchMessage(String id) {
  return (select(messages)..where((t) => t.id.equals(id))).watchSingleOrNull();
}
```

**修改 2：使用 StreamBuilder**
```dart
// lib/features/message/message_detail_page.dart

// 之前：
body: FutureBuilder<Message?>(
  future: db.messageDao.getMessage(messageId),
  builder: (context, snapshot) {
    // ...
  },
)

// 之后：
body: StreamBuilder<Message?>(
  stream: db.messageDao.watchMessage(messageId),
  builder: (context, snapshot) {
    // ...
  },
)
```

**修复效果：**
- 标记未读/已读后，UI 立即更新
- 切换星标后，星标图标立即变化
- 所有数据库变更都会实时反映到 UI

**文件：**
- `lib/data/local/database/daos/message_dao.dart:52-55`
- `lib/features/message/message_detail_page.dart:209-211`

---

### 3. 文件夹同步不完整 ✅

**问题描述：**
- 只能看到收件箱文件夹
- 其他文件夹（已发送、草稿箱等）没有同步

**原因分析：**
- 同步服务只同步 `inbox` 和 `sent` 类型的文件夹
- 草稿箱等其他重要文件夹被忽略

**原始代码：**
```dart
// lib/data/sync/sync_service.dart:138-141

// 3. 同步文件夹邮件（仅 inbox 和 sent）
if (folder.type == FolderType.inbox || folder.type == FolderType.sent) {
  await syncFolder(account, existing!);
}
```

**修复后：**
```dart
// 3. 同步文件夹邮件（inbox、sent、drafts）
if (folder.type == FolderType.inbox ||
    folder.type == FolderType.sent ||
    folder.type == FolderType.drafts) {
  await syncFolder(account, existing!);
}
```

**修复效果：**
- 现在会同步收件箱、已发送、草稿箱三个文件夹
- 用户可以看到更多文件夹
- 可以根据需要继续添加其他文件夹类型

**文件：** `lib/data/sync/sync_service.dart:138-143`

---

## 关于"收件箱包含发出的邮件"问题

**问题描述：**
- 用户报告收件箱中包含发出的邮件

**可能原因：**
1. **文件夹类型识别错误**：
   - IMAP 服务器的"已发送"文件夹没有被正确识别为 `sent` 类型
   - 被错误地识别为 `inbox` 或 `custom` 类型

2. **邮件过滤逻辑问题**：
   - 统一收件箱只显示 `FolderType.inbox` 类型的文件夹
   - 如果"已发送"文件夹被错误识别为 `inbox`，就会出现在统一收件箱中

**诊断方法：**
```dart
// 在同步时打印文件夹信息
for (final folder in folders) {
  debugPrint('文件夹: ${folder.displayName}, 类型: ${folder.type}, 路径: ${folder.remoteId}');
}
```

**临时解决方案：**
- 检查数据库中的文件夹类型是否正确
- 如果类型错误，需要改进 `_inferFolderType` 方法

**长期解决方案：**
- 增强文件夹类型识别逻辑
- 支持用户手动设置文件夹类型
- 添加文件夹名称模式匹配（如 "Sent", "已发送", "发件箱" 等）

---

## 测试建议

### 1. 测试收件人显示
- 发送包含多个收件人的邮件
- 检查收件人列表是否正确显示
- 测试包含特殊字符的姓名（引号、换行符等）

### 2. 测试状态更新
- 打开邮件详情页
- 标记为未读，观察 UI 是否立即更新
- 切换星标，观察星标图标是否立即变化
- 返回列表页，检查状态是否一致

### 3. 测试文件夹同步
- 删除本地数据库
- 重新同步账户
- 检查是否能看到收件箱、已发送、草稿箱
- 检查每个文件夹中的邮件是否正确

### 4. 测试统一收件箱
- 添加多个账户
- 检查统一收件箱是否只显示收件箱的邮件
- 确认不包含已发送的邮件

---

## 后续改进建议

### 1. 收件人处理
- 考虑使用 `dart:convert` 的 `jsonEncode` 而不是手动拼接
- 添加更完善的错误处理

### 2. 状态同步
- 实现与服务器的双向同步
- 标记已读后同步到 IMAP 服务器
- 处理离线状态下的操作队列

### 3. 文件夹管理
- 添加文件夹类型的手动设置功能
- 支持自定义文件夹图标
- 实现文件夹排序和隐藏

### 4. 性能优化
- 使用索引优化数据库查询
- 实现邮件列表的虚拟滚动
- 添加图片缓存机制

---

## 相关文件

### 修改的文件
1. `lib/data/sync/sync_service.dart` - 收件人编码和文件夹同步
2. `lib/data/local/database/daos/message_dao.dart` - 添加 watchMessage
3. `lib/features/message/message_detail_page.dart` - 使用 StreamBuilder

### 相关文件
1. `lib/domain/models/mail_recipient.dart` - 收件人模型和解析
2. `lib/data/backends/imap/imap_mail_backend.dart` - IMAP 文件夹类型识别
3. `lib/features/message/widgets/recipient_section.dart` - 收件人 UI 组件

---

## 总结

本次修复解决了三个关键问题：

1. ✅ **收件人 JSON 解析** - 修复了 JSON 格式错误和特殊字符转义
2. ✅ **状态更新延迟** - 使用 StreamBuilder 实现实时更新
3. ✅ **文件夹同步不完整** - 增加了草稿箱的同步

这些修复提升了应用的稳定性和用户体验。建议进行完整的回归测试以确保所有功能正常工作。
