package com.everyemail.app

import android.app.NotificationChannel
import android.app.NotificationChannelGroup
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.webkit.WebView
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private companion object {
        const val WEBVIEW_SNAPSHOT_CHANNEL = "com.everyemail.app/webview_snapshot"
        const val SYSTEM_SETTINGS_CHANNEL = "com.everyemail.app/system_settings"
        const val NOTIFICATION_CHANNELS_CHANNEL = "com.everyemail.app/notification_channels"

        // 兜底渠道：缺账户信息时通知仍落到一个有名字的渠道，而非 FCM 自动建的 "Misc"。
        const val FALLBACK_CHANNEL_ID = "everyemail_default"
        // 每账户「通知类别」分组与「邮件」渠道的 id 前缀；与 Worker channel_id 约定一致。
        const val ACCOUNT_GROUP_PREFIX = "account_"
        const val MAIL_CHANNEL_PREFIX = "mail_"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WEBVIEW_SNAPSHOT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "captureVisibleRect" -> captureVisibleWebViewRect(flutterEngine, call, result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_SETTINGS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNELS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncChannels" -> {
                    val accounts = call.argument<List<Map<String, String>>>("accounts") ?: emptyList()
                    syncNotificationChannels(accounts)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // 打开本应用的系统通知设置页。纯 notification 推送下，声音/震动/重要性等
    // 由系统通知渠道管理，应用内不再自管这些开关。
    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", packageName, null))
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    // 按账户同步通知渠道：每个账户一个分组（=「通知类别」，提供该账户的「允许通知」总开关），
    // 分组下挂一个「邮件」渠道。新邮件 FCM 通知由 Worker 投递到 mail_<accountId>，使系统设置里
    // 的逐账户开关真正生效。渠道须在通知到达前已存在，否则 FCM 回退到自动建的 "Misc"。
    //
    // accounts：[{id, name}]，name 为账户显示名（空则邮箱）。API < 26 无渠道概念，直接返回。
    private fun syncNotificationChannels(accounts: List<Map<String, String>>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 兜底渠道：缺账户信息的通知（Manifest 默认 channel）有个有名字的去处。
        manager.createNotificationChannel(
            NotificationChannel(
                FALLBACK_CHANNEL_ID,
                "其他通知",
                NotificationManager.IMPORTANCE_HIGH,
            )
        )

        val wantedGroupIds = mutableSetOf<String>()
        for (account in accounts) {
            val id = account["id"] ?: continue
            val name = account["name"]?.takeIf { it.isNotBlank() } ?: id
            val groupId = "$ACCOUNT_GROUP_PREFIX$id"
            wantedGroupIds.add(groupId)

            manager.createNotificationChannelGroup(NotificationChannelGroup(groupId, name))

            val mailChannel = NotificationChannel(
                "$MAIL_CHANNEL_PREFIX$id",
                "邮件",
                NotificationManager.IMPORTANCE_HIGH,
            )
            mailChannel.group = groupId
            manager.createNotificationChannel(mailChannel)
        }

        // 清理已移除账户：删掉 account_ 前缀但已不在集合中的分组（连带删其下渠道）。
        for (group in manager.notificationChannelGroups) {
            if (group.id.startsWith(ACCOUNT_GROUP_PREFIX) && group.id !in wantedGroupIds) {
                manager.deleteNotificationChannelGroup(group.id)
            }
        }
    }

    private fun captureVisibleWebViewRect(
        flutterEngine: FlutterEngine,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val identifier = call.longArgument("webViewIdentifier")
        if (identifier == null) {
            result.error("missing_webview_identifier", "Missing WebView identifier.", null)
            return
        }

        val webView = WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, identifier)
        if (webView == null) {
            result.error("webview_not_found", "No WebView found for identifier $identifier.", null)
            return
        }

        webView.post {
            try {
                val bytes = drawVisibleRectToPng(webView, call)
                result.success(bytes)
            } catch (error: Throwable) {
                result.error("webview_snapshot_failed", error.message, null)
            }
        }
    }

    private fun drawVisibleRectToPng(webView: WebView, call: MethodCall): ByteArray? {
        val viewWidth = webView.width
        val viewHeight = webView.height
        if (viewWidth <= 0 || viewHeight <= 0) return null

        val requestedLeft = call.doubleArgument("cropLeft")?.roundToInt() ?: 0
        val requestedTop = call.doubleArgument("cropTop")?.roundToInt() ?: 0
        val requestedWidth = call.doubleArgument("width")?.roundToInt() ?: viewWidth
        val requestedHeight = call.doubleArgument("height")?.roundToInt() ?: viewHeight

        val left = requestedLeft.coerceIn(0, max(0, viewWidth - 1))
        val top = requestedTop.coerceIn(0, max(0, viewHeight - 1))
        val width = min(max(1, requestedWidth), viewWidth - left)
        val height = min(max(1, requestedHeight), viewHeight - top)
        if (width <= 0 || height <= 0) return null

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.TRANSPARENT)
        canvas.translate(-left.toFloat(), -top.toFloat())
        webView.draw(canvas)

        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
        bitmap.recycle()
        return output.toByteArray()
    }

    private fun MethodCall.longArgument(name: String): Long? {
        return (argument<Any>(name) as? Number)?.toLong()
    }

    private fun MethodCall.doubleArgument(name: String): Double? {
        return (argument<Any>(name) as? Number)?.toDouble()
    }
}
