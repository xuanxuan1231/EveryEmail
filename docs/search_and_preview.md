# 邮件搜索和预览功能实现文档

## ✅ 已完成的功能

### 1. 邮件搜索功能

#### 数据库搜索方法
在 `MessageDao` 中添加了两个搜索方法：

**全局搜索**（所有账户）：
```dart
Future<List<MessageWithAccount>> searchMessages(String query, {int limit = 50})
```
- 搜索范围：主题、发件人名称、发件人邮箱、预览内容
- 返回结果：包含账户信息的邮件列表
- 排序：按日期倒序
- 限制：默认 50 条

**账户搜索**（特定账户）：
```dart
Future<List<Message>> searchAccountMessages(String accountId, String query, {int limit = 50})
```
- 搜索范围：同上
- 返回结果：特定账户的邮件列表

#### 搜索页面 UI
创建了 `SearchPage`（`lib/features/search/search_page.dart`）：

**功能特点**：
- ✅ 实时搜索（500ms 防抖）
- ✅ 搜索框自动聚焦
- ✅ 清除按钮
- ✅ 搜索结果计数
- ✅ 空状态提示
- ✅ 无结果提示
- ✅ 使用 Gmail 风格邮件列表项显示结果

**UI 状态**：
1. **未搜索**：显示搜索图标和提示文字
2. **搜索中**：显示加载指示器
3. **有结果**：显示结果列表和计数
4. **无结果**：显示无结果提示

---

### 2. 邮件预览功能

#### 邮件详情页面增强
完善了 `MessageDetailPage`（`lib/features/message/message_detail_page.dart`）：

**新增功能**：
- ✅ HTML 邮件渲染（使用 `flutter_widget_from_html_core`）
- ✅ 纯文本邮件显示（可选择复制）
- ✅ 标记为未读功能
- ✅ 星标切换功能
- ✅ 改进的 UI 布局

**页面结构**：
```
┌─────────────────────────────────────┐
│ [返回] 邮件详情    [回复][转发][菜单] │
├─────────────────────────────────────┤
│ 主题（大标题）                        │
│                                     │
│ [头像] 发件人名称              时间   │
│        发件人邮箱                    │
│                                     │
│ ▼ 收件人（可展开）                   │
│                                     │
│ ─────────────────────────────────  │
│                                     │
│ 邮件正文（HTML 渲染或纯文本）         │
│                                     │
│ ─────────────────────────────────  │
│                                     │
│ 📎 附件                              │
│ [附件列表]                           │
└─────────────────────────────────────┘
```

**操作菜单**：
- 删除（待实现后端）
- 标记为未读 ✅
- 加星标/取消星标 ✅
- 移动到...（待实现）

**HTML 渲染**：
- 使用 `HtmlWidget` 渲染 HTML 邮件
- 支持链接点击（待实现打开浏览器）
- 自动适配主题样式
- 带边框的容器包裹

---

## 📐 技术实现

### 1. 数据库搜索查询

```dart
// 使用 LIKE 进行模糊搜索
final searchPattern = '%${query.toLowerCase()}%';

// 多字段搜索（OR 条件）
..where(
  messages.subject.lower().like(searchPattern) |
  messages.fromName.lower().like(searchPattern) |
  messages.fromEmail.lower().like(searchPattern) |
  messages.preview.lower().like(searchPattern),
)
```

### 2. 搜索防抖

```dart
onChanged: (value) {
  // 500ms 防抖，避免频繁查询
  Future.delayed(const Duration(milliseconds: 500), () {
    if (_searchController.text == value) {
      _performSearch(value);
    }
  });
},
```

### 3. HTML 渲染

```dart
HtmlWidget(
  body.htmlBody!,
  textStyle: theme.textTheme.bodyMedium,
  onTapUrl: (url) {
    // 处理链接点击
    debugPrint('打开链接: $url');
    return true;
  },
)
```

### 4. 标志位操作

```dart
// 标记为未读（清除 seen 标志）
final newFlags = message.flagsBitmask & ~(1 << MessageFlag.seen.index);

// 切换星标
final isFlagged = (message.flagsBitmask & (1 << MessageFlag.flagged.index)) != 0;
final newFlags = isFlagged
    ? message.flagsBitmask & ~(1 << MessageFlag.flagged.index)  // 取消
    : message.flagsBitmask | (1 << MessageFlag.flagged.index);   // 添加
```

---

## 🎨 UI 设计

### 搜索页面

**AppBar**：
- 搜索框占据整个标题区域
- 自动聚焦
- 清除按钮（有内容时显示）

**空状态**：
```
        🔍
    搜索邮件
按主题、发件人或内容搜索
```

**无结果**：
```
        🔍❌
    未找到结果
  尝试使用不同的关键词
```

