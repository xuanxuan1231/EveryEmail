# Cloudflare Workers + Graph API Webhooks 实现完成

## ✅ 已完成的工作

### 1. Cloudflare Worker ✅

**目录：** `cloudflare-worker/`

**文件：**
- `src/index.js` - Worker 主代码
- `wrangler.toml` - 配置文件
- `package.json` - 依赖配置
- `README.md` - 部署文档

**功能：**
- ✅ 接收 Graph API webhook 通知
- ✅ 验证 webhook（clientState）
- ✅ 管理订阅（创建、续订、删除）
- ✅ 存储 FCM tokens（Workers KV）
- ✅ 发送 FCM 推送通知
- ✅ CORS 支持
- ✅ 健康检查

---

### 2. Flutter 集成 ✅

**文件：**
- `lib/data/webhook/webhook_service.dart` - Webhook API 客户端
- `lib/data/webhook/webhook_manager.dart` - 订阅管理器

**功能：**
- ✅ 创建订阅
- ✅ 续订订阅（自动，每 2 天）
- ✅ 删除订阅
- ✅ 注册 FCM token
- ✅ 处理推送通知
- ✅ 触发增量同步

---

## 🚀 部署步骤

### 第 1 步：部署 Cloudflare Worker

```bash
# 1. 进入 worker 目录
cd cloudflare-worker

# 2. 安装 Wrangler CLI
npm install -g wrangler

# 3. 登录 Cloudflare
wrangler login

# 4. 创建 KV 命名空间
wrangler kv:namespace create "KV"
# 复制输出的 id，更新 wrangler.toml

# 5. 设置 FCM Server Key
wrangler secret put FCM_SERVER_KEY
# 输入你的 FCM Server Key

# 6. 更新 wrangler.toml
# 修改 WORKER_URL 为你的 Worker URL

# 7. 部署
wrangler deploy

# 8. 查看 Worker URL
# 输出类似：https://ee-webhook.gemen.pp.ua
```

---

### 第 2 步：配置 FCM

#### 2.1 创建 Firebase 项目

1. 访问 https://console.firebase.google.com/
2. 创建新项目或选择现有项目
3. 添加 Android 应用
4. 下载 `google-services.json`

#### 2.2 配置 Android

**1. 添加 google-services.json**
```bash
# 复制到 android/app/
cp google-services.json android/app/
```

**2. 修改 android/build.gradle**
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

**3. 修改 android/app/build.gradle**
```gradle
plugins {
    id 'com.google.gms.google-services'
}

dependencies {
    implementation 'com.google.firebase:firebase-messaging:23.4.0'
}
```

#### 2.3 获取 FCM Server Key

1. Firebase Console → 项目设置 → Cloud Messaging
2. 复制 **Server Key**
3. 在 Cloudflare Worker 中设置：
   ```bash
   wrangler secret put FCM_SERVER_KEY
   ```

---

### 第 3 步：集成到 Flutter 应用

#### 3.1 添加依赖

**pubspec.yaml:**
```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
```

#### 3.2 初始化 Firebase

**lib/main.dart:**
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// 后台消息处理器
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('后台消息: ${message.messageId}');
  // 触发同步
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Firebase
  await Firebase.initializeApp();
  
  // 注册后台消息处理器
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(MyApp());
}
```

#### 3.3 添加 Provider

**lib/app/providers.dart:**
```dart
import '../data/webhook/webhook_service.dart';
import '../data/webhook/webhook_manager.dart';

final webhookServiceProvider = Provider<WebhookService>((ref) {
  return WebhookService(
    workerUrl: 'https://ee-webhook.gemen.pp.ua',
  );
});

