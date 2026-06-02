/// 运行期应用配置：OAuth 客户端 ID 等需要用户自行创建并填入的值。
///
/// 这些值来自你创建的 OAuth 应用（见 docs/oauth-setup.md）。
/// 不要硬编码进版本库——通过 --dart-define 传入：
///
/// ```
/// flutter run \
///   --dart-define=GOOGLE_OAUTH_CLIENT_ID=xxxx.apps.googleusercontent.com \
///   --dart-define=MS_OAUTH_CLIENT_ID=00000000-0000-0000-0000-000000000000
/// ```
///
/// 未配置时对应账户类型的 OAuth 登录会被禁用，但通用 IMAP 仍可用。
class AppConfig {
  const AppConfig._();

  /// Google Android OAuth 客户端 ID（形如 xxxx.apps.googleusercontent.com）。
  static const String googleClientId =
      String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');

  /// Microsoft Entra ID 应用（客户端）ID（GUID）。
  static const String microsoftClientId =
      String.fromEnvironment('MS_OAUTH_CLIENT_ID');

  /// OAuth 重定向 scheme，必须与 android/app/build.gradle.kts 的
  /// appAuthRedirectScheme 以及各 OAuth 应用登记的重定向 URI 一致。
  static const String redirectScheme = 'com.everyemail.app';

  static bool get isGoogleConfigured => googleClientId.isNotEmpty;
  static bool get isMicrosoftConfigured => microsoftClientId.isNotEmpty;
}
