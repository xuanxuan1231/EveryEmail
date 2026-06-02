# Office 365 自动识别和 OAuth 引导

## 实现完成 ✅

已实现自动识别 Office 365 服务器并引导用户使用 OAuth 登录。

---

## 🎯 功能说明

### 自动识别 Office 365

当用户输入企业邮箱（如 `user@company.com`）时：

1. **自动发现服务器配置**
   - 应用尝试自动发现 IMAP/SMTP 服务器
   - 如果发现的服务器是 Office 365，自动识别

2. **识别 Office 365 服务器**
   - IMAP: `outlook.office365.com`, `imap-mail.outlook.com`
   - SMTP: `smtp.office365.com`, `smtp-mail.outlook.com`

3. **引导 OAuth 登录**
   - 显示提示信息："检测到 Microsoft 365 / Office 365"
   - 显示 OAuth 登录按钮："使用 Microsoft 账号登录"
   - 仍然保留密码登录选项（用于应用专用密码）

---

## 🔧 技术实现

### 1. 服务器识别（DiscoveryService）

**文件：** `lib/data/autoconfig/discovery_service.dart`

**新增代码：**
```dart
/// Office 365 / Exchange Online 的 IMAP/SMTP 服务器。
static const _office365ImapHosts = {
  'outlook.office365.com',
  'imap-mail.outlook.com',
};

static const _office365SmtpHosts = {
  'smtp.office365.com',
  'smtp-mail.outlook.com',
};

/// 结合发现到的 IMAP 主机名细化类型。
AccountType _refineType(AccountType initial, ServerConfig? imap) {
  if (initial != AccountType.genericImap) return initial;
  final host = imap?.host.toLowerCase() ?? '';

  // 检查是否是 Google 服务器
  if (host.contains('imap.gmail.com') || host.endsWith('.googlemail.com')) {
    return AccountType.gmailOAuth;
  }

  // 检查是否是 Office 365 服务器
  if (_isOffice365Server(host)) {
    return AccountType.microsoftGraph;
  }

  return AccountType.genericImap;
}

/// 检查是否是 Office 365 服务器。
bool _isOffice365Server(String host) {
  return _office365ImapHosts.contains(host) ||
      host.contains('outlook.office365.com');
}
```

**工作原理：**
- 在自动发现配置后，检查 IMAP 主机名
- 如果匹配 Office 365 服务器，将账户类型设置为 `microsoftGraph`
- 这样会自动跳转到 OAuth 登录页面

### 2. 密码页面优化（PasswordPage）

**文件：** `lib/features/onboarding/password_page.dart`

**新增代码：**
```dart
/// 检查是否是 Office 365 服务器。
bool get _isOffice365 {
  final imapHost = widget.imap.host.toLowerCase();
  final smtpHost = widget.smtp?.host.toLowerCase() ?? '';

  return imapHost.contains('outlook.office365.com') ||
      imapHost.contains('imap-mail.outlook.com') ||
      smtpHost.contains('smtp.office365.com') ||
      smtpHost.contains('smtp-mail.outlook.com');
}

/// 使用 OAuth 登录（Office 365）。
Future<void> _loginWithOAuth() async {
  // 跳转到 OAuth 登录页面
  context.push(
    '/onboarding/oauth?type=${AccountType.microsoftGraph.name}&email=${Uri.encodeComponent(widget.email)}',
  );
}
```

**UI 改进：**
```dart
// Office 365 检测提示
if (_isOffice365) ...[
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('检测到 Microsoft 365 / Office 365'),
              Text('推荐使用 OAuth 登录，更安全且无需应用专用密码'),
            ],
          ),
        ),
      ],
    ),
  ),
  const SizedBox(height: 24),

  // OAuth 登录按钮
  FilledButton.icon(
    onPressed: _loginWithOAuth,
    icon: const Icon(Icons.login),
    label: const Text('使用 Microsoft 账号登录'),
  ),
  const SizedBox(height: 16),

  // 分隔线
  Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('或使用密码登录'),
      ),
      const Expanded(child: Divider()),
    ],
  ),
],
```

---

## 📱 用户体验流程

### 场景 1：企业邮箱（Office 365）

```
用户输入：user@company.com
    ↓
自动发现服务器配置
    ↓
检测到：outlook.office365.com
    ↓
显示密码页面，但包含：
  - 蓝色提示框："检测到 Microsoft 365 / Office 365"
  - OAuth 登录按钮（推荐）
  - 分隔线："或使用密码登录"
  - 密码输入框（用于应用专用密码）
    ↓
用户点击 OAuth 登录按钮
    ↓
跳转到 Microsoft 登录页面
    ↓
完成 OAuth 认证
    ↓
开始同步邮件
```

### 场景 2：个人邮箱（Outlook.com）

```
用户输入：user@outlook.com
    ↓
域名识别：microsoftGraph
    ↓
直接跳转到 OAuth 登录页面
    ↓
完成 OAuth 认证
    ↓
开始同步邮件
```

### 场景 3：其他 IMAP 邮箱

