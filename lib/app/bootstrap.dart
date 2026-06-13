import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/local/database/app_database.dart';
import '../data/local/file_store.dart';
import '../data/settings/app_font_settings.dart';
import '../data/settings/display_settings.dart';
import '../data/settings/remote_image_trust.dart';

/// 应用启动初始化结果。
class BootstrapResult {
  const BootstrapResult({
    required this.database,
    required this.appFont,
    required this.displaySettings,
    required this.remoteImageTrust,
    required this.packageInfo,
  });

  /// 已打开的数据库实例（注入 [databaseProvider]）。
  final AppDatabase database;

  /// 持久化的应用字体（注入 [appFontProvider]，首帧即用，避免字体闪烁）。
  final AppFont appFont;

  /// 持久化的显示设置（注入 [displaySettingsProvider]，首帧即用）。
  final DisplaySettings displaySettings;

  /// 持久化的远程图片信任设置（注入 [remoteImageTrustProvider]）。
  final RemoteImageTrust remoteImageTrust;

  /// 应用包信息（版本号、构建号等，注入 [packageInfoProvider]）。
  final PackageInfo packageInfo;
}

/// 应用启动初始化：初始化数据库与文件存储。
Future<BootstrapResult> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  await FileStore.init();
  final appFont = await AppFontSettings.read();
  final displaySettings = await DisplaySettingsStore.read();
  final remoteImageTrust = await RemoteImageTrustStore.read();
  final packageInfo = await PackageInfo.fromPlatform();

  return BootstrapResult(
    database: db,
    appFont: appFont,
    displaySettings: displaySettings,
    remoteImageTrust: remoteImageTrust,
    packageInfo: packageInfo,
  );
}