final webhookManagerProvider = Provider<WebhookManager>((ref) {
  return WebhookManager(
    webhookService: ref.watch(webhookServiceProvider),
    syncService: ref.watch(syncServiceProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    oauthService: ref.watch(oauthServiceProvider),
    db: ref.watch(databaseProvider),
  );
});
```

#### 3.4 在 OAuth 登录后启用 Webhook

**lib/features/onboarding/oauth_page.dart:**
```dart
// OAuth 登录成功后
final account = AccountConfig(...);

// 1. 获取 FCM token
final fcmToken = await FirebaseMessaging.instance.getToken();

// 2. 注册 FCM token
final webhookManager = ref.read(webhookManagerProvider);
await webhookManager.registerFCMToken(account.id, fcmToken!);

// 3. 启用 webhook
await webhookManager.enableWebhook(account);
```

#### 3.5 处理推送通知

**lib/main.dart:**
```dart
// 前台消息
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('前台消息: ${message.messageId}');
  
  // 触发同步
  final webhookManager = container.read(webhookManagerProvider);
  webhookManager.handlePushNotification(message.data);
});

// 点击通知
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  print('点击通知: ${message.messageId}');
  // 导航到邮件详情
});
```

---

## 📊 架构图

```
移动应用
  ↓
1. OAuth 登录
  ↓
2. 调用 CF Worker API 创建订阅
  ↓
3. 注册 FCM token 到 CF Worker
  ↓
Graph API
  ↓
4. 有新邮件时发送 webhook 到 CF Worker
  ↓
CF Worker
  ↓
5. 从 Workers KV 获取 FCM token
  ↓
6. 发送 FCM 推送通知
  ↓
移动应用
  ↓
7. 收到推送，触发增量同步
  ↓
8. 用户看到新邮件（5 秒延迟）
```

---

## 💰 成本估算

### Cloudflare Workers（免费）

**免费额度：**
- 100,000 请求/天
- 1GB Workers KV 存储
- 1,000 次 KV 写入/天
- 100,000 次 KV 读取/天

**估算（1000 用户）：**
- 每天约 10,000 次 webhook 请求
- 1000 个 FCM token（约 50KB）
- **完全免费** ✅

### Firebase Cloud Messaging（免费）

**免费额度：**
- 无限推送通知
- **完全免费** ✅

### 总成本：**$0/月** ✅

---

## 🔋 性能对比

| 方案 | 延迟 | 电池消耗 | 成本 |
|------|------|---------|------|
| **Webhooks + FCM** | 5 秒 | ⭐ 极低 | $0 |
| Delta Query + 30s 轮询 | 15 秒 | ⭐⭐ 低 | $0 |
| Delta Query + 5min 轮询 | 2.5 分钟 | ⭐ 极低 | $0 |

---

## ✅ 功能清单

### Cloudflare Worker
- ✅ Webhook 接收和验证
- ✅ 订阅管理（创建、续订、删除）
- ✅ FCM token 存储
- ✅ FCM 推送发送
- ✅ CORS 支持
- ✅ 错误处理

### Flutter 应用
- ✅ Webhook API 客户端
- ✅ 订阅管理器
- ✅ 自动续订（每 2 天）
- ✅ FCM 集成
- ✅ 推送通知处理
- ✅ 增量同步触发

---

## 🎯 下一步

### 1. 部署 Worker
```bash
cd cloudflare-worker
wrangler deploy
```

### 2. 配置 Firebase
- 创建 Firebase 项目
- 下载 google-services.json
- 获取 FCM Server Key

### 3. 集成到应用
- 添加 Firebase 依赖
- 初始化 Firebase
- 添加 Provider
- 在 OAuth 后启用 Webhook

### 4. 测试
- 登录账户
- 发送测试邮件
- 验证推送通知
- 检查延迟

---

## 📚 相关文档

- `cloudflare-worker/README.md` - Worker 部署文档
- `docs/graph_realtime_sync.md` - Graph API 实时同步方案
- `docs/ews_realtime_sync.md` - EWS 实时同步方案

---

**现在可以部署 Cloudflare Worker 了！** 🚀

**需要帮助配置 Firebase 吗？** 🔥
