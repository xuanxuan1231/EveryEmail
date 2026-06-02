// Cloudflare Worker for Microsoft Graph Webhooks
// 接收 Graph API 的 webhook 通知并推送到移动应用

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS 处理
    if (request.method === 'OPTIONS') {
      return handleCORS();
    }

    try {
      // 1. Webhook 验证端点（Graph API 订阅时会调用）
      if (request.method === 'POST' && url.searchParams.has('validationToken')) {
        console.log('Webhook validation request');
        return new Response(url.searchParams.get('validationToken'), {
          status: 200,
          headers: { 'Content-Type': 'text/plain' },
        });
      }

      // 2. 接收 webhook 通知
      if (path === '/webhook' && request.method === 'POST') {
        return await handleWebhook(request, env);
      }

      // 2b. 生命周期通知（富通知订阅推荐配置）
      if (path === '/lifecycle' && request.method === 'POST') {
        return await handleLifecycle(request, env);
      }

      // 3. 创建订阅
      if (path === '/api/subscribe' && request.method === 'POST') {
        return await handleSubscribe(request, env);
      }

      // 4. 续订订阅
      if (path === '/api/renew' && request.method === 'POST') {
        return await handleRenew(request, env);
      }

      // 5. 删除订阅
      if (path === '/api/unsubscribe' && request.method === 'POST') {
        return await handleUnsubscribe(request, env);
      }

      // 6. 注册 FCM token
      if (path === '/api/register-fcm' && request.method === 'POST') {
        return await handleRegisterFCM(request, env);
      }

      // 6b. 注销 FCM token（删除账户时清理映射）
      if (path === '/api/unregister-fcm' && request.method === 'POST') {
        return await handleUnregisterFCM(request, env);
      }

      // 7. 健康检查
      if (path === '/health') {
        return jsonResponse({ status: 'ok', timestamp: Date.now() });
      }

      return jsonResponse({ error: 'Not Found' }, 404);
    } catch (error) {
      console.error('Error:', error);
      return jsonResponse({ error: error.message }, 500);
    }
  },
};

// 处理 webhook 通知
async function handleWebhook(request, env) {
  const body = await request.json();
  console.log('Received webhook:', JSON.stringify(body));

  // 验证 clientState（安全检查）
  const notifications = body.value || [];

  for (const notification of notifications) {
    const { subscriptionId, changeType, resource, resourceData } = notification;

    console.log(`Processing notification: ${changeType} for ${resource}`);

    // 只对“新邮件到达”发通知。邮件到达后 Graph 还会连发多条 updated
    // （重点收件箱分类、垃圾判定、已读/分类标记等服务端处理），全部推送会
    // 让一封邮件炸出近 10 条通知。已读/删除等跨设备状态由 App 增量同步兜底。
    if (changeType !== 'created') {
      console.log(`Skip non-created change: ${changeType}`);
      continue;
    }

    // 从 subscriptionId 获取用户信息
    const subscription = await env.KV.get(`subscription:${subscriptionId}`, 'json');

    if (!subscription) {
      console.warn(`Subscription not found: ${subscriptionId}`);
      continue;
    }

    const { userId, accountId, clientState } = subscription;

    // 验证 clientState
    if (notification.clientState !== clientState) {
      console.warn('Invalid clientState');
      continue;
    }

    // 去重：Graph 是 at-least-once 投递，同一封邮件可能被重投多次。
    // 用 messageId 在 KV 里记一个短期标记，命中则跳过。
    const messageId = resourceData?.id;
    if (messageId) {
      const dedupKey = `seen:${accountId}:${messageId}`;
      if (await env.KV.get(dedupKey)) {
        console.log(`Duplicate notification skipped: ${messageId}`);
        continue;
      }
      await env.KV.put(dedupKey, '1', { expirationTtl: 600 }); // 10 分钟去重窗口
    }

    // 获取用户的 FCM token
    const fcmToken = await env.KV.get(`fcm:${userId}:${accountId}`);

    if (!fcmToken) {
      console.warn(`FCM token not found for user: ${userId}`);
      continue;
    }

    // 解密富通知内容拿到主题/发件人；未配置加密或解密失败则回退通用文案。
    let title = '新邮件';
    let body = '您有新邮件';
    if (notification.encryptedContent && env.ENCRYPTION_PRIVATE_KEY) {
      try {
        const message = await decryptResourceData(notification.encryptedContent, env);
        const fromAddr = message?.from?.emailAddress;
        title = fromAddr?.name || fromAddr?.address || title;
        body = message?.subject || message?.bodyPreview || body;
      } catch (error) {
        console.error('Failed to decrypt resource data:', error);
      }
    }

    // 发送推送通知
    try {
      await sendFCMNotification(fcmToken, {
        title,
        body,
        changeType,
        resource,
        messageId: messageId || '',
        accountId,
      }, env);

      console.log(`FCM notification sent to user: ${userId}`);
    } catch (error) {
      console.error('Failed to send FCM:', error);
    }
  }

  // Graph API 要求返回 202 Accepted
  return new Response('Accepted', { status: 202 });
}

