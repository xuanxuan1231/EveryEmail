# Microsoft OAuth 强制选择账户功能

## ✅ 实现完成

已为 Microsoft OAuth 添加 `prompt=select_account` 参数，强制用户在每次登录时选择账户。

---

## 🎯 问题描述

**原问题：**
- 浏览器已登录个人 Microsoft 账号
- 尝试添加工作账号时，自动使用浏览器中的个人账号
- 无法切换到工作账号登录

**解决方案：**
- 添加 `prompt=select_account` 参数
- 强制 Microsoft 登录页面显示账户选择器
- 用户可以选择不同的账户或添加新账户

---

## 🔧 技术实现

### 修改的文件

**`lib/data/auth/oauth_config.dart`**

### 修改内容

**之前：**
```dart
static OAuthProviderConfig? microsoft() {
  if (!AppConfig.isMicrosoftConfigured) return null;
  return OAuthProviderConfig(
    clientId: AppConfig.microsoftClientId,
    redirectUrl: '${AppConfig.redirectScheme}://oauth2redirect',
    scopes: const [...],
    serviceConfiguration: const AuthorizationServiceConfiguration(...),
    // 没有 additionalParameters
  );
}
```

**之后：**
```dart
static OAuthProviderConfig? microsoft() {
  if (!AppConfig.isMicrosoftConfigured) return null;
  return OAuthProviderConfig(
    clientId: AppConfig.microsoftClientId,
    redirectUrl: '${AppConfig.redirectScheme}://oauth2redirect',
    scopes: const [...],
    serviceConfiguration: const AuthorizationServiceConfiguration(...),
    // 强制选择账户，避免自动使用浏览器中已登录的账户
    additionalParameters: const {
      'prompt': 'select_account',
    },
  );
}
```

---

## 📱 用户体验变化

### 之前的行为

```
用户点击 OAuth 登录
    ↓
跳转到 Microsoft 登录页面
    ↓
自动使用浏览器中已登录的账户
    ↓
直接进入权限确认页面
    ↓
无法切换账户 ❌
```

### 现在的行为

```
用户点击 OAuth 登录
    ↓
跳转到 Microsoft 登录页面
    ↓
显示账户选择器 ✅
    ↓
用户可以：
  - 选择已登录的个人账号
  - 选择已登录的工作账号
  - 使用其他账户登录
    ↓
进入权限确认页面
    ↓
完成登录
```

---

## 🎨 Microsoft 账户选择器

### 显示内容

Microsoft 登录页面会显示：

1. **已登录的账户列表**
   - 个人账号（如 user@outlook.com）
   - 工作账号（如 user@company.com）
   - 每个账户显示头像和邮箱

2. **使用其他账户**
   - 点击可以输入新的账户
   - 支持个人账号和工作账号

3. **账户管理**
   - 可以移除已保存的账户
   - 可以添加新账户

---

## 🔍 `prompt` 参数说明

Microsoft OAuth 2.0 支持的 `prompt` 参数值：

| 值 | 说明 | 用途 |
|---|------|------|
| `select_account` | 强制显示账户选择器 | 允许用户选择或切换账户 ✅ |
| `consent` | 强制显示权限同意页面 | 每次都要求用户同意权限 |
| `login` | 强制重新登录 | 即使已登录也要求输入密码 |
| `none` | 静默登录 | 如果未登录则失败 |

**我们使用 `select_account`：**
- ✅ 允许用户选择账户
- ✅ 不强制重新输入密码
- ✅ 用户体验最佳

---

## ✅ 优势

### 1. 解决账户冲突
- ✅ 可以在个人账号和工作账号之间切换
- ✅ 不会自动使用错误的账户
- ✅ 避免登录失败

### 2. 支持多账户
- ✅ 可以添加多个个人账号
- ✅ 可以添加多个工作账号
- ✅ 每次登录都可以选择

### 3. 更好的用户体验
- ✅ 清晰的账户选择界面
- ✅ 不需要先退出浏览器账号
- ✅ 符合用户预期

### 4. 安全性
- ✅ 用户明确知道使用哪个账户
- ✅ 避免误用他人账户
- ✅ 符合企业安全要求

---

## 🧪 测试步骤

### 测试 1：个人账号和工作账号切换

