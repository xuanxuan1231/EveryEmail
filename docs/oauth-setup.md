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

Gmail 采用 **Google Identity Services 原生流程**：应用用账户选择器拿到一次性
**server auth code**，交给 Cloudflare Worker 用「Web 应用」客户端（含 secret）兑换
access/refresh token——**不再使用自定义 URI scheme 回调**。

需要在 **同一个 Google Cloud 项目**里创建最多 **3 类** OAuth 客户端。

### 1. 创建项目并启用 Gmail API
访问 [Google Cloud Console](https://console.cloud.google.com/)，新建项目；在
「API 和服务」→「库」中搜索「Gmail API」并启用。

### 2. 配置 OAuth 同意屏幕
- 选择「外部」用户类型，填写应用名称、支持邮箱、开发者邮箱。
- **添加 scope**：`https://mail.google.com/`（受限 scope，全权限 IMAP/SMTP）。
- 隐私政策 URL：验证时必须真实可达（测试模式可先用占位）。
- 「测试用户」里加入你自己的 Google 账户（最多 100 个）。

### 3. 创建 OAuth 客户端 → **Web 应用**（后端兑换用）
- 类型：Web application。
- **无需**填写「已授权的重定向 URI」（原生 server auth code 兑换不走浏览器重定向）。
- 记下 **客户端 ID** 与 **客户端密钥**：
  - 客户端 ID → 应用 `--dart-define=GOOGLE_SERVER_CLIENT_ID` **且** Worker `GOOGLE_WEB_CLIENT_ID`。
  - 客户端密钥 → **只放 Worker**（不进应用、不进版本库）。

### 4. 创建 OAuth 客户端 → **Android**
- 类型：Android；包名：`com.everyemail.app`。
- SHA-1 证书指纹：粘贴上面取到的 SHA-1（先 debug，发布前再加 release）。
- 代码里**不需要**填这个 client id——Android 凭「包名 + SHA-1」自动匹配。
- ⚠️ 此客户端必须存在且 SHA-1 正确，否则 Credential Manager 运行时报错。

### 5. 创建 OAuth 客户端 → **iOS**（仅在要支持 iOS 时）
- 类型：iOS；Bundle ID 与 Xcode 的 `PRODUCT_BUNDLE_IDENTIFIER` 一致。
- 记下 **iOS 客户端 ID** → 应用 `--dart-define=GOOGLE_IOS_CLIENT_ID`。
- 把它的**反向形式**填进 `ios/Runner/Info.plist` 的 `CFBundleURLTypes`
  （`com.googleusercontent.apps.<前缀>`，替换占位符 `YOUR_IOS_CLIENT_ID`）。
- 确认 iOS 部署目标 ≥ 12.0（google_sign_in_ios 要求）。

### 6. 配置 Worker 的 Web client 密钥
```bash
cd cloudflare-worker
# 先把 wrangler.toml 里的 GOOGLE_WEB_CLIENT_ID 填成第 3 步的 Web 客户端 ID
wrangler secret put GOOGLE_WEB_CLIENT_SECRET   # 粘贴第 3 步的客户端密钥
wrangler deploy
```

### 7. 发布到公网（可选，v1 不需要）
- 受限 scope `https://mail.google.com/` 需通过 **CASA 安全评估**（按年付费，已无免费自测）。
- **测试模式**下受限 scope 的 refresh token **7 天过期**（开发够用）。

### 交给应用的值
```bash
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=你的Web客户端ID.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=你的iOS客户端ID.apps.googleusercontent.com   # 仅 iOS
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

## 一次传入所有 Client ID

```bash
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=你的Web客户端ID.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=你的iOS客户端ID.apps.googleusercontent.com \
  --dart-define=MS_OAUTH_CLIENT_ID=00000000-0000-0000-0000-000000000000
```

未配置的提供商会在 UI 中禁用，但通用 IMAP（密码登录）仍可用。
Gmail 还需在 Worker 配好 `GOOGLE_WEB_CLIENT_ID` + `GOOGLE_WEB_CLIENT_SECRET`（见应用 1 第 6 步）。

---

## 常见问题

**Q: 测试模式下 Gmail refresh token 7 天过期怎么办？**  
A: 开发期每周重新登录一次即可；要长期免登录需通过 CASA 验证（付费）。

**Q: Microsoft 登录成功但 IMAP 报 401？**  
A: everyemail 的 Microsoft 账户走 **Graph API**（不走 IMAP），所以不会遇到这个坑。

**Q: 能复用 Thunderbird 的 OAuth 客户端吗？**  
A: 不能。Thunderbird 的 client id 绑定了它自己的包名/签名，你必须创建自己的。

**Q: 发布前还要做什么？**  
A: 用 release keystore 重新取 SHA-1/Base64 哈希：Google 的 **Android** 客户端加上 release SHA-1，Microsoft 应用加上 release Base64 哈希。Gmail 受限 scope 还需通过 CASA 安全评估才能给测试用户以外的人用。
