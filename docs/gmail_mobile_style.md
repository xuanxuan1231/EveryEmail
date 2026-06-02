# Gmail 移动 App 风格邮件列表

## 📱 真实的 Gmail 移动 App 特点

基于 **Android/iOS Gmail App** 的实际设计，而非网页版。

## 🎨 核心视觉特征

### 1. ✅ 大头像（56x56px）
- **尺寸**：56x56px 圆形头像（比网页版的 40px 大）
- **位置**：左侧，与内容有 16px 间距
- **内容**：显示发件人名称或邮箱的首字母
- **颜色**：使用 Gmail 风格的柔和色调（15 种预设颜色）

```dart
Container(
  width: 56,
  height: 56,
  decoration: BoxDecoration(
    color: color,
    shape: BoxShape.circle,
  ),
  child: Text(initial, style: TextStyle(fontSize: 24)),
)
```

### 2. ✅ 未读指示器（左侧蓝色竖条）
- **样式**：4px 宽的蓝色竖条，而不是圆点
- **位置**：邮件项最左侧
- **高度**：与邮件项同高（约 88px）
- **颜色**：`theme.colorScheme.primary`（蓝色）

```dart
Container(
  width: 4,
  height: 88,
  color: isRead ? Colors.transparent : theme.colorScheme.primary,
)
```

### 3. ✅ 三行布局结构

#### 第一行：发件人 + 时间
- **发件人**：
  - 字体大小：14sp
  - 未读：`FontWeight.w700`（粗体）
  - 已读：`FontWeight.w500`（中等）
  - 颜色：`onSurface`
  - 单行显示，超出省略

- **时间**：
  - 字体大小：12sp
  - 未读：`FontWeight.w500`
  - 已读：`FontWeight.normal`
  - 颜色：`onSurfaceVariant`
  - 位置：右上角

#### 第二行：主题 + 附件图标
- **主题**：
  - 字体大小：14sp
  - 未读：`FontWeight.w600`
  - 已读：`FontWeight.normal`
  - 颜色：`onSurface`
  - 单行显示，超出省略

- **附件图标**：
  - 大小：16x16px
  - 图标：`Icons.attach_file`
  - 颜色：`onSurfaceVariant`

#### 第三行：预览 + 星标
- **预览**：
  - 字体大小：13sp
  - 字重：`FontWeight.normal`
  - 颜色：`onSurfaceVariant`
  - 单行显示，超出省略

- **星标**：
  - 大小：22x22px
  - 已加星：实心星星 `Icons.star`，颜色 `#F9AB00`（Gmail 黄色）
  - 未加星：空心星星 `Icons.star_border_outlined`，颜色 `onSurfaceVariant`（半透明）
  - 位置：右下角
  - 可点击区域：带 padding 的 InkWell

### 4. ✅ 时间格式（中文本地化）
- **今天**：`上午10:30` 或 `下午2:45`（12 小时制）
- **昨天**：`昨天`
- **一周内**：`周一`、`周二`、`周三` 等
- **今年**：`3月15日`
- **往年**：`2023年`

```dart
String _formatDate(DateTime date) {
  final diff = today.difference(messageDate).inDays;
  
  if (diff == 0) {
    // 今天：上午/下午 + 时间
    final period = hour >= 12 ? '下午' : '上午';
    final displayHour = hour > 12 ? hour - 12 : hour;
    return '$period$displayHour:$minute';
  } else if (diff == 1) {
    return '昨天';
  } else if (diff < 7) {
    return weekdays[date.weekday - 1]; // 周一-周日
  } else if (date.year == now.year) {
    return '${date.month}月${date.day}日';
  } else {
    return '${date.year}年';
  }
}
```

### 5. ✅ 账户标签（统一收件箱）
- **样式**：带边框的胶囊形状（不是填充背景）
- **高度**：18px
- **边框**：1px，使用账户颜色
- **文字**：11sp，账户颜色，`FontWeight.w500`
- **圆角**：9px（半圆形）
- **内边距**：水平 8px

```dart
Container(
  height: 18,
  padding: EdgeInsets.symmetric(horizontal: 8),
  decoration: BoxDecoration(
    border: Border.all(color: accountColor, width: 1),
    borderRadius: BorderRadius.circular(9),
  ),
  child: Text(accountEmail, style: TextStyle(fontSize: 11)),
)
```

### 6. ✅ 间距和尺寸
- **邮件项高度**：约 88-96px（取决于是否有账户标签）
- **水平内边距**：左 12px（头像后），右 16px
- **垂直内边距**：上下各 16px
- **头像右边距**：16px
- **行间距**：4px（发件人到主题）、2px（主题到预览）、6px（预览到标签）
- **底部分隔线**：1px，`outlineVariant`（半透明）

### 7. ✅ 选择模式
- **触发**：长按邮件项
- **头像替换**：显示蓝色圆形复选框（56x56px）
- **复选框图标**：白色对勾，28x28px
- **背景色**：`primaryContainer`（alpha: 0.2）

### 8. ✅ 颜色方案（Gmail 风格）

#### 头像颜色（15 种柔和色调）
```dart
const colors = [
  Color(0xFFE57373), // 红色
  Color(0xFFF06292), // 粉色
  Color(0xFFBA68C8), // 紫色
  Color(0xFF9575CD), // 深紫色
  Color(0xFF7986CB), // 靛蓝
  Color(0xFF64B5F6), // 蓝色
  Color(0xFF4FC3F7), // 浅蓝
  Color(0xFF4DD0E1), // 青色
  Color(0xFF4DB6AC), // 蓝绿
  Color(0xFF81C784), // 绿色
  Color(0xFFAED581), // 浅绿
  Color(0xFFFFB74D), // 橙色
  Color(0xFFFF8A65), // 深橙
  Color(0xFFA1887F), // 棕色
  Color(0xFF90A4AE), // 蓝灰
];
```

