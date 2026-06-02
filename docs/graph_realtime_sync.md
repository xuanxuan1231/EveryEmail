# Microsoft Graph API 实时同步方案详解

## 🎯 核心问题

**Graph API 能实现实时同步吗？**

**答案：可以，但有条件！** ⚠️

---

## 📊 Graph API 实时同步方案对比

| 方案 | 实时性 | 需要服务器 | 移动端可用 | 复杂度 | 推荐度 |
|------|--------|-----------|-----------|--------|--------|
| **Change Notifications (Webhooks)** | ⭐⭐⭐⭐⭐ | ✅ 需要 | ❌ | 高 | ⚠️ |
| **Delta Query + 短轮询** | ⭐⭐⭐⭐ | ❌ | ✅ | 低 | ✅ 推荐 |
| **Delta Query + 长轮询** | ⭐⭐⭐ | ❌ | ✅ | 中 | ✅ |
| **定时轮询** | ⭐⭐ | ❌ | ✅ | 低 | ⚠️ |

---

## 1️⃣ Change Notifications (Webhooks)

### 工作原理

```
应用 → Graph API
  ↓
创建订阅（提供 webhook URL）
  ↓
Graph API → 你的服务器（发送通知）
  ↓
你的服务器 → FCM/APNs → 移动应用
  ↓
移动应用同步邮件
```

### API 调用

**创建订阅：**
```http
POST https://graph.microsoft.com/v1.0/subscriptions
Content-Type: application/json

{
  "changeType": "created,updated,deleted",
  "notificationUrl": "https://your-server.com/api/webhook",
  "resource": "/me/mailFolders('Inbox')/messages",
  "expirationDateTime": "2024-12-31T18:23:45.9356913Z",
  "clientState": "secretClientValue"
}
```

**响应：**
```json
{
  "id": "7f105c7d-2dc5-4530-97cd-4e7ae6534c07",
  "resource": "/me/mailFolders('Inbox')/messages",
  "changeType": "created,updated,deleted",
  "clientState": "secretClientValue",
  "notificationUrl": "https://your-server.com/api/webhook",
  "expirationDateTime": "2024-12-31T18:23:45.9356913Z"
}
```

**接收通知：**
```json
{
  "value": [
    {
      "subscriptionId": "7f105c7d-2dc5-4530-97cd-4e7ae6534c07",
      "changeType": "created",
      "resource": "Users/{user-id}/Messages/{message-id}",
      "resourceData": {
        "@odata.type": "#Microsoft.Graph.Message",
        "@odata.id": "Users/{user-id}/Messages/{message-id}",
        "id": "{message-id}"
      }
    }
  ]
}
```

### 优点 ✅

- ⭐⭐⭐⭐⭐ **真正的实时推送**（几秒内）
- ✅ 最省电（不需要轮询）
- ✅ Microsoft 官方推荐

### 缺点 ❌

- ❌ **需要公网服务器**（接收 webhook）
- ❌ **需要 HTTPS 端点**
- ❌ **需要验证端点**（Graph API 会验证）
- ❌ **订阅有效期最长 3 天**（需要续期）
- ❌ **移动应用无法直接使用**

### 架构要求

```
移动应用 ← FCM/APNs ← 你的服务器 ← Graph API Webhooks
```

**需要：**
1. 后端服务器（Node.js/Python/Go 等）
2. 公网域名和 HTTPS 证书
3. FCM/APNs 推送服务
4. 数据库（存储订阅信息）

**成本：**
- 服务器费用（$5-20/月）
- 域名费用（$10-15/年）
- 开发和维护成本

---

## 2️⃣ Delta Query + 短轮询（推荐）✅

### 工作原理

```
应用每 30-60 秒调用一次 Delta Query
  ↓
只返回变更的邮件（增量）
  ↓
应用更新本地数据库
  ↓
用户看到新邮件
```

### API 调用

**首次调用：**
```http
GET https://graph.microsoft.com/v1.0/me/mailFolders/Inbox/messages/delta
```

**响应：**
```json
{
  "@odata.deltaLink": "https://graph.microsoft.com/v1.0/me/mailFolders/Inbox/messages/delta?$deltatoken=abc123",
  "value": [
    {
      "id": "message-1",
      "subject": "New Email",
      ...
    }
  ]
}
```

**后续调用（使用 deltaLink）：**
```http
GET https://graph.microsoft.com/v1.0/me/mailFolders/Inbox/messages/delta?$deltatoken=abc123
```

**响应（只返回变更）：**
```json
{
  "@odata.deltaLink": "https://graph.microsoft.com/v1.0/me/mailFolders/Inbox/messages/delta?$deltatoken=def456",
  "value": [
    {
      "id": "message-2",
      "subject": "Another New Email",
      ...
    },
    {
      "@removed": {
        "reason": "deleted"
      },
      "id": "message-3"
    }
  ]
}
```

### 优点 ✅

- ⭐⭐⭐⭐ **接近实时**（30-60 秒延迟）
- ✅ **不需要服务器**
- ✅ **移动端直接可用**
- ✅ **省流量**（只传输变更）
- ✅ **实现简单**
- ✅ **已经实现**（你的代码已有 Delta Query）

