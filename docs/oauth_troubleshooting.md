# OAuth 登录失败诊断指南

## 问题：直接显示登录失败，没有打开浏览器

这个问题通常由以下几个原因引起：

---

## 🔍 诊断步骤

### 1. 检查客户端 ID 是否正确传入

**问题：** 客户端 ID 未配置或格式错误

**检查方法：**

在 `lib/features/onboarding/oauth_page.dart` 的 `_startOAuth` 方法开始处添加调试代码：

```dart
Future<void> _startOAuth() async {
  if (_isAuthenticating) return;

  // 添加调试代码
  final config = OAuthProviders.microsoft();
  debugPrint('=== OAuth 配置检查 ===');
  debugPrint('客户端 ID: ${config?.clientId ?? "未配置"}');
  debugPrint('重定向 URI: ${config?.redirectUrl ?? "未配置"}');
  debugPrint('是否已配置: ${AppConfig.isMicrosoftConfigured}');
  
  setState(() {
    _isAuthenticating = true;
    _errorMessage = null;
  });
  
  // ... 其余代码
}
```

**运行应用并查看日志：**
```bash
flutter run --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID
```

**预期输出：**
```
=== OAuth 配置检查 ===
客户端 ID: 12345678-1234-1234-1234-123456789abc
重定向 URI: com.everyemail.app://oauth2redirect
是否已配置: true
```

**如果显示"未配置"：**
- 检查 `--dart-define` 参数是否正确
- 检查客户端 ID 格式（应该是 GUID 格式）
- 确认没有多余的空格或引号

---

### 2. 检查错误消息

**修改 OAuth 页面以显示详细错误：**

在 `lib/features/onboarding/oauth_page.dart` 中：

```dart
} catch (e) {
  // 添加详细的错误日志
  debugPrint('=== OAuth 错误详情 ===');
  debugPrint('错误类型: ${e.runtimeType}');
  debugPrint('错误消息: $e');
  if (e is Exception) {
    debugPrint('异常详情: ${e.toString()}');
  }
  
  setState(() {
    _isAuthenticating = false;
    _errorMessage = e.toString();
  });
}
```

---

### 3. 检查 flutter_appauth 依赖

**检查 pubspec.yaml：**
```bash
grep flutter_appauth pubspec.yaml
```

**预期输出：**
```yaml
flutter_appauth: ^7.0.1  # 或更高版本
```

**如果没有或版本过低：**
```bash
flutter pub add flutter_appauth
flutter pub get
```

---

### 4. 检查 Android 配置

**检查 AndroidManifest.xml：**
```bash
cat android/app/src/main/AndroidManifest.xml | grep -A 5 "appAuthRedirectScheme"
```

**应该包含：**
```xml
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

**如果没有，需要添加到 `<application>` 标签内。**

---

### 5. 检查网络权限

**检查 AndroidManifest.xml：**
```bash
grep "INTERNET" android/app/src/main/AndroidManifest.xml
```

**应该包含：**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

---

### 6. 常见错误及解决方案

#### 错误 1：客户端 ID 未配置

**错误消息：**
```
账户类型 AccountType.microsoftGraph 未配置 OAuth（请检查 client id 是否通过 --dart-define 传入）
```

**解决方法：**
```bash
# 确保使用正确的参数运行
flutter run --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID

# 或者在 VS Code 的 launch.json 中配置：
{
  "configurations": [
    {
      "name": "everyemail",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID"
      ]
    }
  ]
}
```

#### 错误 2：重定向 URI 不匹配

**错误消息：**
```
AADSTS50011: The redirect URI specified in the request does not match
```

**解决方法：**
1. 检查 Azure 应用的重定向 URI 配置
2. 确保是：`com.everyemail.app://oauth2redirect`
3. 确保平台类型是"移动和桌面应用程序"

#### 错误 3：flutter_appauth 初始化失败

**错误消息：**
```
PlatformException(authorize_failed, ...)
```

**解决方法：**
```bash
# 清理并重新构建
flutter clean
flutter pub get
flutter run --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID
```

#### 错误 4：Chrome Custom Tabs 不可用

**错误消息：**
```
No browser available
```

**解决方法：**
- 确保设备上安装了 Chrome 或其他浏览器
- 在模拟器上，确保 Google Play 服务已安装

---

## 🔧 完整的调试版本

创建一个调试版本的 OAuth 页面：

