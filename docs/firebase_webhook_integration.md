# Firebase + Webhook 集成完成

## ✅ 已完成的工作

### 1. Flutter 端配置 ✅

**已完成：**
- ✅ 添加 Firebase 依赖（firebase_core, firebase_messaging）
- ✅ 配置 Android Gradle（google-services 插件）
- ✅ 初始化 Firebase
- ✅ 注册后台消息处理器
- ✅ 请求通知权限
- ✅ 添加 Webhook Provider

**修改的文件：**
- `pubspec.yaml` - 添加 Firebase 依赖
- `android/build.gradle.kts` - 添加 google-services classpath
- `android/app/build.gradle.kts` - 应用 google-services 插件
- `lib/main.dart` - 初始化 Firebase
- `lib/app/providers.dart` - 添加 Webhook Provider

---

## 🚀 下一步：配置和测试

### 第 1 步：更新 Worker URL

**文件：** `lib/app/providers.dart`

找到这一行：
```dart
workerUrl: 'https://ee-webhook.gemen.pp.ua',
```

替换为你的实际 Worker URL（从 Cloudflare 部署输出获取）。

---

### 第 2 步：在 OAuth 登录后启用 Webhook

**文件：** `lib/features/onboarding/oauth_page.dart`

在账户保存成功后（第 107 行之后），添加：

```dart
debugPrint('账户保存成功！');

// 启用 Webhook 推送
try {
  final fcmToken = await FirebaseMessaging.instance.getToken();
  
  if (fcmToken != null) {
    final webhookManager = ref.read(webhookManagerProvider);
    
    // 注册 FCM token
    await webhookManager.registerFCMToken(accountId, fcmToken);
    
    // 启用 webhook
    final account = AccountConfig(
      id: accountId,
      email: widget.email,
      displayName: displayName,
      type: widget.accountType,
      authType: AuthType.oauth,
      secretRef: Value(secretRef),
      colorValue: Value(_generateAccountColor()),
    );
    
    await webhookManager.enableWebhook(account);
    
    debugPrint('Webhook 推送已启用');
  }
} catch (e) {
  debugPrint('启用 Webhook 失败: $e');
  // 失败不影响正常使用，会回退到轮询模式
}

// 5. 导航到同步配置页面
```

---

### 第 3 步：处理推送通知

**文件：** `lib/app/app.dart` 或 `lib/main.dart`

在 `main()` 函数中，Firebase 初始化之后添加：

```dart
// 前台消息处理
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  debugPrint('前台消息: ${message.messageId}');
  debugPrint('数据: ${message.data}');
  
  // TODO: 显示应用内通知或直接触发同步
});

// 点击通知处理
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  debugPrint('点击通知: ${message.messageId}');
  // TODO: 导航到邮件详情
});
```

---

## 🧪 测试步骤

### 测试 1：检查 Firebase 初始化

```bash
flutter run --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID
```

**查看日志：**
```
FCM Token: xxxxx...
```

如果看到 FCM Token，说明 Firebase 初始化成功 ✅

---

### 测试 2：测试 OAuth 登录和 Webhook 订阅

1. 在应用中添加 Microsoft 账号
2. 完成 OAuth 登录
3. 查看日志：

**预期输出：**
```
账户保存成功！
Webhook 推送已启用
=== 启用 Webhook 推送 ===
账户: user@company.com
订阅创建成功: xxx-xxx-xxx
过期时间: 2024-xx-xx
```

---

### 测试 3：测试推送通知

1. 在另一个设备或网页版发送邮件到你的账号
2. 等待 5-10 秒
3. 查看应用是否收到推送通知

**预期行为：**
- 收到系统通知："新邮件"
- 日志显示：`前台消息: xxx` 或 `后台消息: xxx`

---

### 测试 4：检查 Worker 日志

```bash
cd cloudflare-worker
wrangler tail
```

**预期输出：**
```
Received webhook: {...}
Processing notification: created for /me/messages/xxx
FCM notification sent to user: xxx
```

---

## 🔍 故障排除

### 问题 1：Firebase 初始化失败

**错误：** `MissingPluginException` 或 `No Firebase App`

**解决：**
```bash
flutter clean
flutter pub get
flutter run
```

---

### 问题 2：没有收到推送通知

**检查清单：**
- [ ] Worker 是否部署成功？
- [ ] Worker URL 是否正确配置？
- [ ] FCM token 是否注册成功？
- [ ] Webhook 订阅是否创建成功？
- [ ] Service Account JSON 是否正确配置？
- [ ] Firebase 项目 ID 是否正确？

**调试步骤：**
1. 检查 Worker 日志：`wrangler tail`
2. 检查应用日志：查看 `debugPrint` 输出
3. 手动测试 Worker：
   ```bash
   curl https://ee-webhook.gemen.pp.ua/health
   ```

---

### 问题 3：Webhook 订阅创建失败

**错误：** `Failed to create subscription`

**可能原因：**
- Worker URL 不可访问
- Access token 过期
- Graph API 权限不足

**解决：**
1. 检查 Worker 是否可访问
2. 检查 OAuth 权限是否包含 `Mail.ReadWrite`
3. 查看详细错误日志

---

## 📊 性能监控

### Cloudflare Dashboard

访问 Cloudflare Dashboard 查看：
- 请求数量
- 错误率
- 响应时间

### Firebase Console

访问 Firebase Console 查看：
- 推送通知发送数量
- 推送通知成功率

---

## 🎯 完成检查清单

- [ ] Firebase 依赖已添加
- [ ] google-services.json 已配置
- [ ] Firebase 初始化成功
- [ ] FCM Token 获取成功
- [ ] Worker URL 已配置
- [ ] OAuth 登录后启用 Webhook
- [ ] 推送通知处理已添加
- [ ] 测试推送通知成功

---

## 📚 相关文档

- `cloudflare-worker/README.md` - Worker 部署文档
- `docs/webhook_implementation_complete.md` - 完整实现文档
- `docs/fcm_v1_migration.md` - FCM v1 API 说明

---

**现在可以测试完整的实时推送功能了！** 🎉

