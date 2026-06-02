# OAuth 应用创建指南

everyemail 需要你自己创建 OAuth 应用（Gmail 和 Microsoft），然后把 Client ID 通过 `--dart-define` 传给 Flutter。

## 前置：确定应用包名与签名指纹

OAuth 把客户端绑定到「包名 + 签名证书指纹」。

**包名**：已设为 `com.everyemail.app`（见 `android/app/build.gradle.kts`）。

**调试签名 SHA-1**（开发/测试用）：
```bash
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android
```
记下 `SHA1:` 那行。

**Microsoft 需要 Base64 签名哈希**：
```bash
keytool -exportcert -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android | openssl sha1 -binary | openssl base64
```

---

## 应用 1：Google Cloud（Gmail / Workspace）

### 1. 创建项目
访问 [Google Cloud Console](https://console.cloud.google.com/)，新建项目。

### 2. 启用 Gmail API
在「API 和服务」→「库」中搜索「Gmail API」并启用。

### 3. 配置 OAuth 同意屏幕
- 选择「外部」用户类型。
- 填写应用名称、支持邮箱、开发者邮箱。
- **添加 scope**：`https://mail.google.com/`（受限 scope，全权限 IMAP/SMTP）。
- 隐私政策 URL：验证时必须真实可达（测试模式可先用占位）。

### 4. 创建 OAuth 客户端 → Android
- 类型：Android
- 包名：`com.everyemail.app`
- SHA-1 证书指纹：粘贴上面取到的 SHA-1（先 debug，发布前再加 release）。
- Android 客户端是 public client，**无 client secret**。

### 5. 测试模式
- 在「OAuth 同意屏幕」→「测试用户」中添加你自己的 Google 账户（最多 100 个）。
- **注意**：测试模式下，受限 scope 的 refresh token **7 天过期**（开发够用）。

### 6. 发布到公网（可选，v1 不需要）
- 受限 scope 需通过 **CASA 安全评估**（按年付费，已无免费自测）。
- 预算：DAST 扫描 + 问卷，约 $500 起，每 12 个月一次。

### 交给应用的值
记下 **Android OAuth 客户端 ID**（形如 `xxxx.apps.googleusercontent.com`），运行时传入：
```bash
flutter run --dart-define=GOOGLE_OAUTH_CLIENT_ID=你的客户端ID.apps.googleusercontent.com
```

---

## 应用 2：Microsoft Entra ID / Azure（Outlook / O365）

### 1. 注册应用
访问 [Azure Portal](https://portal.azure.com/) → Microsoft Entra ID → 应用注册 → 新注册。

### 2. 支持的账户类型
选择「任何组织目录中的账户和个人 Microsoft 账户」→ 对应 authority `common`（同时覆盖 Outlook.com 个人号与 O365 工作/学校号）。

### 3. 添加平台 → 移动和桌面应用
- 重定向 URI：`com.everyemail.app://oauth2redirect`（自定义 scheme，用 AppAuth 不用 MSAL）。
- 或者用 MSAL 格式：`msauth://com.everyemail.app/<Base64签名哈希>`（把上面取到的 Base64 哈希填进去）。
- **推荐前者**（自定义 scheme 更简单）。

### 4. 身份验证设置
- 开启「允许公共客户端流」= 是（public client，无 secret）。

### 5. API 权限 → Microsoft Graph → 委托权限
添加以下权限（个人账户无需管理员同意，企业租户可能需要）：
- `Mail.ReadWrite`
- `Mail.Send`
- `offline_access`（必需，获取 refresh token）
- `User.Read`
- `openid`
- `profile`
- `email`

### 交给应用的值
记下 **应用程序（客户端）ID**（GUID），运行时传入：
```bash
flutter run --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID-GUID
```

---

## 同时传入两个 Client ID

```bash
flutter run \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=xxxx.apps.googleusercontent.com \
  --dart-define=MS_OAUTH_CLIENT_ID=00000000-0000-0000-0000-000000000000
```

未配置的提供商会在 UI 中禁用，但通用 IMAP（密码登录）仍可用。

---

## 常见问题

**Q: 测试模式下 Gmail refresh token 7 天过期怎么办？**  
A: 开发期每周重新登录一次即可；要长期免登录需通过 CASA 验证（付费）。

**Q: Microsoft 登录成功但 IMAP 报 401？**  
A: everyemail 的 Microsoft 账户走 **Graph API**（不走 IMAP），所以不会遇到这个坑。

**Q: 能复用 Thunderbird 的 OAuth 客户端吗？**  
A: 不能。Thunderbird 的 client id 绑定了它自己的包名/签名，你必须创建自己的。

**Q: 发布前还要做什么？**  
A: 用 release keystore 重新取 SHA-1/Base64 哈希，在两个 OAuth 应用里都加上 release 指纹。