### 缺点 ⚠️

- ⚠️ 有延迟（30-60 秒）
- ⚠️ 比 Webhooks 耗电（但比全量轮询省很多）

### 实现代码

```dart
class GraphRealtimeSync {
  Timer? _syncTimer;
  
  // 启动实时同步（前台）
  void startRealtimeSync(AccountConfig account) {
    _syncTimer?.cancel();
    
    // 每 30 秒同步一次
    _syncTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      try {
        await syncService.syncAccount(account);
      } catch (e) {
        debugPrint('实时同步失败: $e');
      }
    });
  }
  
  // 启动后台同步
  void startBackgroundSync(AccountConfig account) {
    _syncTimer?.cancel();
    
    // 每 5 分钟同步一次
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      try {
        await syncService.syncAccount(account);
      } catch (e) {
        debugPrint('后台同步失败: $e');
      }
    });
  }
  
  // 停止同步
  void stop() {
    _syncTimer?.cancel();
  }
}
```

### 电池优化

**策略：**
```dart
// 根据应用状态调整同步频率
if (appInForeground) {
  // 前台：30-60 秒
  syncInterval = Duration(seconds: 30);
} else if (appInBackground) {
  // 后台：5-10 分钟
  syncInterval = Duration(minutes: 5);
} else {
  // 应用关闭：不同步
  stopSync();
}
```

---

## 3️⃣ Delta Query + 长轮询

### 工作原理

```
应用调用 Delta Query
  ↓
如果没有变更，等待 30 秒
  ↓
30 秒后再次检查
  ↓
有变更时立即返回
```

### 实现方式

**使用 `Prefer: wait` 头：**
```http
GET https://graph.microsoft.com/v1.0/me/mailFolders/Inbox/messages/delta?$deltatoken=abc123
Prefer: wait=30
```

**行为：**
- 如果有变更：立即返回
- 如果没有变更：等待最多 30 秒
- 30 秒后仍无变更：返回空结果

### 优点 ✅

- ⭐⭐⭐ **较低延迟**（0-30 秒）
- ✅ 不需要服务器
- ✅ 比短轮询省电

### 缺点 ⚠️

- ⚠️ Graph API 可能不支持（需要测试）
- ⚠️ 长连接可能被中断
- ⚠️ 移动网络不稳定

---

## 4️⃣ 定时轮询（不推荐）

### 工作原理

```
应用每 5 分钟调用一次 Delta Query
```

### 优点 ✅

- ✅ 实现简单
- ✅ 不需要服务器

### 缺点 ❌

- ❌ 延迟高（5 分钟）
- ❌ 用户体验差

---

## 🎯 推荐方案：Delta Query + 智能轮询

### 方案设计

```dart
class SmartSyncStrategy {
  Duration _currentInterval = Duration(seconds: 30);
  
  // 根据用户行为动态调整
  void adjustSyncInterval() {
    if (userIsActivelyReading) {
      // 用户正在阅读邮件：30 秒
      _currentInterval = Duration(seconds: 30);
    } else if (appInForeground) {
      // 应用在前台但用户不活跃：2 分钟
      _currentInterval = Duration(minutes: 2);
    } else if (appInBackground) {
      // 应用在后台：5 分钟
      _currentInterval = Duration(minutes: 5);
    } else {
      // 应用关闭：停止同步
      stopSync();
    }
  }
  
  // 指数退避（如果没有新邮件）
  void applyExponentialBackoff(bool hasNewMail) {
    if (!hasNewMail) {
      // 没有新邮件，逐渐降低频率
      _currentInterval = Duration(
        seconds: min(_currentInterval.inSeconds * 2, 300), // 最多 5 分钟
      );
    } else {
      // 有新邮件，恢复快速同步
      _currentInterval = Duration(seconds: 30);
    }
  }
}
```

### 特点

- ⭐⭐⭐⭐ **接近实时**（30 秒 - 5 分钟）
- ✅ **智能省电**（动态调整频率）
- ✅ **不需要服务器**
- ✅ **用户体验好**

---

## 📊 实际效果对比

### Webhooks（需要服务器）

```
新邮件到达 → 1-5 秒 → 用户看到通知
```

**延迟：** 1-5 秒 ⭐⭐⭐⭐⭐

---

### Delta Query + 30 秒轮询（推荐）

```
新邮件到达 → 0-30 秒 → 用户看到通知
平均延迟：15 秒
```

**延迟：** 15 秒（平均）⭐⭐⭐⭐

---

### Delta Query + 5 分钟轮询

```
新邮件到达 → 0-5 分钟 → 用户看到通知
平均延迟：2.5 分钟
```

**延迟：** 2.5 分钟（平均）⭐⭐

---

## 🔋 电池消耗对比

### Webhooks + FCM

```
电池消耗：⭐ 极低
原因：完全被动接收
```

---

### Delta Query + 30 秒轮询

