# 添加 Microsoft 365 / Outlook 账号

## ✅ 已支持！

EveryEmail 已经完整支持 Microsoft 365 和 Outlook.com 账号！

## 🚀 快速开始（3 步）

### 1. 创建 Azure 应用（5 分钟）

访问 https://portal.azure.com/ 并创建应用：

1. Microsoft Entra ID → 应用注册 → 新注册
2. 名称：`EveryEmail`
3. 账户类型：**任何组织目录中的账户和个人 Microsoft 账户**
4. 重定向 URI：`com.everyemail.app://oauth2redirect` (移动和桌面应用程序)
5. API 权限 → 添加 Microsoft Graph 委托权限：
   - Mail.ReadWrite
   - Mail.Send
   - User.Read
   - offline_access
   - openid, email, profile
6. 复制客户端 ID

### 2. 运行应用

```bash
flutter run --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID
```

### 3. 添加账号

1. 打开应用 → 添加账户
2. 输入 Microsoft 邮箱（@outlook.com, @hotmail.com 等）
3. 完成 OAuth 登录
4. 开始同步邮件

## 📚 详细文档

- [快速开始指南](docs/microsoft_365_quickstart.md) - 5 分钟配置
- [完整配置文档](docs/microsoft_365_setup.md) - 详细说明
- [功能总结](docs/microsoft_365_summary.md) - 技术细节

## ✅ 支持的邮箱

- Outlook.com / Hotmail.com / Live.com
- Microsoft 365 (工作/学校账号)
- Exchange Online

## 🎯 功能状态

- ✅ 读取邮件
- ✅ 文件夹管理
- ✅ 搜索邮件
- ✅ 标记已读/星标
- 🚧 发送邮件
- 🚧 下载附件

---

**查看完整文档：** `docs/microsoft_365_quickstart.md`