**结果列表**：
```
找到 X 封邮件

[邮件列表项 1]
[邮件列表项 2]
[邮件列表项 3]
...
```

### 邮件详情页面

**AppBar 操作**：
- 回复按钮
- 转发按钮
- 更多菜单（删除、标记未读、星标、移动）

**正文显示**：
- HTML：带边框的白色容器，完整渲染
- 纯文本：浅色背景容器，可选择复制
- 无正文：灰色斜体提示

---

## 📦 新增依赖

```yaml
dependencies:
  flutter_widget_from_html_core: ^0.15.2
```

用于渲染 HTML 邮件内容。

---

## 🔧 路由配置

### 搜索页面路由
```dart
GoRoute(
  path: '/search',
  builder: (context, state) => const SearchPage(),
)
```

### 使用方式
```dart
// 从主页跳转到搜索
context.push('/search');

// 从搜索结果跳转到详情
context.push('/message/${message.id}');
```

---

## ✅ 功能清单

### 搜索功能
- [x] 数据库搜索方法
- [x] 搜索页面 UI
- [x] 实时搜索（防抖）
- [x] 搜索结果显示
- [x] 空状态和无结果提示
- [x] 结果计数
- [x] 清除搜索
- [x] 路由集成
- [ ] 搜索历史（待实现）
- [ ] 搜索建议（待实现）
- [ ] 高级搜索（按日期、发件人筛选）

### 预览功能
- [x] 邮件详情页面
- [x] HTML 邮件渲染
- [x] 纯文本邮件显示
- [x] 发件人信息显示
- [x] 时间格式化
- [x] 标记为未读
- [x] 星标切换
- [x] 操作菜单
- [x] 附件指示
- [ ] 附件列表显示（待实现）
- [ ] 附件下载（待实现）
- [ ] 收件人列表解析（待实现）
- [ ] 回复功能（待实现）
- [ ] 转发功能（待实现）
- [ ] 删除功能（待实现后端）
- [ ] 移动功能（待实现后端）

---

## 🎯 使用示例

### 搜索邮件

1. 点击主页 AppBar 的搜索图标
2. 输入搜索关键词
3. 查看实时搜索结果
4. 点击邮件项查看详情

### 查看邮件详情

1. 从邮件列表点击邮件项
2. 查看完整邮件内容
3. 使用操作按钮：
   - 点击星标图标切换星标
   - 点击菜单选择"标记为未读"
   - 点击回复/转发（待实现）

---

## 📊 性能优化

### 搜索优化
- **防抖**：500ms 延迟，避免频繁查询
- **限制结果**：默认 50 条，避免加载过多数据
- **索引**：数据库字段建议添加索引（待优化）

### 渲染优化
- **懒加载**：邮件正文按需加载
- **HTML 渲染**：使用高效的 `flutter_widget_from_html_core`
- **列表复用**：使用 `ListView.builder`

---

## 🐛 已知问题

1. **搜索历史**：未实现搜索历史记录
2. **附件显示**：附件列表需要解析 JSON 并显示
3. **收件人列表**：需要解析 JSON 并显示
4. **链接打开**：HTML 中的链接点击需要集成 `url_launcher`
5. **图片显示**：HTML 中的图片可能需要特殊处理

---

## 🚀 下一步改进

### 优先级 1
1. **附件功能**
   - 解析附件元数据 JSON
   - 显示附件列表（文件名、大小、类型）
   - 实现附件下载

2. **链接处理**
   - 集成 `url_launcher`
   - 安全地打开外部链接
   - 显示链接预览

3. **收件人显示**
   - 解析收件人 JSON
   - 显示收件人列表
   - 支持展开/折叠

### 优先级 2
1. **搜索增强**
   - 搜索历史记录
   - 搜索建议
   - 高级筛选（日期、文件夹、标志）

2. **邮件操作**
   - 回复功能
   - 转发功能
   - 删除功能（连接后端）
   - 移动功能（连接后端）

### 优先级 3
1. **用户体验**
   - 搜索结果高亮关键词
   - 邮件详情页滑动切换
   - 快速操作手势
   - 离线缓存

---

## 📝 代码质量

```bash
flutter analyze lib/features/search/
flutter analyze lib/features/message/
flutter analyze lib/data/local/database/daos/message_dao.dart
```

所有新增和修改的文件都通过了 Flutter 静态分析。

---

## 🎉 总结

### 已实现
- ✅ 完整的邮件搜索功能（UI + 数据库查询）
- ✅ 增强的邮件详情页面（HTML 渲染 + 操作）
- ✅ 标记未读和星标功能
- ✅ 路由集成
- ✅ 代码质量保证

### 待完善
- 附件功能
- 回复/转发功能
- 搜索历史
- 高级筛选

**核心功能已完成，可以正常使用！** ✨