#### 星标颜色
- 已加星：`Color(0xFFF9AB00)` - Gmail 官方黄色
- 未加星：`onSurfaceVariant` (alpha: 0.6)

## 📐 布局结构

```
┌─────────────────────────────────────────────────────┐
│ [蓝条] [头像]  发件人名称                    上午10:30 │
│   4px   56px   14sp, bold              12sp, gray  │
│                                                     │
│              主题文本                          [📎] │
│              14sp, medium                     16px │
│                                                     │
│              预览文本...                        [⭐] │
│              13sp, gray                       22px │
│                                                     │
│              [账户标签]                             │
│              11sp, bordered                        │
├─────────────────────────────────────────────────────┤
```

## 🎯 与网页版的区别

| 特性 | 移动 App | 网页版 |
|------|---------|--------|
| 头像大小 | 56x56px | 40x40px |
| 未读指示 | 左侧蓝色竖条（4px） | 蓝色圆点（8px） |
| 布局 | 三行（发件人/主题/预览） | 两行（发件人+时间/主题+预览） |
| 主题和预览 | 分开两行 | 同一行（主题 — 预览） |
| 星标位置 | 右下角（与预览同行） | 右侧（与主题同行） |
| 邮件项高度 | 88-96px | 72-80px |
| 时间格式 | 上午/下午 + 12小时制 | 24小时制 |
| 账户标签 | 带边框胶囊 | 填充背景 |

## 🔄 组件使用

### GmailMobileMessageItem 参数

```dart
GmailMobileMessageItem(
  message: message,              // 必需：邮件数据
  onTap: () => {},              // 必需：点击回调
  accountEmail: 'user@gmail.com', // 可选：账户邮箱
  accountColor: Colors.blue,     // 可选：账户颜色
  showAccountLabel: true,        // 可选：是否显示账户标签
  isSelected: false,             // 可选：是否选中
  onLongPress: () => {},         // 可选：长按回调
  onStarTap: () => {},          // 可选：星标点击回调
)
```

### 在统一收件箱中使用

```dart
GmailMobileMessageItem(
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
GmailMobileMessageItem(
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

## ✅ 实现的细节

### 1. 字体大小精确匹配
- 发件人：14sp
- 主题：14sp
- 预览：13sp
- 时间：12sp
- 账户标签：11sp

### 2. 字重精确匹配
- 未读发件人：`FontWeight.w700`（粗体）
- 已读发件人：`FontWeight.w500`（中等）
- 未读主题：`FontWeight.w600`
- 已读主题：`FontWeight.normal`
- 预览：`FontWeight.normal`

### 3. 颜色精确匹配
- 星标黄色：`#F9AB00`（Gmail 官方色）
- 头像颜色：15 种 Material Design 柔和色调
- 未读竖条：主题色（蓝色）

### 4. 间距精确匹配
- 邮件项内边距：12px（左）、16px（右）、16px（上下）
- 头像大小：56x56px
- 头像右边距：16px
- 未读竖条宽度：4px

## 🎨 视觉效果

### 未读邮件
- ✅ 左侧蓝色竖条（4px 宽）
- ✅ 发件人粗体（FontWeight.w700）
- ✅ 主题中等粗体（FontWeight.w600）
- ✅ 时间中等粗体（FontWeight.w500）
- ❌ 无背景色（与 Gmail 一致）

### 已读邮件
- ✅ 无左侧竖条
- ✅ 发件人中等字重（FontWeight.w500）
- ✅ 主题正常字重（FontWeight.normal）
- ✅ 时间正常字重（FontWeight.normal）

### 选中邮件
- ✅ 浅色背景（primaryContainer, alpha: 0.2）
- ✅ 头像替换为蓝色圆形复选框
- ✅ 白色对勾图标

## 📱 响应式设计

- **触摸区域**：整个邮件项可点击
- **星标触摸区域**：带 padding 的 InkWell，增大点击区域
- **长按反馈**：进入选择模式
- **水波纹效果**：Material InkWell 提供

## 🐛 已知问题

无已知问题。代码已通过 Flutter 分析。

## 📊 性能优化

- **ListView.builder**：懒加载，只渲染可见项
- **const 构造函数**：尽可能使用 const
- **颜色生成**：确定性算法，无需缓存
- **简单布局**：避免复杂嵌套

## 🎯 下一步

### 待实现的功能
- [ ] 星标切换后端逻辑
- [ ] 选择模式状态管理
- [ ] 批量操作（删除、归档、标记已读）
- [ ] 滑动操作（左滑归档、右滑删除）
- [ ] 邮件分类标签（重要、社交、促销）
- [ ] 线程折叠

## ✅ 验证清单

- [x] 头像大小 56x56px
- [x] 未读邮件左侧蓝色竖条（4px）
- [x] 发件人在最上面（与时间同行）
- [x] 主题单独一行
- [x] 预览单独一行
- [x] 星标在右下角
- [x] 时间格式：上午/下午 + 12小时制
- [x] 账户标签带边框（不是填充）
- [x] 字体大小匹配（14/14/13/12/11sp）
- [x] 字重匹配（w700/w600/w500/normal）
- [x] 星标颜色 #F9AB00
- [x] 邮件项高度约 88-96px
- [x] 选择模式 UI 正确
- [x] 代码通过 Flutter 分析

---

**这才是真正的 Gmail 移动 App 风格！** 📱✨
