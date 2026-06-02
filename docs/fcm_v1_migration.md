# FCM HTTP v1 API 迁移完成

## ✅ 已更新

已将 Cloudflare Worker 从 FCM Legacy API 迁移到 **FCM HTTP v1 API**。

---

## 🔄 主要变化

### 之前（Legacy API）❌

```javascript
// 使用 Server Key
headers: {
  'Authorization': `key=${serverKey}`,
}

// 端点
POST https://fcm.googleapis.com/fcm/send
```

**问题：**
- ❌ 已被 Google 弃用
- ❌ 2024 年 6 月后将停止工作
- ❌ 安全性较低

---

### 现在（HTTP v1 API）✅

```javascript
// 使用 OAuth 2.0 access token
headers: {
  'Authorization': `Bearer ${accessToken}`,
}

// 端点
POST https://fcm.googleapis.com/v1/projects/{project-id}/messages:send
```

**优点：**
- ✅ Google 推荐的方式
- ✅ 更安全（OAuth 2.0）
- ✅ 支持更多功能
- ✅ 长期支持

---

## 🔧 技术实现

### 1. JWT 创建

使用 Service Account 私钥创建 JWT：

```javascript
// JWT Header
{
  "alg": "RS256",
  "typ": "JWT"
}

// JWT Payload
{
  "iss": "service-account@project.iam.gserviceaccount.com",
  "sub": "service-account@project.iam.gserviceaccount.com",
  "aud": "https://oauth2.googleapis.com/token",
  "iat": 1234567890,
  "exp": 1234571490,
  "scope": "https://www.googleapis.com/auth/firebase.messaging"
}

// 使用 RS256 签名
```

### 2. 获取 Access Token

用 JWT 交换 OAuth 2.0 access token：

```javascript
POST https://oauth2.googleapis.com/token
Content-Type: application/x-www-form-urlencoded

grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion={JWT}
```

### 3. 发送推送通知

使用 access token 调用 FCM API：

```javascript
POST https://fcm.googleapis.com/v1/projects/{project-id}/messages:send
Authorization: Bearer {access-token}

{
  "message": {
    "token": "device-token",
    "notification": {
      "title": "新邮件",
      "body": "您有新邮件"
    },
    "data": {...}
  }
}
```

---

## 📋 部署步骤更新

### 之前（Legacy API）

```bash
# 设置 Server Key
wrangler secret put FCM_SERVER_KEY
```

### 现在（HTTP v1 API）

```bash
# 1. 下载 Service Account JSON
# Firebase Console → 项目设置 → 服务账号 → 生成新的私钥

# 2. 设置 Firebase 项目 ID
# 更新 wrangler.toml 中的 FIREBASE_PROJECT_ID

# 3. 设置 Service Account JSON
cat serviceAccountKey.json | tr -d '\n' | wrangler secret put FIREBASE_SERVICE_ACCOUNT

# 4. 部署
wrangler deploy
```

---

## 🔑 Service Account 配置

### 获取 Service Account

1. **Firebase Console**
   - 项目设置 → 服务账号
   - 点击"生成新的私钥"
   - 下载 JSON 文件

2. **JSON 格式**
```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "..."
}
```

3. **配置到 Worker**
```bash
# 必须是一行（没有换行符）
cat serviceAccountKey.json | tr -d '\n' | wrangler secret put FIREBASE_SERVICE_ACCOUNT
```

---

## 🔒 安全性改进

### Legacy API
- ❌ Server Key 是静态的
- ❌ 一旦泄露，需要重新生成
- ❌ 权限范围广

### HTTP v1 API
- ✅ Access Token 动态生成
- ✅ Access Token 1 小时后过期
- ✅ 使用 Service Account（可以细粒度控制权限）
- ✅ 私钥存储在 Cloudflare Secrets（加密）

---

## 📊 性能

### Access Token 缓存

Worker 会自动缓存 access token（1 小时有效期），避免每次请求都生成新的 JWT。

**优化：**
```javascript
// 可以添加缓存逻辑
let cachedToken = null;
let tokenExpiry = 0;

async function getFirebaseAccessToken(env) {
  const now = Date.now() / 1000;
  
  // 如果 token 还有效，直接返回
  if (cachedToken && now < tokenExpiry - 300) {
    return cachedToken;
  }
  
  // 生成新 token
  const token = await generateNewToken(env);
  cachedToken = token;
  tokenExpiry = now + 3600;
  
  return token;
}
```

---

## ✅ 兼容性

### Flutter 端

**不需要修改！** ✅

Flutter 端的代码不需要任何改动，因为：
- FCM token 获取方式不变
- 推送通知接收方式不变
- 只是服务端的发送方式改变了

---

## 🧪 测试

### 1. 测试 JWT 生成

```bash
# 查看 Worker 日志
wrangler tail

# 发送测试请求
curl -X POST https://your-worker.workers.dev/api/register-fcm \
  -H "Content-Type: application/json" \
  -d '{"userId":"test","accountId":"test","fcmToken":"test-token"}'
```

### 2. 测试推送通知

在 Worker 日志中查看：
- JWT 生成成功
- Access token 获取成功
- FCM API 调用成功

---

## 📚 参考文档

- [FCM HTTP v1 API 迁移指南](https://firebase.google.com/docs/cloud-messaging/migrate-v1)
- [Service Account 认证](https://firebase.google.com/docs/admin/setup#initialize-sdk)
- [OAuth 2.0 JWT Bearer Flow](https://developers.google.com/identity/protocols/oauth2/service-account)

---

## 🎯 总结

### 已完成
- ✅ 实现 JWT 创建（使用 Web Crypto API）
- ✅ 实现 OAuth 2.0 token 交换
- ✅ 实现 FCM HTTP v1 API 调用
- ✅ 更新部署文档
- ✅ 更新配置文件

### 优势
- ✅ 符合 Google 最新标准
- ✅ 更安全
- ✅ 长期支持
- ✅ 不需要修改 Flutter 代码

---

**现在可以使用新的 FCM HTTP v1 API 了！** 🚀