// 处理生命周期通知（订阅即将过期 / 被移除等）。
async function handleLifecycle(request, env) {
  const body = await request.json().catch(() => ({}));
  const events = body.value || [];
  for (const event of events) {
    console.log(
      `Lifecycle event: ${event.lifecycleEvent} for subscription ${event.subscriptionId}`
    );
    // reauthorizationRequired / subscriptionRemoved：
    // 客户端有每 2 天的续订定时器 + 启动重建逻辑兜底，这里仅记录。
  }
  return new Response('Accepted', { status: 202 });
}

// 创建 Graph API 订阅
async function handleSubscribe(request, env) {
  const { accessToken, userId, accountId, resource } = await request.json();

  if (!accessToken || !userId || !accountId) {
    return jsonResponse({ error: 'Missing required fields' }, 400);
  }

  // 生成唯一的 clientState
  const clientState = crypto.randomUUID();

  // 订阅配置。只订阅 created：新邮件到达才推送（避免 updated 高频通知）。
  const subscription = {
    changeType: 'created',
    notificationUrl: `${env.WORKER_URL}/webhook`,
    resource: resource || '/me/mailFolders(\'Inbox\')/messages',
    expirationDateTime: getExpirationDate(3), // 3 天后过期
    clientState: clientState,
  };

  // 配置了加密证书时开启富通知：Graph 把邮件主题/发件人加密塞进 webhook，
  // Worker 解密后填进通知。未配置则降级为通用文案，推送仍可用。
  if (env.ENCRYPTION_CERTIFICATE && env.ENCRYPTION_CERTIFICATE_ID) {
    subscription.includeResourceData = true;
    subscription.encryptionCertificate = env.ENCRYPTION_CERTIFICATE;
    subscription.encryptionCertificateId = env.ENCRYPTION_CERTIFICATE_ID;
    subscription.lifecycleNotificationUrl = `${env.WORKER_URL}/lifecycle`;
  }

  // 调用 Graph API 创建订阅
  const response = await fetch('https://graph.microsoft.com/v1.0/subscriptions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(subscription),
  });

  if (!response.ok) {
    const error = await response.text();
    console.error('Failed to create subscription:', error);
    return jsonResponse({ error: 'Failed to create subscription', details: error }, response.status);
  }

  const result = await response.json();
  const subscriptionId = result.id;

  // 保存订阅信息到 KV
  await env.KV.put(
    `subscription:${subscriptionId}`,
    JSON.stringify({
      subscriptionId,
      userId,
      accountId,
      clientState,
      resource: result.resource,
      expirationDateTime: result.expirationDateTime,
      createdAt: Date.now(),
    }),
    { expirationTtl: 259200 } // 3 天
  );

  // 保存用户的订阅列表
  const userSubscriptions = await env.KV.get(`user:${userId}:subscriptions`, 'json') || [];
  userSubscriptions.push(subscriptionId);
  await env.KV.put(`user:${userId}:subscriptions`, JSON.stringify(userSubscriptions));

  console.log(`Subscription created: ${subscriptionId} for user: ${userId}`);

  return jsonResponse({
    success: true,
    subscriptionId,
    expirationDateTime: result.expirationDateTime,
  });
}

