# OAuth 调试增强 - 完成

## ✅ 已添加增强版调试日志

现在 OAuth 服务会输出详细的配置信息和错误详情。

---

## 📊 新增的日志输出

### OAuth 配置信息

```
=== OAuth Service ===
客户端 ID: 12345678-1234-1234-1234-123456789abc
重定向 URL: com.everyemail.app://oauth2redirect
授权端点: https://login.microsoftonline.com/common/oauth2/v2.0/authorize
令牌端点: https://login.microsoftonline.com/common/oauth2/v2.0/token
权限范围: Mail.ReadWrite, Mail.Send, User.Read, offline_access, openid, email, profile
额外参数: {prompt: select_account}
```

### 错误详情

```
=== OAuth Service 错误 ===
异常类型: PlatformException
异常详情: PlatformException(authorize_failed, Failed to authorize, ...)
```

---

## 🔍 常见错误及解决方案

### 错误 1: `authorize_failed`

**完整错误：**
```
PlatformException(authorize_failed, Failed to authorize, ...)
```

**可能原因：**
1. 重定向 URI 不匹配
2. 客户端 ID 错误
3. Azure 应用配置问题

**解决方法：**
1. 检查 Azure 应用的重定向 URI 是否为 `com.everyemail.app://oauth2redirect`
2. 检查平台类型是否为"移动和桌面应用程序"
3. 检查客户端 ID 是否正确（GUID 格式）

---

### 错误 2: `authorize_and_exchange_code_failed`

**完整错误：**
```
PlatformException(authorize_and_exchange_code_failed, ...)
```

**可能原因：**
1. 授权成功但令牌交换失败
2. 客户端 ID 或密钥配置问题

**解决方法：**
1. 确认 Azure 应用类型为"公共客户端"
2. 不要配置客户端密钥（移动应用不需要）

---

### 错误 3: `User cancelled flow`

**完整错误：**
```
PlatformException(authorize_failed, User cancelled flow, ...)
```

**原因：** 用户取消了登录

**解决方法：** 这是正常的，用户可以重新尝试

---

### 错误 4: `No browser available`

**完整错误：**
```
PlatformException(authorize_failed, No browser available, ...)
```

**原因：** 设备上没有浏览器

**解决方法：** 安装 Chrome 或其他浏览器

---

## 🚀 下一步

1. **停止当前应用**（如果正在运行）

2. **重新运行应用：**
   ```bash
   flutter run --dart-define=MS_OAUTH_CLIENT_ID=你的客户端ID
   ```

3. **尝试添加 Microsoft 账号**

4. **查看控制台输出**
   - 会显示完整的 OAuth 配置
   - 会显示详细的错误信息

5. **将日志发给我**
   - 包括 `=== OAuth Service ===` 部分
   - 包括 `=== OAuth Service 错误 ===` 部分

---

## 📋 检查清单

在重新运行前，确认：

- [ ] Azure 应用已创建
- [ ] 客户端 ID 格式正确（GUID）
- [ ] 重定向 URI 为 `com.everyemail.app://oauth2redirect`
- [ ] 平台类型为"移动和桌面应用程序"
- [ ] API 权限已添加
- [ ] 使用 `--dart-define` 传入客户端 ID

---

## 💡 提示

如果看到 `authorize_failed` 错误，最常见的原因是：

1. **重定向 URI 不匹配**
   - Azure 配置：`com.everyemail.app://oauth2redirect`
   - 代码配置：`com.everyemail.app://oauth2redirect`
   - 必须完全一致（包括大小写）

2. **平台类型错误**
   - 必须是"移动和桌面应用程序"
   - 不是"Web"或"单页应用程序"

---

**重新运行应用，查看详细日志！** 🔍
