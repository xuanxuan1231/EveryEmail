import 'package:flutter/widgets.dart';

import '../data/local/database/app_database.dart';
import '../data/local/file_store.dart';

/// 应用启动初始化结果。
class BootstrapResult {
  const BootstrapResult({required this.database});

  /// 已打开的数据库实例（注入 [databaseProvider]）。
  final AppDatabase database;
}

/// 应用启动初始化：初始化数据库与文件存储。
Future<BootstrapResult> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  await FileStore.init();

  return BootstrapResult(database: db);
}
