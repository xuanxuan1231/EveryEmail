import 'package:flutter/widgets.dart';

import '../data/local/database/app_database.dart';
import '../data/local/file_store.dart';
import '../data/settings/app_font_settings.dart';

/// 应用启动初始化结果。
class BootstrapResult {
  const BootstrapResult({required this.database, required this.appFont});

  /// 已打开的数据库实例（注入 [databaseProvider]）。
  final AppDatabase database;

  /// 持久化的应用字体（注入 [appFontProvider]，首帧即用，避免字体闪烁）。
  final AppFont appFont;
}

/// 应用启动初始化：初始化数据库与文件存储。
Future<BootstrapResult> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  await FileStore.init();
  final appFont = await AppFontSettings.read();

  return BootstrapResult(database: db, appFont: appFont);
}
