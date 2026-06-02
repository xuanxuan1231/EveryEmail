import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/fcm_bootstrap.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // bootstrap 是 UI 真正依赖的初始化；Firebase / FCM 由 FcmBootstrap 在 runApp 之后异步处理，
  // 否则 Play Services 异常或离线时会让首屏黑屏。
  final result = await bootstrap();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(result.database),
      ],
      child: const FcmBootstrap(child: EveryMailApp()),
    ),
  );
}
