# 侧栏账户下拉列表优化

## 🎨 优化内容

### 问题
侧栏的账户文件夹下拉列表（ExpansionTile）有黑色边框，视觉效果不佳。

### 解决方案
通过 `Theme` 包裹 `ExpansionTile`，自定义样式去除边框并优化交互效果。

---

## ✅ 实现的优化

### 1. 去除黑色边框
```dart
Theme(
  data: Theme.of(context).copyWith(
    dividerColor: Colors.transparent,  // 去除分隔线
  ),
  child: ExpansionTile(
    shape: const Border(),  // 去除展开时的边框
    collapsedShape: const Border(),  // 去除折叠时的边框
    ...
  ),
)
```

### 2. 优化交互效果
```dart
Theme(
  data: Theme.of(context).copyWith(
    splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),  // 点击水波纹
    highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),  // 高亮颜色
  ),
  ...
)
```

### 3. 改善选中状态
```dart
ExpansionTile(
  backgroundColor: isAccountSelected
      ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
      : null,
  collapsedBackgroundColor: isAccountSelected
      ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
      : null,
  ...
)
```

### 4. 优化标题样式
```dart
title: Text(
  account.displayName,
  style: TextStyle(
    fontWeight: isAccountSelected ? FontWeight.w600 : FontWeight.normal,
  ),
),
```

### 5. 优化子项样式
```dart
ListTile(
  selectedTileColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
  shape: const Border(),  // 去除边框
  contentPadding: const EdgeInsets.only(left: 56, right: 16),  // 缩进对齐
  ...
)
```

### 6. 调整内边距
```dart
ExpansionTile(
  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  childrenPadding: EdgeInsets.zero,  // 子项无额外内边距
  ...
)
```

---

## 🎯 优化效果

### 优化前 ❌
- 黑色边框明显
- 展开/折叠时有黑色分隔线
- 选中状态不明显
- 交互反馈不够柔和

### 优化后 ✅
- 无边框，视觉干净
- 无分隔线，流畅过渡
- 选中状态清晰（浅色背景 + 粗体文字）
- 点击有柔和的水波纹效果
- 子项缩进对齐，层级清晰

---

## 📐 样式规格

### 颜色
```dart
// 选中背景（展开/折叠）
secondaryContainer (alpha: 0.3)

// 子项选中背景
secondaryContainer (alpha: 0.2)

// 点击水波纹
primary (alpha: 0.1)

// 高亮颜色
primary (alpha: 0.05)
```

### 内边距
```dart
// ExpansionTile 内边距
horizontal: 16px, vertical: 4px

// 子项内边距
left: 56px (对齐头像后), right: 16px
```

### 字体
```dart
// 账户名称
选中：FontWeight.w600
未选中：FontWeight.normal
```

---

## 🔧 代码实现

### 完整代码
```dart
Theme(
  data: Theme.of(context).copyWith(
    dividerColor: Colors.transparent,
    splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
    highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
  ),
  child: ExpansionTile(
    leading: CircleAvatar(...),
    title: Text(
      account.displayName,
      style: TextStyle(
        fontWeight: isAccountSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    ),
    subtitle: Text(account.email),
    backgroundColor: isAccountSelected
        ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
        : null,
    collapsedBackgroundColor: isAccountSelected
        ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
        : null,
    shape: const Border(),
    collapsedShape: const Border(),
    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    childrenPadding: EdgeInsets.zero,
    children: [
      ListTile(
        leading: const SizedBox(width: 16),
        title: const Text('收件箱'),
        dense: true,
        selected: isAccountSelected,
        selectedTileColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
        shape: const Border(),
        contentPadding: const EdgeInsets.only(left: 56, right: 16),
        onTap: () { ... },
      ),
    ],
  ),
)
```

---

## ✅ 验证清单

### 视觉验证
- [x] 无黑色边框
- [x] 无黑色分隔线
- [x] 选中状态清晰
- [x] 展开/折叠流畅
- [x] 子项缩进对齐

### 交互验证
- [x] 点击有水波纹效果
- [x] 高亮颜色柔和
- [x] 选中背景明显
- [x] 字体粗细变化

### 代码质量
- [x] 通过 Flutter 静态分析
- [x] 无错误、无警告

---

## 🎨 Material Design 最佳实践

### 1. 去除不必要的边框
Material 3 设计强调简洁，避免过多的边框和分隔线。

### 2. 使用透明度表示状态
通过不同的透明度（alpha）表示不同的交互状态：
- 选中：alpha: 0.3
- 子项选中：alpha: 0.2
- 水波纹：alpha: 0.1
- 高亮：alpha: 0.05

### 3. 使用字重表示重要性
选中的项目使用粗体（FontWeight.w600），未选中使用正常字重。

### 4. 保持视觉层级
通过缩进（left: 56px）保持子项与父项的视觉层级关系。

---

## 📊 对比效果

| 特性 | 优化前 ❌ | 优化后 ✅ |
|------|---------|---------|
| 边框 | 黑色边框 | 无边框 |
| 分隔线 | 黑色分隔线 | 无分隔线 |
| 选中状态 | 不明显 | 浅色背景 + 粗体 |
| 水波纹 | 默认 | 柔和的主题色 |
| 子项对齐 | 默认 | 缩进对齐 |
| 视觉效果 | 生硬 | 柔和流畅 |

---

## 🚀 使用效果

### 侧栏账户列表
```
┌─────────────────────────────┐
│ ☰  EveryEmail               │
│    2 个账户                  │
├─────────────────────────────┤
│ 📥 统一收件箱                │
├─────────────────────────────┤
│                             │
│ [A] Account 1               │  ← 无边框
│     user1@example.com       │
│   ▼                         │
│     📥 收件箱                │  ← 缩进对齐
│                             │
│ [B] Account 2 (选中)        │  ← 浅色背景 + 粗体
│     user2@example.com       │
│   ▼                         │
│     📥 收件箱                │  ← 选中背景
│                             │
├─────────────────────────────┤
│ ➕ 添加账户                  │
│ ⚙️ 设置                     │
└─────────────────────────────┘
```

---

## 🎉 总结

通过以下优化，侧栏账户下拉列表的视觉效果大幅提升：

1. ✅ 去除黑色边框和分隔线
2. ✅ 优化选中状态显示
3. ✅ 改善交互反馈效果
4. ✅ 调整内边距和对齐
5. ✅ 符合 Material 3 设计规范

**视觉效果更加干净、流畅、现代！** ✨
