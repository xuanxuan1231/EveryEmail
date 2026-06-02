# Gmail 风格邮件列表

## 📧 实现的特性

### 1. ✅ 紧凑的布局
- **单行显示主题和预览**：主题（粗体）+ " — " + 预览（灰色），完全模仿 Gmail
- **垂直间距优化**：每个邮件项高度约 72-80px，与 Gmail 一致
- **无边框分隔**：使用背景色区分未读邮件，而不是边框线

### 2. ✅ 未读邮件指示
- **蓝色圆点**：未读邮件左侧显示蓝色圆点（8x8px）
- **背景色**：未读邮件有浅色背景（`surfaceContainerHighest`）
- **字体加粗**：未读邮件的发件人和主题使用更粗的字体（`FontWeight.w600` 和 `FontWeight.w500`）

### 3. ✅ 发件人头像
- **彩色圆形头像**：40x40px 圆形头像
- **首字母显示**：显示发件人名称或邮箱的首字母
- **颜色生成**：根据邮箱地址生成一致的颜色（12 种预设颜色）
- **账户颜色**：统一收件箱中使用账户配色

### 4. ✅ 时间显示（Gmail 风格）
- **今天**：显示时间（如 "14:30"）
- **昨天**：显示 "昨天"
- **一周内**：显示星期（如 "周一"、"周二"）
- **今年**：显示月日（如 "3月15日"）
- **往年**：显示年月日（如 "2023/3/15"）

### 5. ✅ 图标指示器
- **星标图标**：右侧显示星标图标（已加星显示实心黄色星星）
- **附件图标**：有附件时显示回形针图标（16x16px）
- **可点击星标**：点击星标图标可切换星标状态（待实现后端逻辑）

### 6. ✅ 账户标签
- **统一收件箱**：显示邮件所属账户的邮箱地址
- **彩色标签**：使用账户配色的浅色背景
- **小字体**：10px 字体，紧凑显示
- **单账户视图**：不显示账户标签

### 7. ✅ 选择模式（UI 已准备）
- **长按触发**：长按邮件项进入选择模式
- **复选框替换头像**：选中时显示蓝色勾选图标
- **选中背景**：选中项显示主题色背景
- **批量操作**：为后续批量删除、归档等操作做准备

## 🎨 视觉细节

### 颜色方案
```dart
// 未读邮件背景
theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)

// 选中背景
theme.colorScheme.primaryContainer.withValues(alpha: 0.3)

// 未读指示器
theme.colorScheme.primary (蓝色圆点)

// 星标颜色
Colors.amber.shade700 (已加星)
theme.colorScheme.onSurfaceVariant (未加星)

// 账户标签背景
accountColor.withValues(alpha: 0.15)
```

### 字体样式
```dart
// 发件人（未读）
bodyMedium + FontWeight.w600

// 发件人（已读）
bodyMedium + FontWeight.normal

// 主题（未读）
bodySmall + FontWeight.w500

// 主题（已读）
bodySmall + FontWeight.normal

// 预览
bodySmall + onSurfaceVariant

// 时间
labelSmall + onSurfaceVariant
```

### 间距
```dart
// 水平内边距：16px
// 垂直内边距：8px
// 头像右边距：12px
// 未读圆点右边距：8px
// 发件人和时间间距：8px
// 行间距：2px
```

## 📱 组件使用

### GmailMessageItem 参数

```dart
GmailMessageItem(
  message: message,              // 必需：邮件数据
  onTap: () => {},              // 必需：点击回调
  accountEmail: 'user@gmail.com', // 可选：账户邮箱（用于标签）
  accountColor: Colors.blue,     // 可选：账户颜色
  showAccountLabel: true,        // 可选：是否显示账户标签
  isSelected: false,             // 可选：是否选中
  onLongPress: () => {},         // 可选：长按回调
  onStarTap: () => {},          // 可选：星标点击回调
)
```

### 在统一收件箱中使用

```dart
GmailMessageItem(
  message: message,
  onTap: () => onMessageTap(message.id),
  accountEmail: item.accountEmail,
  accountColor: Color(item.accountColorValue!),
  showAccountLabel: true,  // 显示账户标签
  onStarTap: () {
    // 切换星标
  },
  onLongPress: () {
    // 进入选择模式
  },
)
```

