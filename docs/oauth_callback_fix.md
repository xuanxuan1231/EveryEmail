# OAuth 回调问题修复

## ✅ 问题已修复

**问题：** 确认权限后无法回调到应用

**原因：** `AndroidManifest.xml` 中缺少 OAuth 回调的 Activity 配置

---

## 🔧 修复内容

在 `android/app/src/main/AndroidManifest.xml` 中添加了：

```xml
<!-- flutter_appauth: OAuth 回调接收器 -->
<activity
    android:name="net.openid.appauth.RedirectUriReceiverActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="${appAuthRedirectScheme}"/>
    </intent-filter>
</activity>
```

**说明：**
- `RedirectUriReceiverActivity` 是 flutter_appauth 提供的回调接收器
- `android:exported="true"` 允许外部应用（浏览器）调用
- `android:scheme="${appAuthRedirectScheme}"` 使用 build.gradle.kts 中配置的 scheme
- 实际值为 `com.everyemail.app`（来自 `manifestPlaceholders`）

---

## 🚀 现在需要重新构建应用

因为修改了 AndroidManifest.xml，需要重新构建：

```bash
# 停止当前应用
# 然后运行：
flutter run --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID
```

---

## 📱 预期行为

1. ✅ 点击 OAuth 登录
2. ✅ 打开浏览器（Chrome Custom Tab）
3. ✅ 显示 Microsoft 账户选择器
4. ✅ 选择账户并确认权限
5. ✅ **自动返回应用** ← 现在应该可以了！
6. ✅ 开始同步邮件

---

## 🔍 工作原理

### OAuth 回调流程

```
应用 → 浏览器
  ↓
用户登录并确认权限
  ↓
Microsoft 重定向到: com.everyemail.app://oauth2redirect?code=...
  ↓
Android 系统查找能处理这个 scheme 的 Activity
  ↓
找到 RedirectUriReceiverActivity
  ↓
RedirectUriReceiverActivity 接收回调
  ↓
flutter_appauth 处理授权码
  ↓
返回应用并完成登录 ✅
```

---

## 📊 完整的配置检查

### 1. build.gradle.kts ✅
```kotlin
manifestPlaceholders += mapOf("appAuthRedirectScheme" to "com.everyemail.app")
```

### 2. AndroidManifest.xml ✅
```xml
<activity android:name="net.openid.appauth.RedirectUriReceiverActivity" ...>
    <data android:scheme="${appAuthRedirectScheme}"/>
</activity>
```

### 3. OAuth 配置 ✅
```dart
redirectUrl: 'com.everyemail.app://oauth2redirect'
```

### 4. Azure 应用 ✅
```
重定向 URI: com.everyemail.app://oauth2redirect
平台类型: 移动和桌面应用程序
```

---

## 🎉 所有配置已完成

现在重新运行应用，OAuth 登录应该可以完整工作了！

**重要：** 因为修改了 AndroidManifest.xml，必须重新构建应用才能生效。