```
电池消耗：⭐⭐ 低
原因：
- 每小时 120 次请求
- 使用 Delta Query（只传输变更）
- 可以动态调整频率
```

**优化后：**
```
前台活跃：30 秒（120 次/小时）
前台不活跃：2 分钟（30 次/小时）
后台：5 分钟（12 次/小时）
```

---

### 全量轮询（不推荐）

```
电池消耗：⭐⭐⭐⭐ 高
原因：每次传输所有邮件
```

---

## 🎯 最终推荐

### 方案：Delta Query + 智能轮询 ✅

**理由：**

1. ✅ **不需要服务器**（零成本）
2. ✅ **移动端直接可用**
3. ✅ **已经实现了 Delta Query**（你的代码已有）
4. ✅ **接近实时**（30 秒延迟可接受）
5. ✅ **省电**（智能调整频率）
6. ✅ **实现简单**（1-2 天）

**对比 Webhooks：**
- ⚠️ 延迟稍高（30 秒 vs 5 秒）
- ✅ 但不需要服务器（省钱省事）
- ✅ 对大多数用户来说，30 秒延迟完全可接受

---

## 🛠️ 实现步骤

### 第 1 步：创建实时同步服务

**文件：** `lib/data/sync/realtime_sync_service.dart`

```dart
class RealtimeSyncService {
  final SyncService _syncService;
  Timer? _syncTimer;
  Duration _currentInterval = Duration(seconds: 30);
  
  // 启动实时同步
  void start(AccountConfig account) {
    stop(); // 停止现有的
    
    _syncTimer = Timer.periodic(_currentInterval, (timer) async {
      try {
        final hasNewMail = await _syncService.syncAccount(account);
        _adjustInterval(hasNewMail);
      } catch (e) {
        debugPrint('同步失败: $e');
      }
    });
  }
  
  // 动态调整间隔
  void _adjustInterval(bool hasNewMail) {
    if (!hasNewMail) {
      // 没有新邮件，降低频率
      _currentInterval = Duration(
        seconds: min(_currentInterval.inSeconds * 2, 300),
      );
    } else {
      // 有新邮件，恢复快速同步
      _currentInterval = Duration(seconds: 30);
    }
    
    // 重启定时器
    start(account);
  }
  
  // 停止同步
  void stop() {
    _syncTimer?.cancel();
  }
}
```

---

### 第 2 步：集成到应用生命周期

```dart
class _HomePageState extends ConsumerState<HomePage> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRealtimeSync();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRealtimeSync();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // 应用回到前台，快速同步
        _startRealtimeSync(interval: Duration(seconds: 30));
        break;
      case AppLifecycleState.paused:
        // 应用进入后台，降低频率
        _startRealtimeSync(interval: Duration(minutes: 5));
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // 应用关闭，停止同步
        _stopRealtimeSync();
        break;
    }
  }
}
```

---

### 第 3 步：添加用户配置

```dart
// 设置页面
class SyncSettings {
  // 同步频率选项
  enum SyncFrequency {
    realtime,    // 30 秒
    fast,        // 2 分钟
    normal,      // 5 分钟
    slow,        // 15 分钟
    manual,      // 仅手动
  }
  
  SyncFrequency foregroundFrequency = SyncFrequency.realtime;
  SyncFrequency backgroundFrequency = SyncFrequency.normal;
}
```

---

## 📊 性能数据

### 30 秒轮询（推荐配置）

**网络流量：**
- 首次同步：根据邮件数量（100 封 ≈ 500KB）
- 增量同步：每次 1-5KB（无新邮件）
- 有新邮件：每封 5-20KB

**每天流量：**
```
前台 8 小时（30 秒）：960 次 × 2KB = 1.9MB
后台 16 小时（5 分钟）：192 次 × 2KB = 0.4MB
总计：约 2.3MB/天
```

**电池消耗：**
- 约 2-3% / 天（取决于设备）

---

## 🎉 结论

### Graph API 可以实现接近实时的同步！✅

**最佳方案：Delta Query + 智能轮询**

**优点：**
- ✅ 30 秒延迟（可接受）
- ✅ 不需要服务器
- ✅ 省电省流量
- ✅ 实现简单（1-2 天）
- ✅ 已有 Delta Query 基础

**对比 EWS Streaming Notifications：**
- ⚠️ 延迟稍高（30 秒 vs 5 秒）
- ✅ 但支持个人账号
- ✅ 不需要长连接
- ✅ 更稳定

**对比 Webhooks：**
- ⚠️ 延迟稍高（30 秒 vs 5 秒）
- ✅ 但不需要服务器（省钱）
- ✅ 实现简单

---

## 🚀 下一步

**我建议：**

1. **立即实现 Delta Query + 智能轮询**（1-2 天）
   - 利用现有的 Delta Query 实现
   - 添加定时同步
   - 添加智能频率调整

2. **测试效果**
   - 测试延迟
   - 测试电池消耗
   - 收集用户反馈

3. **如果需要更低延迟**
   - 再考虑 EWS 或 Webhooks

---

**要我现在开始实现 Delta Query + 智能轮询吗？** 🚀