**前提条件：**
- 浏览器已登录个人 Microsoft 账号（如 user@outlook.com）

**测试步骤：**
1. 打开应用 → 添加账户
2. 输入工作邮箱：`user@company.com`
3. 等待自动发现（如果是 Office 365）
4. 点击"使用 Microsoft 账号登录"

**预期结果：**
- ✅ 显示 Microsoft 账户选择器
- ✅ 列出已登录的个人账号
- ✅ 可以点击"使用其他账户"
- ✅ 输入工作账号邮箱和密码
- ✅ 完成工作账号登录

### 测试 2：多个工作账号

**前提条件：**
- 浏览器已登录工作账号 A（如 user1@company.com）

**测试步骤：**
1. 尝试添加工作账号 B：`user2@company.com`
2. 点击 OAuth 登录

**预期结果：**
- ✅ 显示账户选择器
- ✅ 可以选择"使用其他账户"
- ✅ 输入账号 B 的凭据
- ✅ 完成账号 B 的登录

### 测试 3：个人账号（Outlook.com）

**测试步骤：**
1. 输入 `user@outlook.com`
2. 点击 OAuth 登录

**预期结果：**
- ✅ 显示账户选择器
- ✅ 可以选择已登录的账户或使用其他账户

---

## 📊 与 Google OAuth 的对比

### Google OAuth

**当前配置：**
```dart
additionalParameters: const {
  'access_type': 'offline',
  'prompt': 'consent',
},
```

**行为：**
- `prompt: consent` - 每次都显示权限同意页面
- 也会显示账户选择器（Google 的默认行为）

### Microsoft OAuth

**当前配置：**
```dart
additionalParameters: const {
  'prompt': 'select_account',
},
```

**行为：**
- `prompt: select_account` - 强制显示账户选择器
- 不会每次都要求同意权限（除非权限变更）

**结论：** 两者都支持账户选择，但实现方式略有不同。

---

## 🔧 Azure 应用配置

### 不需要修改 Azure 应用！

**好消息：** `prompt=select_account` 是 OAuth 2.0 标准参数，不需要在 Azure 门户中配置任何东西。

**Azure 应用配置保持不变：**
- ✅ 重定向 URI：`com.everyemail.app://oauth2redirect`
- ✅ API 权限：Mail.ReadWrite, Mail.Send, User.Read, offline_access
- ✅ 平台：移动和桌面应用程序

**只需要修改代码即可！**

---

## 📚 Microsoft 文档参考

### prompt 参数文档

**官方文档：**
- [Microsoft identity platform and OAuth 2.0 authorization code flow](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow)
- [prompt parameter](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow#request-an-authorization-code)

**prompt=select_account 说明：**
> Forces the user to select an account, interrupting single sign-on. The user may select an existing signed-in account, enter credentials for a remembered account, or choose to use a different account altogether.

**翻译：**
> 强制用户选择账户，中断单点登录。用户可以选择现有的已登录账户、输入已记住账户的凭据，或选择使用完全不同的账户。

---

## 📊 代码质量

```bash
flutter analyze lib/data/auth/oauth_config.dart
```

**结果：**
- ✅ 0 errors
- ✅ 0 warnings
- ✅ 0 info

---

## 🎉 总结

### 实现的功能

- ✅ 添加 `prompt=select_account` 参数
- ✅ 强制显示 Microsoft 账户选择器
- ✅ 支持个人账号和工作账号切换
- ✅ 不需要修改 Azure 应用配置

### 用户体验改进

- ✅ 可以在多个账户之间选择
- ✅ 不会自动使用错误的账户
- ✅ 清晰的账户选择界面
- ✅ 符合用户预期

### 技术优势

- ✅ 使用标准 OAuth 2.0 参数
- ✅ 无需额外配置
- ✅ 代码简洁清晰
- ✅ 易于维护

---

## 🚀 现在可以测试

```bash
flutter run --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID
```

**测试场景：**
1. 确保浏览器已登录个人 Microsoft 账号
2. 在应用中添加工作账号
3. 点击 OAuth 登录
4. 观察是否显示账户选择器
5. 选择"使用其他账户"
6. 输入工作账号凭据
7. 完成登录

---

**功能已实现，无需修改 Azure 应用配置！** 🎉✨
