import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'webview_platform_bootstrap.dart';

/// 预热平台 WebView 引擎。
///
/// 首次创建 WebView（尤其 Android Chromium）有一次性初始化开销：加载 WebView
/// 实现库、拉起渲染进程。冷启动后在后台创建一个最小 [WebViewController] 并加载
/// 空白文档，把这笔成本提前付清，使首次打开邮件详情时正文渲染更快。
///
/// 仅预热引擎，**不**改动 [MessageHtmlView] 的控制器创建时序。预热是纯优化：
/// 在不支持 WebView 的平台（桌面/测试）静默忽略，不影响功能。本组件不渲染额外
/// UI，仅透传 [child]（与 FcmBootstrap / RealtimeSyncCoordinator 同构）。
class WebViewWarmer extends StatefulWidget {
  const WebViewWarmer({required this.child, super.key});

  final Widget child;

  @override
  State<WebViewWarmer> createState() => _WebViewWarmerState();
}

class _WebViewWarmerState extends State<WebViewWarmer> {
  /// 持有预热控制器至 app 生命周期结束：保持引擎/渲染进程温热。
  WebViewController? _warmController;

  @override
  void initState() {
    super.initState();
    // 首帧之后再预热，避免与首屏渲染争抢资源。
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmUp());
  }

  void _warmUp() {
    if (!mounted || _warmController != null) return;
    try {
      ensureWebViewPlatformRegistered();
      // 构造控制器即触发原生 WebView 实例化（昂贵的一次性初始化）；加载空白
      // 文档让引擎完成首次解析。无需挂载 WebViewWidget——库加载是进程级的。
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..loadHtmlString('<!doctype html><html><body></body></html>');
      _warmController = controller;
    } catch (_) {
      // 平台不支持 WebView：忽略。详情页会走自身的不可用态。
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