### 在单账户视图中使用

```dart
GmailMessageItem(
  message: message,
  onTap: () => onMessageTap(message.id),
  showAccountLabel: false,  // 不显示账户标签
  onStarTap: () {
    // 切换星标
  },
  onLongPress: () {
    // 进入选择模式
  },
)
```

## 🔄 与 Gmail 的对比

### ✅ 已实现的 Gmail 特性
- [x] 紧凑的单行布局（主题 + 预览）
- [x] 未读蓝色圆点
- [x] 未读背景色
- [x] 彩色头像（首字母）
- [x] 智能时间显示
- [x] 星标图标
- [x] 附件图标
- [x] 选择模式 UI

### 🚧 待实现的功能
- [ ] 星标切换后端逻辑
- [ ] 选择模式状态管理
- [ ] 批量操作（删除、归档、标记已读）
- [ ] 滑动操作（左滑归档、右滑删除）
- [ ] 邮件分类标签（重要、社交、促销等）
- [ ] 线程折叠（同一主题的多封邮件）
- [ ] 搜索高亮

### 📐 布局差异
Gmail 使用更紧凑的间距，我们的实现稍微宽松一些以适应 Material 3 设计规范。

## 🎯 下一步优化

### 1. 实现星标功能
```dart
// 在 home_page.dart 中
onStarTap: () async {
  final syncService = ref.read(syncServiceProvider);
  final isFlagged = (message.flagsBitmask & (1 << MessageFlag.flagged.index)) != 0;
  
  // 调用后端切换星标
  await syncService.toggleFlag(message, !isFlagged);
}
```

### 2. 实现选择模式
```dart
// 添加状态管理
final selectedMessages = useState<Set<String>>({});

// 长按进入选择模式
onLongPress: () {
  selectedMessages.value = {message.id};
}

// 点击切换选择
onTap: () {
  if (selectedMessages.value.isNotEmpty) {
    // 选择模式：切换选中状态
    if (selectedMessages.value.contains(message.id)) {
      selectedMessages.value.remove(message.id);
    } else {
      selectedMessages.value.add(message.id);
    }
  } else {
    // 正常模式：打开邮件
    onMessageTap(message.id);
  }
}
```

### 3. 添加滑动操作
```dart
Dismissible(
  key: Key(message.id),
  background: Container(
    color: Colors.green,
    alignment: Alignment.centerLeft,
    padding: EdgeInsets.only(left: 20),
    child: Icon(Icons.archive, color: Colors.white),
  ),
  secondaryBackground: Container(
    color: Colors.red,
    alignment: Alignment.centerRight,
    padding: EdgeInsets.only(right: 20),
    child: Icon(Icons.delete, color: Colors.white),
  ),
  onDismissed: (direction) {
    if (direction == DismissDirection.startToEnd) {
      // 归档
    } else {
      // 删除
    }
  },
  child: GmailMessageItem(...),
)
```

## 🐛 已知问题

无已知问题。代码已通过 Flutter 分析。

## 📊 性能考虑

- **ListView.builder**：使用懒加载，只渲染可见项
- **const 构造函数**：尽可能使用 const 减少重建
- **颜色缓存**：根据邮箱地址生成的颜色是确定性的，无需缓存
- **简单布局**：避免复杂的嵌套和计算

## 🎨 自定义

### 修改颜色
在 `gmail_message_item.dart` 中修改 `_generateColorFromEmail` 方法的颜色列表。

### 修改间距
调整 `Container` 的 `padding` 参数。

### 修改字体
调整 `TextStyle` 的 `fontWeight` 和 `fontSize` 参数。

## ✅ 验证清单

- [x] 未读邮件显示蓝色圆点
- [x] 未读邮件背景色不同
- [x] 未读邮件字体加粗
- [x] 主题和预览在同一行
- [x] 时间显示格式正确
- [x] 星标图标显示正确
- [x] 附件图标显示正确
- [x] 头像颜色一致
- [x] 账户标签显示正确
- [x] 选择模式 UI 正确
- [x] 代码通过 Flutter 分析
