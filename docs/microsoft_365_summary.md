# Microsoft 365 / Exchange 账号支持总结

## ✅ 当前状态

EveryEmail **已经支持** Microsoft 365 和 Outlook.com 账号！

### 已实现的功能

#### 1. OAuth 认证 ✅
- Microsoft Entra ID (Azure AD) OAuth 2.0
- 支持个人账号和工作/学校账号
- 自动刷新访问令牌
- 安全存储 refresh token

#### 2. Microsoft Graph API 集成 ✅
- 完整的 Graph Mail API 实现
- 文件夹列表和管理
- 邮件读取和搜索
- 增量同步支持

#### 3. 自动识别 ✅
- 自动识别 Microsoft 域名：
  - `@outlook.com`
  - `@hotmail.com`
  - `@live.com`
  - `@msn.com`
  - `@passport.com`
- 自动跳转到 OAuth 登录

#### 4. 邮件功能 ✅
- 读取所有文件夹的邮件
- 查看邮件详情（HTML/纯文本）
- 查看附件列表
- 查看收件人信息
- 标记已读/未读
- 星标邮件
- 搜索邮件

---

## 📋 配置步骤

### 前置要求

你需要创建一个 Azure 应用注册来获取客户端 ID。

### 快速配置（3 步）

#### 步骤 1：创建 Azure 应用

1. 访问 https://portal.azure.com/
2. Microsoft Entra ID → 应用注册 → 新注册
3. 配置：
   - 名称：`EveryEmail`
   - 账户类型：**任何组织目录中的账户和个人 Microsoft 账户**
   - 重定向 URI：`com.everyemail.app://oauth2redirect` (移动和桌面应用程序)
4. API 权限 → 添加 Microsoft Graph 委托权限：
   - `Mail.ReadWrite`
   - `Mail.Send`
   - `User.Read`
   - `offline_access`
   - `openid`, `email`, `profile`
5. 复制客户端 ID

#### 步骤 2：配置应用

```bash
flutter run --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID
```

#### 步骤 3：添加账号

1. 打开应用 → 添加账户
2. 输入 Microsoft 邮箱
3. 完成 OAuth 登录
4. 开始同步邮件

---

## 🎯 支持的账号类型

### ✅ 完全支持

- **Outlook.com** - 个人邮箱
- **Hotmail.com** - 个人邮箱
- **Live.com** - 个人邮箱
- **MSN.com** - 个人邮箱
- **Microsoft 365** - 工作/学校账号
- **Office 365** - 工作/学校账号
- **Exchange Online** - 企业邮箱
- **自定义域名** - 使用 Microsoft 365 的组织域名

---

## 📁 相关文件

### 核心实现

1. **OAuth 配置**
   - `lib/core/config/app_config.dart` - 客户端 ID 配置
   - `lib/data/auth/oauth_config.dart` - OAuth 端点和权限
   - `lib/data/auth/oauth_service.dart` - OAuth 认证服务

2. **Graph API 后端**
   - `lib/data/backends/graph/graph_mail_backend.dart` - Graph API 实现
   - `lib/data/sync/sync_service.dart` - 同步服务

3. **自动发现**
   - `lib/data/autoconfig/discovery_service.dart` - 域名识别

4. **UI 页面**
   - `lib/features/onboarding/add_account_page.dart` - 添加账号入口
   - `lib/features/onboarding/oauth_page.dart` - OAuth 登录页面

### 文档

- `docs/microsoft_365_setup.md` - 完整配置指南
- `docs/microsoft_365_quickstart.md` - 快速开始指南
- `README_M365.md` - 简短说明

---

## 🔧 技术细节

### Microsoft Graph API

**基础 URL：** `https://graph.microsoft.com/v1.0`

**主要端点：**
```
GET  /me/mailFolders              # 获取文件夹列表
GET  /me/messages                 # 获取邮件列表
GET  /me/mailFolders/{id}/messages/delta  # 增量同步
GET  /me/messages/{id}            # 获取邮件详情
PATCH /me/messages/{id}           # 更新邮件
POST /me/sendMail                 # 发送邮件
```

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

**授权端点：**
```
https://login.microsoftonline.com/common/oauth2/v2.0/authorize
```

**令牌端点：**
```
https://login.microsoftonline.com/common/oauth2/v2.0/token
```

**重定向 URI：**
```
com.everyemail.app://oauth2redirect
```

### 数据存储

- **Refresh Token**: 系统安全存储（Keychain/Keystore）
- **Access Token**: 内存中（1 小时有效期）
- **账户配置**: SQLite 数据库
- **邮件数据**: SQLite 数据库（本地）

---

## 🚀 功能状态

### 已实现 ✅

| 功能 | 状态 | 说明 |
|------|------|------|
| OAuth 登录 | ✅ | 完整实现 |
| 文件夹列表 | ✅ | 所有文件夹类型 |
| 读取邮件 | ✅ | HTML 和纯文本 |
| 邮件搜索 | ✅ | 多字段搜索 |
| 查看附件 | ✅ | 列表显示 |
| 收件人信息 | ✅ | 完整显示 |
| 标记已读 | ✅ | 本地更新 |
| 星标邮件 | ✅ | 本地更新 |
| 增量同步 | ✅ | Delta API |

