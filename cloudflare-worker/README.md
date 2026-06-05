# Cloudflare Worker for Microsoft Graph Webhooks

这个 Cloudflare Worker 接收 Microsoft Graph API 的 webhook 通知，并通过 FCM HTTP v1 API 推送到移动应用。

## 功能

- ✅ 接收 Graph API webhook 通知
- ✅ 验证 webhook（clientState）
- ✅ 管理订阅（创建、续订、删除）
- ✅ 存储 FCM tokens
- ✅ 发送 FCM 推送通知（使用 HTTP v1 API）

## 部署步骤

### 1. 安装 Wrangler CLI

```bash
npm install -g wrangler
```

### 2. 登录 Cloudflare

```bash
wrangler login
```

### 3. 创建 KV 命名空间

```bash
wrangler kv:namespace create "KV"
```

复制输出的 `id`，更新 `wrangler.toml` 中的 `YOUR_KV_NAMESPACE_ID`。

### 4. 配置 Firebase

#### 4.1 获取 Firebase 项目 ID

1. 访问 https://console.firebase.google.com/
2. 选择你的项目
3. 项目设置 → 常规
4. 复制 **项目 ID**
5. 更新 `wrangler.toml` 中的 `FIREBASE_PROJECT_ID`

#### 4.2 下载 Service Account 密钥

1. Firebase Console → 项目设置 → 服务账号
2. 点击"生成新的私钥"
3. 下载 JSON 文件（例如：`serviceAccountKey.json`）

#### 4.3 配置 Service Account

```bash
# 方法 1：直接粘贴 JSON（推荐）
wrangler secret put FIREBASE_SERVICE_ACCOUNT
# 粘贴完整的 JSON 内容（一行）

# 方法 2：从文件读取
cat serviceAccountKey.json | tr -d '\n' | wrangler secret put FIREBASE_SERVICE_ACCOUNT
```

**重要：** Service Account JSON 必须是一行，不能有换行符。

### 4b. 配置富通知加密（可选，让通知显示邮件主题/发件人）

不配置也能正常推送，只是通知文案是通用的“新邮件 / 您有新邮件”；配置后 Graph 会把邮件主题/发件人**加密**随 webhook 下发，Worker 解密后填进通知。

1. 生成自签名证书 + RSA 私钥：

   ```bash
   openssl req -x509 -newkey rsa:2048 -keyout enc_private.pem -out enc_cert.pem \
     -days 3650 -nodes -subj "/CN=everyemail-fcm"
   ```

2. 把私钥写入 secret（不入库）：

   ```bash
   wrangler secret put ENCRYPTION_PRIVATE_KEY
   # 粘贴 enc_private.pem 全文（含 BEGIN/END PRIVATE KEY 行）
   ```

3. 取证书公钥 base64（一行），填进 `wrangler.toml` 的 `[vars]`：

   ```bash
   grep -v CERTIFICATE enc_cert.pem | tr -d '\n'
   ```

   ```toml
   ENCRYPTION_CERTIFICATE = "MIID...（上一步的一行 base64）"
   ENCRYPTION_CERTIFICATE_ID = "everyemail-key-1"
   ```

> 改动后需**删除并重建**已存在的订阅才会带上加密设置。App 启动时会按订阅 schema 版本自动重建，无需手动操作。

### 5. 更新 Worker URL

在 `wrangler.toml` 中更新 `WORKER_URL` 为你的 Worker URL：
```
https://ee-webhook.gemen.pp.ua
```

### 6. 部署

```bash
cd cloudflare-worker
wrangler deploy
```

## API 端点

### 1. Webhook 接收

```
POST /webhook
```

接收 Graph API 的 webhook 通知。

### 2. 创建订阅

```
POST /api/subscribe
Content-Type: application/json

{
  "accessToken": "user-access-token",
  "userId": "user-id",
  "accountId": "account-id",
  "resource": "/me/mailFolders('Inbox')/messages"
}
```

### 3. 续订订阅

```
POST /api/renew
Content-Type: application/json

{
  "accessToken": "user-access-token",
  "subscriptionId": "subscription-id"
}
```

### 4. 删除订阅

```
POST /api/unsubscribe
Content-Type: application/json

{
  "accessToken": "user-access-token",
  "subscriptionId": "subscription-id",
  "userId": "user-id"
}
```

### 5. 注册 FCM Token

```
POST /api/register-fcm
Content-Type: application/json

{
  "userId": "user-id",
  "accountId": "account-id",
  "fcmToken": "fcm-device-token"
}
```

### 6. 健康检查

```
GET /health
```

## 本地开发

```bash
wrangler dev
```

## 查看日志

```bash
wrangler tail
```

## FCM HTTP v1 API

### 为什么使用 HTTP v1 API？

- ✅ Legacy API（Server Key）已被弃用
- ✅ HTTP v1 API 更安全（使用 OAuth 2.0）
- ✅ 支持更多功能
- ✅ Google 推荐

### 认证流程

1. 使用 Service Account 私钥创建 JWT
2. 用 JWT 交换 OAuth 2.0 access token
3. 使用 access token 调用 FCM API

### Service Account 权限

Service Account 需要以下权限：
- `https://www.googleapis.com/auth/firebase.messaging`

这个权限在下载 Service Account 密钥时自动包含。

## 成本

**免费额度：**
- 100,000 请求/天
- 1GB Workers KV 存储
- 1,000 次 KV 写入/天
- 100,000 次 KV 读取/天

**估算（1000 用户）：**
- 每天约 10,000 次 webhook 请求
- 完全在免费额度内 ✅

## 安全性

- ✅ 验证 clientState（防止伪造通知）
- ✅ HTTPS 加密
- ✅ Service Account 存储在 Cloudflare Secrets
- ✅ OAuth 2.0 认证
- ✅ 订阅自动过期（3 天）

## 监控

在 Cloudflare Dashboard 中查看：
- 请求数量
- 错误率
- 响应时间
- KV 使用情况

## 故障排除

### Webhook 验证失败

确保 `WORKER_URL` 配置正确，Graph API 需要能访问这个 URL。

### FCM 推送失败

**错误：** `Failed to get access token`

**解决：**
1. 检查 Service Account JSON 是否正确
2. 确保 JSON 是一行（没有换行符）
3. 检查 Firebase 项目 ID 是否正确

**错误：** `FCM error: 404`

**解决：**
1. 检查 `FIREBASE_PROJECT_ID` 是否正确
2. 确保 Service Account 有 FCM 权限

### 订阅过期

订阅最长有效期 3 天，需要定期续订。移动应用应该每 2 天调用一次续订 API。

## 测试

### 测试健康检查

```bash
curl https://ee-webhook.gemen.pp.ua/health
```

### 测试 FCM 推送

```bash
curl -X POST https://ee-webhook.gemen.pp.ua/api/register-fcm \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user",
    "accountId": "test-account",
    "fcmToken": "your-fcm-token"
  }'
```

## 参考文档

- [FCM HTTP v1 API](https://firebase.google.com/docs/cloud-messaging/migrate-v1)
- [Service Account 认证](https://firebase.google.com/docs/admin/setup#initialize-sdk)
- [Cloudflare Workers](https://developers.cloudflare.com/workers/)
- [Microsoft Graph Webhooks](https://learn.microsoft.com/en-us/graph/webhooks)