```dart
Future<void> _startOAuth() async {
  if (_isAuthenticating) return;

  setState(() {
    _isAuthenticating = true;
    _errorMessage = null;
  });

  try {
    // 1. 检查配置
    debugPrint('=== 开始 OAuth 流程 ===');
    debugPrint('账户类型: ${widget.accountType}');
    debugPrint('邮箱: ${widget.email}');
    
    final config = OAuthProviders.forType(widget.accountType);
    if (config == null) {
      throw Exception('OAuth 配置未找到。请检查：\n'
          '1. 是否传入了 --dart-define=MS_OAUTH_CLIENT_ID\n'
          '2. 客户端 ID 格式是否正确（GUID 格式）');
    }
    
    debugPrint('客户端 ID: ${config.clientId}');
    debugPrint('重定向 URI: ${config.redirectUrl}');
    debugPrint('权限范围: ${config.scopes.join(", ")}');
    
    // 2. 执行 OAuth 登录
    debugPrint('调用 OAuth 服务...');
    final oauthService = ref.read(oauthServiceProvider);
    final tokens = await oauthService.authorize(widget.accountType);
    
    debugPrint('OAuth 成功！');
    debugPrint('Access Token: ${tokens.accessToken.substring(0, 20)}...');
    debugPrint('Refresh Token: ${tokens.refreshToken != null ? "已获取" : "未获取"}');

    if (tokens.refreshToken == null) {
      throw Exception('未获取到 refresh token，无法保存账户');
    }

    // 3. 保存账户
    final tokenStore = ref.read(tokenStoreProvider);
    final db = ref.read(databaseProvider);
    
    final accountId = generateId();
    final secretRef = 'account_$accountId';

    await tokenStore.writeRefreshToken(secretRef, tokens.refreshToken!);

    final displayName = widget.accountType == AccountType.gmailOAuth
        ? 'Gmail'
        : 'Microsoft';

    await db.accountDao.insertAccount(
      AccountsCompanion.insert(
        id: accountId,
        email: widget.email,
        displayName: displayName,
        accountType: widget.accountType,
        authType: AuthType.oauth,
        secretRef: Value(secretRef),
        colorValue: Value(_generateAccountColor()),
      ),
    );

    debugPrint('账户保存成功！');

    // 4. 导航到同步配置页面
    if (mounted) {
      context.push('/onboarding/sync-config?email=${Uri.encodeComponent(widget.email)}&accountId=${Uri.encodeComponent(accountId)}');
    }
  } catch (e, stackTrace) {
    debugPrint('=== OAuth 错误 ===');
    debugPrint('错误类型: ${e.runtimeType}');
    debugPrint('错误消息: $e');
    debugPrint('堆栈跟踪: $stackTrace');
    
    setState(() {
      _isAuthenticating = false;
      _errorMessage = '登录失败：$e\n\n'
          '请检查：\n'
          '1. 客户端 ID 是否正确配置\n'
          '2. Azure 应用的重定向 URI 是否为 com.everyemail.app://oauth2redirect\n'
          '3. 网络连接是否正常';
    });
  }
}
```

---

## 📋 检查清单

运行应用前，确认以下所有项：

- [ ] 已创建 Azure 应用并获取客户端 ID
- [ ] 客户端 ID 格式正确（GUID 格式：`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`）
- [ ] Azure 应用的重定向 URI 配置为 `com.everyemail.app://oauth2redirect`
- [ ] Azure 应用的平台类型是"移动和桌面应用程序"
- [ ] 已添加所需的 API 权限
- [ ] 使用 `--dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID` 运行应用
- [ ] `pubspec.yaml` 中包含 `flutter_appauth` 依赖
- [ ] `android/app/build.gradle.kts` 中配置了 `appAuthRedirectScheme`
- [ ] `AndroidManifest.xml` 中包含网络权限
- [ ] 设备/模拟器上安装了浏览器

---

## 🚀 快速测试

运行以下命令进行完整测试：

```bash
# 1. 清理项目
flutter clean

# 2. 获取依赖
flutter pub get

# 3. 运行应用（替换为你的客户端 ID）
flutter run --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID

# 4. 查看日志
# 在应用中尝试添加 Microsoft 账号
# 观察控制台输出的调试信息
```

---

## 📞 如果仍然失败

请提供以下信息：

1. **完整的错误消息**（从控制台复制）
2. **客户端 ID 格式**（前几位字符，不要完整 ID）
3. **Azure 应用配置截图**（重定向 URI 和平台类型）
4. **运行命令**（你使用的完整 flutter run 命令）
5. **设备信息**（真机还是模拟器，Android 版本）

---

## 💡 提示

如果你看到类似这样的错误：
```
账户类型 AccountType.microsoftGraph 未配置 OAuth
```

这意味着客户端 ID 没有正确传入。请确保：
1. 使用 `--dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID` 运行
2. 客户端 ID 没有多余的空格或引号
3. 客户端 ID 格式正确（GUID 格式）

---

**开始诊断：** 添加上面的调试代码，运行应用，查看控制台输出！
