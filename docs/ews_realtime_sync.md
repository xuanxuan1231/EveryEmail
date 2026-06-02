# Exchange Web Services (EWS) 实时同步方案

## 📋 当前状态

**问题：** 当前实现使用 Microsoft Graph API，不是 Exchange Web Services (EWS) 协议

**你的需求：** 使用 EWS 协议进行同步，支持实时推送

---

## 🔍 Exchange 协议对比

### Microsoft Graph API（当前实现）

**优点：**
- ✅ 现代化的 REST API
- ✅ Microsoft 推荐的方式
- ✅ 支持个人账号（Outlook.com）和工作账号

**缺点：**
- ❌ 实时推送需要 Webhooks（需要服务器）
- ❌ 不是传统的 Exchange 协议

**实时同步方案：**
- Webhooks（需要公网服务器）
- 定时轮询

---

### Exchange Web Services (EWS)

**优点：**
- ✅ 传统的 Exchange 协议
- ✅ 支持实时推送（Streaming Notifications）
- ✅ 不需要服务器

**缺点：**
- ⚠️ Microsoft 正在逐步淘汰 EWS
- ⚠️ 只支持 Exchange Server 和 Office 365
- ⚠️ 不支持个人 Outlook.com 账号

**实时同步方案：**
1. **Streaming Notifications** ✅ 推荐
2. **Push Notifications** （需要服务器）
3. **Pull Notifications** （轮询）

---

## 🎯 EWS Streaming Notifications（推荐）

### 工作原理

```
应用 → EWS 服务器
  ↓
创建 Streaming Subscription
  ↓
保持长连接（HTTP 长轮询）
  ↓
有新邮件时，服务器立即推送通知
  ↓
应用接收通知并同步邮件
```

### 特点

- ✅ **真正的实时推送**
- ✅ **不需要公网服务器**
- ✅ **低延迟**（几秒内收到通知）
- ✅ **省电**（不需要频繁轮询）
- ⚠️ 需要保持长连接

---

## 📊 EWS 实时同步方案对比

| 方案 | 实时性 | 需要服务器 | 复杂度 | 推荐度 |
|------|--------|-----------|--------|--------|
| **Streaming Notifications** | ⭐⭐⭐⭐⭐ | ❌ | 中 | ✅ 推荐 |
| Push Notifications | ⭐⭐⭐⭐⭐ | ✅ | 高 | ❌ |
| Pull Notifications | ⭐⭐ | ❌ | 低 | ❌ |
| Graph Webhooks | ⭐⭐⭐⭐⭐ | ✅ | 高 | ❌ |
| 定时轮询 | ⭐ | ❌ | 低 | ❌ |

---

## 🔧 EWS Streaming Notifications 实现方案

### 1. 创建订阅

**XML 请求：**
```xml
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types">
  <soap:Body>
    <Subscribe xmlns="http://schemas.microsoft.com/exchange/services/2006/messages">
      <StreamingSubscriptionRequest>
        <FolderIds>
          <t:DistinguishedFolderId Id="inbox"/>
          <t:DistinguishedFolderId Id="sentitems"/>
        </FolderIds>
        <EventTypes>
          <t:EventType>NewMailEvent</t:EventType>
          <t:EventType>ModifiedEvent</t:EventType>
          <t:EventType>DeletedEvent</t:EventType>
        </EventTypes>
      </StreamingSubscriptionRequest>
    </Subscribe>
  </soap:Body>
</soap:Envelope>
```

**响应：**
```xml
<SubscriptionId>JgBjbzI3M...</SubscriptionId>
```

---

### 2. 获取事件流

**XML 请求：**
```xml
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <GetStreamingEvents xmlns="http://schemas.microsoft.com/exchange/services/2006/messages">
      <SubscriptionIds>
        <SubscriptionId>JgBjbzI3M...</SubscriptionId>
      </SubscriptionIds>
      <ConnectionTimeout>30</ConnectionTimeout>
    </GetStreamingEvents>
  </soap:Body>
</soap:Envelope>
```

**响应（长连接）：**
```xml
<Notification>
  <SubscriptionId>JgBjbzI3M...</SubscriptionId>
  <Events>
    <NewMailEvent>
      <ItemId Id="AAMkAD..." ChangeKey="CQAAAB..."/>
      <ParentFolderId Id="AAMkAD..." ChangeKey="AQAAAA=="/>
    </NewMailEvent>
  </Events>
</Notification>
```

---

### 3. 处理通知

