import 'package:shared_preferences/shared_preferences.dart';

/// 应用字体选择。
enum AppFont {
  /// 系统默认字体（Android 12+ 的 Google Sans，回退 Roboto）。
  system,

  /// 随应用打包的 Google Sans Flex 可变字体，代替系统字体。
  googleSansFlex,
}

/// 应用字体的持久化设置（SharedPreferences，与 [ImapRealtimeSettings] 一致的存储方式）。
///
/// 默认 [AppFont.system]；用户可在设置页切到 [AppFont.googleSansFlex]。
class AppFontSettings {
  const AppFontSettings._();

  static const String _key = 'app.font';

  static AppFont _parse(String? raw) {
    return raw == 'googleSansFlex' ? AppFont.googleSansFlex : AppFont.system;
  }

  static String _encode(AppFont font) {
    return font == AppFont.googleSansFlex ? 'googleSansFlex' : 'system';
  }

  static Future<AppFont> read() async {
    final prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(_key));
  }

  static Future<void> write(AppFont font) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(font));
  }
}
