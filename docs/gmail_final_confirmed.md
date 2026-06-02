# Gmail 移动 App 风格 - 最终确定版

## ✅ 最终布局确认

根据用户反馈，最终确定的布局为：**三行布局，主题和预览分开显示**

### 布局结构

```
┌─────────────────────────────────────────────────────┐
│ [蓝条] [头像]  发件人名称                    08:47   │
│   4px   56px   14sp, bold              12sp, gray  │
│                                                     │
│              主题文本主题文本主题文本...        [📎] │
│              14sp, 单行，超出省略          18px     │
│                                                     │
│              预览文本预览文本预览文本...        [⭐] │
│              13sp, 单行，超出省略          22px     │
│                                                     │
│              [账户标签]                             │
├─────────────────────────────────────────────────────┤
```

## 🎨 最终实现的特点

### 1. 三行内容布局
- **第一行**：发件人（14sp, 粗体）+ 时间（12sp, 右上角）
- **第二行**：主题（14sp, 单行）+ 附件图标（18px）
- **第三行**：预览（13sp, 单行）+ 星标（22px）

### 2. 单行省略显示
- **主题**：`maxLines: 1`, `overflow: TextOverflow.ellipsis`
- **预览**：`maxLines: 1`, `overflow: TextOverflow.ellipsis`
- 超出部分显示 `...` 省略号

### 3. 核心特征
- ✅ 56x56px 大头像
- ✅ 左侧 4px 蓝色竖条（未读指示）
- ✅ 三行布局（发件人 / 主题 / 预览）
- ✅ 主题和预览分开显示
- ✅ 每行单独显示，超出省略
- ✅ 精确的字体大小和字重
- ✅ Gmail 官方星标颜色（#F9AB00）
- ✅ 12 小时制时间格式
- ✅ 邮件项高度约 80px

## 📐 详细规格

### 字体规格
```dart
发件人：14sp, FontWeight.w700（未读）/ FontWeight.w500（已读）
时间：  12sp, FontWeight.w500（未读）/ FontWeight.normal（已读）
主题：  14sp, FontWeight.w600（未读）/ FontWeight.normal（已读）
预览：  13sp, FontWeight.normal, onSurfaceVariant
标签：  11sp, FontWeight.w500
```

### 尺寸规格
```dart
头像：      56x56px
未读竖条：  4px × 80px
附件图标：  18px
星标图标：  22px
邮件项高度：约 80-88px
```

### 间距规格
```dart
水平内边距：左 12px，右 16px
垂直内边距：上下各 14px
头像右边距：16px
发件人到主题：4px
主题到预览：  2px
预览到标签：  4px
```

### 颜色规格
```dart
未读竖条：  theme.colorScheme.primary
星标黄色：  Color(0xFFF9AB00)
预览文本：  theme.colorScheme.onSurfaceVariant
选中背景：  primaryContainer (alpha: 0.2)
```

## 🔧 代码实现

### 主题行（单独一行）
```dart
Row(
  children: [
    Expanded(
      child: Text(
        message.subject,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        maxLines: 1,  // 单行
        overflow: TextOverflow.ellipsis,  // 超出省略
      ),
    ),
    if (hasAttachments) Icon(attach_file, 18px),
  ],
)
```

### 预览行（单独一行）
```dart
Row(
  children: [
    Expanded(
      child: Text(
        message.preview,
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,  // 单行
        overflow: TextOverflow.ellipsis,  // 超出省略
      ),
    ),
    Icon(star, 22px),
  ],
)
```

## 📊 布局对比

| 特性 | 最终实现 ✅ | 说明 |
|------|-----------|------|
| 布局行数 | 3行 | 发件人 / 主题 / 预览 |
| 主题显示 | 单独一行 | 超出显示 ... |
| 预览显示 | 单独一行 | 超出显示 ... |
| 主题最大行数 | 1行 | maxLines: 1 |
| 预览最大行数 | 1行 | maxLines: 1 |
| 省略方式 | ellipsis | 末尾显示 ... |
| 附件图标位置 | 主题行右侧 | 18px |
| 星标图标位置 | 预览行右侧 | 22px |
| 邮件项高度 | 80-88px | 取决于是否有标签 |

## ✅ 验证清单

### 视觉验证
- [x] 头像大小 56x56px
- [x] 未读邮件左侧蓝色竖条（4px 宽）
- [x] 三行布局（发件人 / 主题 / 预览）
- [x] 主题单独一行
- [x] 预览单独一行
- [x] 主题超出显示省略号
- [x] 预览超出显示省略号
- [x] 发件人在最上面（14sp, 粗体）
- [x] 时间在右上角（12sp）
- [x] 附件图标在主题行右侧（18px）
- [x] 星标在预览行右侧（22px）
- [x] 时间格式：上午/下午 + 12小时制
- [x] 账户标签带边框（18px 高）
- [x] 邮件项高度约 80px
- [x] 底部分隔线 1px

### 功能验证
- [x] 点击邮件项触发回调
- [x] 点击星标触发回调
- [x] 长按触发回调
- [x] 选择模式 UI 显示正确
- [x] 未读/已读状态显示正确
- [x] 星标状态显示正确
- [x] 附件图标显示正确
- [x] 账户标签显示正确
- [x] 主题单行省略正确
- [x] 预览单行省略正确

### 代码质量
- [x] 通过 Flutter 静态分析
- [x] 无错误、无警告
- [x] 代码结构清晰
- [x] 注释完整

## 🎯 关键改进

### 1. 主题和预览分开显示
- **之前**：主题和预览混在一起（RichText）
- **现在**：主题和预览分成两行，各自独立显示

### 2. 单行省略
- **主题**：单行显示，超出部分显示 `...`
- **预览**：单行显示，超出部分显示 `...`
- 使用 `maxLines: 1` 和 `overflow: TextOverflow.ellipsis`

### 3. 调整高度
- **未读竖条**：从 72px 增加到 80px
- **垂直内边距**：从 12px 增加到 14px
- **邮件项总高度**：约 80-88px

## 🚀 使用方法

```dart
GmailMobileMessageItem(
  message: message,
  onTap: () => openMessage(message.id),
  accountEmail: 'user@gmail.com',
  accountColor: Colors.blue,
  showAccountLabel: true,
  onStarTap: () => toggleStar(message.id),
  onLongPress: () => enterSelectionMode(message.id),
)
```

## 📝 修改历史

### 第一版
- ❌ 三行布局，但主题和预览分开

### 第二版
- ❌ 两行布局，主题和预览混在一起

### 第三版（最终版）✅
- ✅ 三行布局，主题和预览分开
- ✅ 每行单独显示，超出省略
- ✅ 符合用户要求

## 🎉 总结

最终实现的布局：
1. **三行内容**：发件人 / 主题 / 预览
2. **主题单行**：超出显示 `...`
3. **预览单行**：超出显示 `...`
4. **清晰分离**：主题和预览各自独立
5. **完整功能**：星标、附件、账户标签

**完全符合用户要求！** ✨