// 续订订阅
async function handleRenew(request, env) {
  const { accessToken, subscriptionId } = await request.json();

  if (!accessToken || !subscriptionId) {
    return jsonResponse({ error: 'Missing required fields' }, 400);
  }

  // 续订 3 天
  const expirationDateTime = getExpirationDate(3);

  const response = await fetch(`https://graph.microsoft.com/v1.0/subscriptions/${subscriptionId}`, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ expirationDateTime }),
  });

  if (!response.ok) {
    const error = await response.text();
    console.error('Failed to renew subscription:', error);
    return jsonResponse({ error: 'Failed to renew subscription', details: error }, response.status);
  }

  const result = await response.json();

  // 更新 KV 中的过期时间
  const subscription = await env.KV.get(`subscription:${subscriptionId}`, 'json');
  if (subscription) {
    subscription.expirationDateTime = result.expirationDateTime;
    await env.KV.put(
      `subscription:${subscriptionId}`,
      JSON.stringify(subscription),
      { expirationTtl: 259200 }
    );
  }

  console.log(`Subscription renewed: ${subscriptionId}`);

  return jsonResponse({
    success: true,
    expirationDateTime: result.expirationDateTime,
  });
}

// 删除订阅
async function handleUnsubscribe(request, env) {
  const { accessToken, subscriptionId, userId } = await request.json();

  if (!accessToken || !subscriptionId) {
    return jsonResponse({ error: 'Missing required fields' }, 400);
  }

  // 调用 Graph API 删除订阅
  const response = await fetch(`https://graph.microsoft.com/v1.0/subscriptions/${subscriptionId}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
    },
  });

  if (!response.ok && response.status !== 404) {
    const error = await response.text();
    console.error('Failed to delete subscription:', error);
    return jsonResponse({ error: 'Failed to delete subscription', details: error }, response.status);
  }

  // 从 KV 中删除
  await env.KV.delete(`subscription:${subscriptionId}`);

  // 从用户订阅列表中移除
  if (userId) {
    const userSubscriptions = await env.KV.get(`user:${userId}:subscriptions`, 'json') || [];
    const filtered = userSubscriptions.filter(id => id !== subscriptionId);
    await env.KV.put(`user:${userId}:subscriptions`, JSON.stringify(filtered));
  }

  console.log(`Subscription deleted: ${subscriptionId}`);

  return jsonResponse({ success: true });
}

// 注册 FCM token
async function handleRegisterFCM(request, env) {
  const { userId, accountId, fcmToken } = await request.json();

  if (!userId || !accountId || !fcmToken) {
    return jsonResponse({ error: 'Missing required fields' }, 400);
  }

  // 保存 FCM token
  await env.KV.put(`fcm:${userId}:${accountId}`, fcmToken);

  console.log(`FCM token registered for user: ${userId}, account: ${accountId}`);

  return jsonResponse({ success: true });
}

// 注销 FCM token（删除账户时调用，清理 KV 映射）
async function handleUnregisterFCM(request, env) {
  const { userId, accountId } = await request.json();

  if (!userId || !accountId) {
    return jsonResponse({ error: 'Missing required fields' }, 400);
  }

  await env.KV.delete(`fcm:${userId}:${accountId}`);

  console.log(`FCM token unregistered for user: ${userId}, account: ${accountId}`);

  return jsonResponse({ success: true });
}

// 发送 FCM 推送通知（使用 FCM HTTP v1 API）
async function sendFCMNotification(token, data, env) {
  // 1. 获取 OAuth 2.0 access token
  const accessToken = await getFirebaseAccessToken(env);

  // 2. 发送推送通知
  const projectId = env.FIREBASE_PROJECT_ID;
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: token,
          notification: {
            title: data.title || '新邮件',
            body: data.body || '您有新邮件',
          },
          data: {
            changeType: data.changeType,
            resource: data.resource,
            messageId: data.messageId || '',
            accountId: data.accountId,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            notification: {
              // 指定 channel：必须和客户端 Manifest meta-data + Dart 端创建的 channel 一致，
              // 否则 Android 8+ 会拒绝显示（"unknown channel"）。
              channel_id: 'everyemail_default',
              sound: 'default',
              // 不指定 icon：让 Android 回退到 application launcher icon。
              // 之前指定 'ic_notification' 但 res/ 里没有这个 drawable，FCM 会静默丢弃通知。
            },
          },
        },
      }),
    }
  );

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`FCM error: ${error}`);
  }

  return response.json();
}

// 获取 Firebase OAuth 2.0 access token
async function getFirebaseAccessToken(env) {
  // 从环境变量获取 Service Account JSON
  const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);

  // 创建 JWT
  const jwt = await createJWT(serviceAccount);

  // 交换 JWT 获取 access token
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to get access token: ${error}`);
  }

  const data = await response.json();
  return data.access_token;
}

