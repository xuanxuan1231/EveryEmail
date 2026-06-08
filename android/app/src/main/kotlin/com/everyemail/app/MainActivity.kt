package com.everyemail.app

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