```
用户输入：user@example.com
    ↓
自动发现服务器配置
    ↓
检测到：imap.example.com
    ↓
显示密码页面（正常流程）
  - 密码输入框
  - 测试连接并保存按钮
    ↓
用户输入密码
    ↓
测试连接
    ↓
保存账户
```

---

## 🎨 UI 设计

### Office 365 检测提示框

**样式：**
- 背景色：`theme.colorScheme.primaryContainer`
- 图标：`Icons.info_outline`
- 圆角：12px
- 内边距：16px

**内容：**
- 标题："检测到 Microsoft 365 / Office 365"
- 说明："推荐使用 OAuth 登录，更安全且无需应用专用密码"

### OAuth 登录按钮

**样式：**
- 类型：`FilledButton.icon`
- 图标：`Icons.login`
- 文本："使用 Microsoft 账号登录"
- 高度：48px（全宽）

### 分隔线

**样式：**
- 左右两条分隔线
- 中间文本："或使用密码登录"
- 颜色：`theme.colorScheme.onSurfaceVariant`

---

## ✅ 优势

### 1. 自动识别
- 无需用户手动选择
- 智能判断服务器类型
- 减少用户困惑

### 2. 推荐最佳方案
- OAuth 更安全
- 无需应用专用密码
- 更好的用户体验

### 3. 保留灵活性
- 仍然支持密码登录
- 适用于特殊场景
- 用户有选择权

### 4. 清晰的引导
- 明确的提示信息
- 醒目的 OAuth 按钮
- 清晰的视觉层次

---

## 🧪 测试场景

### 测试 1：企业邮箱自动识别

**步骤：**
1. 打开应用 → 添加账户
2. 输入企业邮箱：`user@contoso.com`
3. 等待自动发现

**预期结果：**
- 如果服务器是 `outlook.office365.com`
- 显示密码页面
- 包含 Office 365 检测提示
- 显示 OAuth 登录按钮

### 测试 2：OAuth 登录流程

**步骤：**
1. 在密码页面点击"使用 Microsoft 账号登录"
2. 跳转到 OAuth 页面
3. 完成 Microsoft 登录

**预期结果：**
- 成功跳转到 OAuth 页面
- 完成登录后返回应用
- 开始同步邮件

### 测试 3：密码登录（应用专用密码）

**步骤：**
1. 在密码页面输入应用专用密码
2. 点击"测试连接并保存"

**预期结果：**
- 测试连接成功
- 保存账户
- 开始同步邮件

### 测试 4：个人邮箱直接 OAuth

**步骤：**
1. 输入 `user@outlook.com`
2. 等待自动识别

**预期结果：**
- 直接跳转到 OAuth 页面
- 不显示密码页面

---

## 📊 支持的场景

| 邮箱类型 | 域名示例 | 服务器 | 识别方式 | 登录方式 |
|---------|---------|--------|---------|---------|
| Outlook.com | @outlook.com | - | 域名识别 | OAuth（直接） |
| Hotmail | @hotmail.com | - | 域名识别 | OAuth（直接） |
| Microsoft 365 | @company.com | outlook.office365.com | 服务器识别 | OAuth（推荐）+ 密码 |
| Exchange Online | @company.com | outlook.office365.com | 服务器识别 | OAuth（推荐）+ 密码 |
| 其他 IMAP | @example.com | imap.example.com | - | 密码 |

---

## 🔍 识别逻辑

### 优先级

1. **域名识别**（最高优先级）
   - `@outlook.com`, `@hotmail.com` 等
   - 直接识别为 `microsoftGraph`
   - 跳过服务器发现，直接 OAuth

2. **服务器识别**（次优先级）
   - 自动发现后检查 IMAP 主机名
   - 如果是 `outlook.office365.com`
   - 升级为 `microsoftGraph`
   - 显示 OAuth 引导

3. **默认处理**（最低优先级）
   - 其他所有情况
   - 使用 `genericImap`
   - 密码登录

---

## 📝 代码质量

```bash
flutter analyze
```

**结果：**
- ✅ 0 errors
- ✅ 0 warnings
- ℹ️ 8 info (代码风格建议)

---

## 📚 相关文档

- [Microsoft 365 快速开始](microsoft_365_quickstart.md)
- [Microsoft 365 完整配置](microsoft_365_setup.md)
- [Microsoft 365 功能总结](microsoft_365_summary.md)

---

## 🎉 总结

### 实现的功能

1. ✅ 自动识别 Office 365 服务器
2. ✅ 显示 OAuth 登录引导
3. ✅ 保留密码登录选项
4. ✅ 清晰的 UI 提示

### 用户体验

- 🎯 智能识别，无需手动选择
- 🔒 推荐最安全的登录方式
- 🎨 清晰的视觉引导
- 🔄 灵活的登录选项

### 技术实现

- 📦 服务器识别逻辑
- 🎨 UI 组件优化
- 🔀 路由跳转处理
- ✅ 代码质量保证

---

**现在可以测试 Office 365 自动识别功能！** 🎉