// 创建 JWT（使用 Web Crypto API）
async function createJWT(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600; // 1 小时后过期

  // JWT Header
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };

  // JWT Payload
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: expiry,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  };

  // Base64url 编码
  const base64url = (obj) => {
    return btoa(JSON.stringify(obj))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
  };

  const encodedHeader = base64url(header);
  const encodedPayload = base64url(payload);
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  // 导入私钥
  const privateKey = await importPrivateKey(serviceAccount.private_key);

  // 签名
  const encoder = new TextEncoder();
  const data = encoder.encode(unsignedToken);
  const signature = await crypto.subtle.sign(
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    privateKey,
    data
  );

  // Base64url 编码签名
  const base64Signature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');

  return `${unsignedToken}.${base64Signature}`;
}

// 导入 RSA 私钥
async function importPrivateKey(pem) {
  // 移除 PEM 头尾和换行符
  const pemContents = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');

  // Base64 解码
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

  // 导入密钥
  return await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  );
}

// 工具函数：获取过期时间
function getExpirationDate(days) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date.toISOString();
}

// 工具函数：JSON 响应
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  });
}

// 工具函数：CORS 预检
function handleCORS() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    },
  });
}

// 解密 Graph 富通知的 encryptedContent，返回邮件资源对象（含 subject/from/bodyPreview）。
// 算法与 Microsoft 官方样例一致：RSA-OAEP 解出对称密钥 → HMAC-SHA256 校验 → AES-256-CBC 解密。
async function decryptResourceData(encryptedContent, env) {
  const { data, dataSignature, dataKey } = encryptedContent;

  // 1. RSA-OAEP 解密对称密钥（AES-256）。Graph 默认 OaepSHA1，失败再试 SHA-256。
  const encryptedKey = base64ToBytes(dataKey);
  let symmetricKey;
  let lastError;
  for (const hash of ['SHA-1', 'SHA-256']) {
    try {
      const privateKey = await importOaepKey(env.ENCRYPTION_PRIVATE_KEY, hash);
      const decrypted = await crypto.subtle.decrypt(
        { name: 'RSA-OAEP' },
        privateKey,
        encryptedKey
      );
      symmetricKey = new Uint8Array(decrypted);
      break;
    } catch (e) {
      lastError = e;
    }
  }
  if (!symmetricKey) {
    throw new Error(`RSA-OAEP decrypt failed: ${lastError}`);
  }

  const dataBytes = base64ToBytes(data);

  // 2. 校验签名：HMAC-SHA256(密文, 对称密钥) 应等于 dataSignature。
  const hmacKey = await crypto.subtle.importKey(
    'raw',
    symmetricKey,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign('HMAC', hmacKey, dataBytes);
  if (bytesToBase64(new Uint8Array(signature)) !== dataSignature) {
    throw new Error('dataSignature mismatch');
  }

  // 3. AES-256-CBC 解密，IV = 对称密钥前 16 字节。
  const aesKey = await crypto.subtle.importKey(
    'raw',
    symmetricKey,
    { name: 'AES-CBC' },
    false,
    ['decrypt']
  );
  const decrypted = await crypto.subtle.decrypt(
    { name: 'AES-CBC', iv: symmetricKey.slice(0, 16) },
    aesKey,
    dataBytes
  );

  return JSON.parse(new TextDecoder().decode(decrypted));
}

// 导入 RSA 私钥用于 OAEP 解密（区别于 importPrivateKey 的 RSASSA 签名用途）。
async function importOaepKey(pem, hash) {
  const pemContents = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binaryDer = base64ToBytes(pemContents);
  return await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSA-OAEP', hash },
    false,
    ['decrypt']
  );
}

// 工具函数：base64 → Uint8Array
function base64ToBytes(b64) {
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

// 工具函数：Uint8Array → base64
function bytesToBase64(bytes) {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}