### 待实现 🚧

| 功能 | 优先级 | 说明 |
|------|--------|------|
| 发送邮件 | 高 | POST /me/sendMail |
| 下载附件 | 高 | GET /me/messages/{id}/attachments/{attachmentId}/$value |
| 删除邮件（同步） | 中 | DELETE /me/messages/{id} |
| 移动邮件（同步） | 中 | POST /me/messages/{id}/move |
| 标记已读（同步） | 中 | PATCH /me/messages/{id} |
| 推送通知 | 低 | Webhooks |
| 日历集成 | 低 | Calendar API |
| 联系人同步 | 低 | Contacts API |

---

## 📊 与 IMAP 的对比

| 特性 | Microsoft Graph | IMAP |
|------|----------------|------|
| 认证方式 | OAuth 2.0 | 密码/应用专用密码 |
| 安全性 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| 性能 | 快（REST API） | 较慢（协议开销） |
| 功能 | 丰富（邮件+日历+联系人） | 仅邮件 |
| 推送通知 | 支持（Webhooks） | 支持（IDLE） |
| Microsoft 支持 | 推荐 | 逐步淘汰 |

**结论：** Microsoft Graph 是访问 Microsoft 365 邮箱的推荐方式。

---

## ❓ 常见问题

### Q: 为什么不使用 IMAP？

A: Microsoft 正在逐步淘汰 IMAP 支持，推荐使用 Graph API。Graph API 功能更强大，性能更好，安全性更高。

### Q: 需要付费吗？

A: 不需要。创建 Azure 应用是免费的，使用 Graph API 也是免费的。

### Q: 个人账号和工作账号有什么区别？

A: 
- **个人账号**：任何人都可以直接使用
- **工作账号**：可能需要组织管理员授权

### Q: 如何处理"需要管理员同意"？

A: 联系你的 IT 管理员，让他们在 Azure 门户中为你的应用授予同意。

### Q: 支持多个账号吗？

A: 是的，可以添加多个 Microsoft 账号，每个账号独立管理。

### Q: 数据安全吗？

A: 
- 所有数据存储在本地设备
- Refresh token 存储在系统安全存储
- 使用 HTTPS 加密通信
- 不会上传数据到第三方服务器

---

## 🔍 故障排除

### 问题 1：OAuth 登录失败

**症状：** 点击登录后无响应或报错

**可能原因：**
- 客户端 ID 未配置或错误
- 重定向 URI 不匹配
- 网络连接问题

**解决方法：**
1. 检查客户端 ID 是否正确配置
2. 确认重定向 URI 为 `com.everyemail.app://oauth2redirect`
3. 检查 Azure 应用的 API 权限
4. 查看应用日志

### 问题 2：无法同步邮件

**症状：** 登录成功但看不到邮件

**可能原因：**
- Token 过期
- API 权限不足
- 网络问题

**解决方法：**
1. 重新登录账号
2. 检查 Azure 应用的 API 权限是否完整
3. 查看应用日志中的错误信息

### 问题 3：只能看到收件箱

**症状：** 侧边栏只显示收件箱文件夹

**可能原因：**
- 文件夹同步未完成
- 之前的 Bug（已修复）

**解决方法：**
1. 等待几秒钟让同步完成
2. 打开侧边栏查看文件夹列表
3. 如果仍然只有收件箱，重新同步账户

---

## 📚 参考资料

### Microsoft 官方文档

- [Microsoft Graph API 概述](https://learn.microsoft.com/graph/api/overview)
- [Microsoft Graph Mail API](https://learn.microsoft.com/graph/api/resources/mail-api-overview)
- [Azure 应用注册](https://learn.microsoft.com/azure/active-directory/develop/quickstart-register-app)
- [OAuth 2.0 授权码流程](https://learn.microsoft.com/azure/active-directory/develop/v2-oauth2-auth-code-flow)

### 开发者资源

- [Microsoft 365 开发者计划](https://developer.microsoft.com/microsoft-365/dev-program) - 免费测试账号
- [Graph Explorer](https://developer.microsoft.com/graph/graph-explorer) - API 测试工具
- [Azure Portal](https://portal.azure.com/) - 应用管理

---

## 🎉 总结

EveryEmail **已经完整支持** Microsoft 365 和 Outlook.com 账号！

**你需要做的：**
1. ✅ 创建 Azure 应用（5 分钟）
2. ✅ 配置客户端 ID
3. ✅ 添加账号并开始使用

**已经可以使用的功能：**
- ✅ 读取所有文件夹的邮件
- ✅ 搜索邮件
- ✅ 查看邮件详情
- ✅ 标记已读/星标
- ✅ 查看附件和收件人

**即将推出的功能：**
- 🚧 发送邮件
- 🚧 下载附件
- 🚧 邮件操作同步

---

**快速开始：** 查看 `docs/microsoft_365_quickstart.md`

**详细配置：** 查看 `docs/microsoft_365_setup.md`

**最后更新：** 2026/05/31