**收到通知后：**
1. 解析事件类型（NewMail、Modified、Deleted）
2. 获取邮件 ID
3. 同步该邮件
4. 更新 UI

---

## 🛠️ 实现需求

### 1. EWS 客户端库

**Dart/Flutter 没有官方的 EWS 库**，需要：

#### 选项 1：使用 HTTP + XML 解析（推荐）
```dart
// 使用 dio + xml 包
dependencies:
  dio: ^5.0.0
  xml: ^6.0.0
```

**优点：**
- ✅ 完全控制
- ✅ 可以精确实现需要的功能

**缺点：**
- ⚠️ 需要手动构建 XML 请求
- ⚠️ 需要手动解析 XML 响应

#### 选项 2：移植 Java/C# EWS 库
```dart
// 参考 ews-java-api 或 EWS Managed API
// 移植到 Dart
```

**优点：**
- ✅ 功能完整

**缺点：**
- ❌ 工作量大
- ❌ 维护成本高

---

### 2. 认证方式

**EWS 支持的认证：**

#### OAuth 2.0（推荐）✅
```dart
// 使用 OAuth access token
headers: {
  'Authorization': 'Bearer $accessToken',
}
```

**优点：**
- ✅ 安全
- ✅ 可以复用现有的 OAuth 实现
- ✅ Microsoft 推荐

#### Basic Authentication（已弃用）❌
```dart
// 不推荐，Microsoft 已禁用
```

---

### 3. EWS 端点

**Office 365 / Exchange Online：**
```
https://outlook.office365.com/EWS/Exchange.asmx
```

**Exchange Server（本地部署）：**
```
https://mail.company.com/EWS/Exchange.asmx
```

**自动发现（Autodiscover）：**
```
https://autodiscover.company.com/autodiscover/autodiscover.xml
```

---

## 📝 实现步骤

### 阶段 1：基础 EWS 支持

1. **创建 EWS 后端**
   - 实现 `EwsMailBackend` 类
   - 实现基本的 SOAP 请求/响应
   - 实现 OAuth 认证

2. **实现基本功能**
   - 列出文件夹
   - 获取邮件列表
   - 获取邮件内容
   - 标记已读/星标

3. **实现增量同步**
   - 使用 SyncFolderItems
   - 保存 SyncState

---

### 阶段 2：实时推送（Streaming Notifications）

1. **创建订阅**
   - 实现 Subscribe 请求
   - 保存 SubscriptionId

2. **监听事件流**
   - 实现 GetStreamingEvents 请求
   - 保持长连接
   - 解析事件通知

3. **处理通知**
   - 新邮件事件 → 同步邮件
   - 修改事件 → 更新邮件
   - 删除事件 → 删除邮件

4. **连接管理**
   - 自动重连
   - 错误处理
   - 订阅续期

---

## 🔍 关键技术点

### 1. SOAP 请求构建

```dart
class EwsClient {
  final Dio _dio;
  final String _ewsUrl;
  final AccessTokenProvider _tokenProvider;

  Future<xml.XmlDocument> sendRequest(String action, String body) async {
    final token = await _tokenProvider();
    
    final envelope = '''
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
               xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
  <soap:Header>
    <t:RequestServerVersion Version="Exchange2016"/>
  </soap:Header>
  <soap:Body>
    $body
  </soap:Body>
</soap:Envelope>
''';

    final response = await _dio.post(
      _ewsUrl,
      data: envelope,
      options: Options(
        headers: {
          'Content-Type': 'text/xml; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return xml.XmlDocument.parse(response.data);
  }
}
```

---

### 2. Streaming Notifications 监听

```dart
class EwsStreamingSubscription {
  final EwsClient _client;
  final String _subscriptionId;
  StreamController<EwsNotification>? _controller;

  Stream<EwsNotification> listen() {
    _controller = StreamController<EwsNotification>();
    _startListening();
    return _controller!.stream;
  }

  Future<void> _startListening() async {
    while (_controller != null && !_controller!.isClosed) {
      try {
        final body = '''
<m:GetStreamingEvents>
  <m:SubscriptionIds>
    <t:SubscriptionId>$_subscriptionId</t:SubscriptionId>
  </m:SubscriptionIds>
  <m:ConnectionTimeout>30</m:ConnectionTimeout>
</m:GetStreamingEvents>
''';

        final response = await _client.sendRequest('GetStreamingEvents', body);
        
        // 解析通知
        final notifications = _parseNotifications(response);
        
        for (final notification in notifications) {
          _controller!.add(notification);
        }
      } catch (e) {
        // 错误处理和重连
        await Future.delayed(Duration(seconds: 5));
      }
    }
  }

  List<EwsNotification> _parseNotifications(xml.XmlDocument doc) {
    // 解析 XML 响应
    // 提取事件类型和邮件 ID
    // ...
  }
}
```

