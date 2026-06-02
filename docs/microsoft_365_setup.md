# Microsoft 365 (Exchange) 账号配置指南

## 概述

EveryEmail 支持通过 Microsoft Graph API 添加 Microsoft 365 和 Outlook.com 账号。

**支持的账号类型：**
- ✅ Microsoft 365 (工作或学校账号)
- ✅ Outlook.com (个人账号)
- ✅ Hotmail.com
- ✅ Live.com

**认证方式：** OAuth 2.0 (无需应用专用密码)

---

## 前置要求

### 1. 注册 Microsoft Entra ID 应用

你需要在 Microsoft Azure 门户创建一个应用注册：

#### 步骤 1：访问 Azure 门户
1. 访问 [Azure Portal](https://portal.azure.com/)
2. 登录你的 Microsoft 账号
3. 搜索并进入 **"Microsoft Entra ID"** (原 Azure Active Directory)

#### 步骤 2：创建应用注册
1. 在左侧菜单选择 **"应用注册"**
2. 点击 **"新注册"**
3. 填写信息：
   - **名称**: `EveryEmail` (或你喜欢的名称)
   - **支持的账户类型**: 选择 **"任何组织目录中的账户和个人 Microsoft 账户"**
   - **重定向 URI**: 
     - 平台: **"移动和桌面应用程序"**
     - URI: `com.everyemail.app://oauth2redirect`
4. 点击 **"注册"**

#### 步骤 3：配置 API 权限
1. 在应用页面，选择 **"API 权限"**
2. 点击 **"添加权限"**
3. 选择 **"Microsoft Graph"**
4. 选择 **"委托的权限"**
5. 添加以下权限：
   - `Mail.ReadWrite` - 读写邮件
   - `Mail.Send` - 发送邮件
   - `User.Read` - 读取用户信息
   - `offline_access` - 获取刷新令牌
   - `openid` - OpenID Connect
   - `email` - 读取邮箱地址
   - `profile` - 读取用户资料
6. 点击 **"添加权限"**
7. （可选）点击 **"为 [你的组织] 授予管理员同意"**

#### 步骤 4：获取客户端 ID
1. 在应用页面，选择 **"概述"**
2. 复制 **"应用程序(客户端) ID"**
   - 格式：`00000000-0000-0000-0000-000000000000` (GUID)

#### 步骤 5：配置移动平台
1. 在应用页面，选择 **"身份验证"**
2. 在 **"平台配置"** 下，点击 **"添加平台"**
3. 选择 **"移动和桌面应用程序"**
4. 添加重定向 URI：
   - `com.everyemail.app://oauth2redirect`
5. 勾选 **"公共客户端流"** 下的选项
6. 点击 **"配置"**

---

## 配置应用

### 方法 1：使用命令行参数（推荐）

运行应用时传入客户端 ID：

```bash
flutter run \
  --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID
```

**示例：**
```bash
flutter run \
  --dart-define=MS_OAUTH_CLIENT_ID=12345678-1234-1234-1234-123456789abc
```

### 方法 2：配置 Android 构建

编辑 `android/app/build.gradle.kts`，在 `defaultConfig` 中添加：

```kotlin
defaultConfig {
    // ...
    
    // Microsoft OAuth 客户端 ID
    buildConfigField("String", "MS_OAUTH_CLIENT_ID", "\"你的客户端ID\"")
}
```

### 方法 3：环境变量（开发环境）

创建 `.env` 文件（不要提交到 Git）：

```env
MS_OAUTH_CLIENT_ID=你的客户端ID
```

---

## 添加 Microsoft 365 账号

### 使用应用添加账号

1. **打开应用**
   - 点击 **"添加账户"**

2. **输入邮箱地址**
   - 输入你的 Microsoft 365 或 Outlook.com 邮箱
   - 例如：`user@contoso.com` 或 `user@outlook.com`

3. **自动识别**
   - 应用会自动识别 Microsoft 账号
   - 跳转到 OAuth 登录页面

4. **Microsoft 登录**
   - 在浏览器中完成 Microsoft 登录
   - 授权应用访问你的邮件
   - 登录成功后自动返回应用

5. **同步邮件**
   - 应用开始同步邮件
   - 等待同步完成

---

## 支持的功能

### ✅ 已实现

- **邮件读取**
  - 读取收件箱、已发送、草稿箱等文件夹
  - 查看邮件内容（HTML 和纯文本）
  - 查看附件列表
  - 查看收件人信息

- **邮件搜索**
  - 按主题、发件人、内容搜索

- **文件夹管理**
  - 查看所有文件夹
  - 切换文件夹
  - 显示未读数量

- **邮件标记**
  - 标记已读/未读
  - 星标邮件

### 🚧 待实现

- **邮件发送**
  - 撰写新邮件
  - 回复邮件
  - 转发邮件

- **邮件操作**
  - 删除邮件（同步到服务器）
  - 移动邮件到其他文件夹
  - 下载附件

- **高级功能**
  - 推送通知
  - 日历集成
  - 联系人同步

---

## 技术细节

### Microsoft Graph API

应用使用 Microsoft Graph REST API v1.0：

**端点：**
- `GET /me/mailFolders` - 获取文件夹列表
- `GET /me/messages` - 获取邮件列表
- `GET /me/mailFolders/{id}/messages/delta` - 增量同步
- `GET /me/messages/{id}` - 获取邮件详情
- `PATCH /me/messages/{id}` - 更新邮件（标记已读等）
- `POST /me/sendMail` - 发送邮件

**权限范围：**
```
https://graph.microsoft.com/Mail.ReadWrite
https://graph.microsoft.com/Mail.Send
https://graph.microsoft.com/User.Read
offline_access
openid
email
profile
```

### OAuth 2.0 流程

1. **授权请求**
   - 端点：`https://login.microsoftonline.com/common/oauth2/v2.0/authorize`
   - 参数：client_id, redirect_uri, scope, response_type=code

2. **令牌交换**
   - 端点：`https://login.microsoftonline.com/common/oauth2/v2.0/token`
   - 获取 access_token 和 refresh_token

3. **令牌刷新**
   - 使用 refresh_token 获取新的 access_token
   - access_token 有效期约 1 小时

### 数据存储

- **Refresh Token**: 存储在系统安全存储（Keychain/Keystore）
- **账户配置**: 存储在本地 SQLite 数据库
- **邮件数据**: 存储在本地 SQLite 数据库

---

## 常见问题

### Q: 为什么需要创建 Azure 应用？

A: Microsoft 要求所有使用 Graph API 的应用都必须在 Azure 中注册。这是为了安全和审计目的。

### Q: 个人账号和工作账号有什么区别？

A: 
- **个人账号** (Outlook.com, Hotmail.com): 任何人都可以使用
- **工作账号** (Microsoft 365): 需要组织管理员授权

### Q: 如何处理"需要管理员同意"的错误？

A: 如果你的组织要求管理员同意，请联系你的 IT 管理员，让他们在 Azure 门户中为你的应用授予同意。

### Q: 支持多个 Microsoft 账号吗？

A: 是的，你可以添加多个 Microsoft 账号，每个账号独立管理。

### Q: 数据安全吗？

A: 
- 所有数据存储在本地设备
- Refresh token 存储在系统安全存储
- 使用 HTTPS 加密通信
- 不会上传数据到第三方服务器

### Q: 为什么不使用 IMAP？

A: Microsoft 正在逐步淘汰 IMAP 支持，推荐使用 Graph API。Graph API 功能更强大，性能更好。

---

## 故障排除

### 问题 1：OAuth 登录失败

**可能原因：**
- 客户端 ID 配置错误
- 重定向 URI 不匹配
- 网络连接问题

**解决方法：**
1. 检查客户端 ID 是否正确
2. 确认重定向 URI 为 `com.everyemail.app://oauth2redirect`
3. 检查网络连接

### 问题 2：无法同步邮件

**可能原因：**
- Token 过期
- API 权限不足
- 网络问题

**解决方法：**
1. 重新登录账号
2. 检查 Azure 应用的 API 权限
3. 查看应用日志

### 问题 3：只能看到收件箱

**可能原因：**
- 文件夹同步未完成
- 文件夹类型识别错误

**解决方法：**
1. 等待同步完成
2. 手动刷新文件夹列表
3. 查看侧边栏的文件夹列表

---

## 开发者信息

### 相关文件

**OAuth 配置：**
- `lib/core/config/app_config.dart` - 客户端 ID 配置
- `lib/data/auth/oauth_config.dart` - OAuth 端点和权限
- `lib/data/auth/oauth_service.dart` - OAuth 认证服务

**Graph API 后端：**
- `lib/data/backends/graph/graph_mail_backend.dart` - Graph API 实现
- `lib/data/sync/sync_service.dart` - 同步服务

**UI 页面：**
- `lib/features/onboarding/add_account_page.dart` - 添加账号入口
- `lib/features/onboarding/oauth_page.dart` - OAuth 登录页面

### 测试账号

建议使用 Microsoft 开发者计划创建测试账号：
- 访问 [Microsoft 365 开发者计划](https://developer.microsoft.com/microsoft-365/dev-program)
- 免费获取 Microsoft 365 E5 订阅（90 天）
- 创建测试用户和邮箱

---

## 下一步

1. **配置客户端 ID**
   - 按照上述步骤创建 Azure 应用
   - 获取客户端 ID
   - 配置到应用中

2. **测试添加账号**
   - 运行应用
   - 添加 Microsoft 365 账号
   - 测试邮件同步

3. **完善功能**
   - 实现邮件发送
   - 实现附件下载
   - 实现邮件操作同步

---

## 参考资料

- [Microsoft Graph API 文档](https://learn.microsoft.com/graph/api/overview)
- [Microsoft Graph Mail API](https://learn.microsoft.com/graph/api/resources/mail-api-overview)
- [Azure 应用注册](https://learn.microsoft.com/azure/active-directory/develop/quickstart-register-app)
- [OAuth 2.0 授权码流程](https://learn.microsoft.com/azure/active-directory/develop/v2-oauth2-auth-code-flow)

---

## 支持

如有问题，请查看：
- 应用日志
- Azure 门户的应用日志
- Microsoft Graph API 文档

---

**最后更新：** 2026/05/31