---

### 3. 自动发现 EWS 端点

```dart
class EwsAutodiscover {
  Future<String> discoverEwsUrl(String email) async {
    final domain = email.split('@')[1];
    
    // 尝试多个 autodiscover 端点
    final urls = [
      'https://autodiscover.$domain/autodiscover/autodiscover.xml',
      'https://$domain/autodiscover/autodiscover.xml',
      'https://autodiscover.outlook.com/autodiscover/autodiscover.xml',
    ];
    
    for (final url in urls) {
      try {
        final response = await _dio.post(
          url,
          data: _buildAutodiscoverRequest(email),
        );
        
        final doc = xml.XmlDocument.parse(response.data);
        final ewsUrl = doc.findAllElements('EwsUrl').first.text;
        
        return ewsUrl;
      } catch (e) {
        continue;
      }
    }
    
    // 默认使用 Office 365 端点
    return 'https://outlook.office365.com/EWS/Exchange.asmx';
  }
}
```

---

## ⚠️ 注意事项

### 1. Microsoft 正在淘汰 EWS

**官方声明：**
> "We are retiring Basic authentication in Exchange Online for Exchange Web Services (EWS), and recommend using OAuth 2.0 authentication."

**影响：**
- ⚠️ 新功能不会添加到 EWS
- ⚠️ Microsoft 推荐使用 Graph API
- ✅ 但 EWS 仍然可用，支持 OAuth

---

### 2. 兼容性

**支持 EWS 的服务：**
- ✅ Exchange Server 2007+
- ✅ Office 365 / Exchange Online
- ❌ Outlook.com（个人账号）

**不支持 EWS 的服务：**
- ❌ Outlook.com / Hotmail.com
- ❌ Live.com

**解决方案：**
- 个人账号使用 Graph API
- 企业账号使用 EWS

---

### 3. 性能考虑

**Streaming Notifications：**
- ✅ 低延迟（1-5 秒）
- ⚠️ 需要保持长连接
- ⚠️ 可能影响电池寿命

**建议：**
- 前台时使用 Streaming Notifications
- 后台时使用定时同步
- 提供用户选项

---

## 🎯 推荐方案

### 混合方案（最佳）

```
个人账号（@outlook.com）
  → Microsoft Graph API
  → 定时轮询或 Webhooks

企业账号（@company.com）
  → 检测是否支持 EWS
  → 如果支持：使用 EWS + Streaming Notifications
  → 如果不支持：使用 Graph API
```

**优点：**
- ✅ 最大兼容性
- ✅ 企业账号有实时推送
- ✅ 个人账号也能用

---

## 📊 工作量估算

### 实现 EWS 基础功能

**时间：** 2-3 周

**任务：**
1. EWS 客户端（SOAP 请求/响应）
2. OAuth 认证集成
3. 基本邮件操作
4. 增量同步

---

### 实现 Streaming Notifications

**时间：** 1-2 周

**任务：**
1. 订阅管理
2. 事件流监听
3. 通知处理
4. 连接管理和重连

---

### 总计

**时间：** 3-5 周
**复杂度：** 中-高

---

## 🚀 下一步

### 选项 1：实现 EWS（推荐）

**如果你需要企业账号的实时推送：**
1. 我可以帮你实现 EWS 后端
2. 实现 Streaming Notifications
3. 保留 Graph API 作为备选

---

### 选项 2：改进 Graph API

**如果可以接受定时轮询：**
1. 添加定时同步（1-5 分钟）
2. 优化同步性能
3. 添加后台同步

---

### 选项 3：混合方案

**最佳方案：**
1. 企业账号使用 EWS + Streaming Notifications
2. 个人账号使用 Graph API + 定时轮询
3. 自动检测并选择最佳方案

---

## 💡 我的建议

**建议实现混合方案：**

1. **短期（1-2 周）：**
   - 为 Graph API 添加定时轮询
   - 让现有功能可用

2. **中期（3-5 周）：**
   - 实现 EWS 后端
   - 实现 Streaming Notifications
   - 自动检测并选择协议

3. **长期：**
   - 优化性能和电池使用
   - 添加用户配置选项

---

**你想采用哪个方案？我可以立即开始实现！** 🚀
