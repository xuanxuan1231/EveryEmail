/// 运行期应用配置：OAuth 客户端 ID 等需要用户自行创建并填入的值。
///
/// 这些值来自你创建的 OAuth 应用（见 docs/oauth-setup.md）。
/// 不要硬编码进版本库——通过 --dart-define 传入：
///
/// ```
/// flutter run \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com \
///   --dart-define=GOOGLE_IOS_CLIENT_ID=yyyy.apps.googleusercontent.com \
///   --dart-define=MS_OAUTH_CLIENT_ID=00000000-0000-0000-0000-000000000000
/// ```
///
/// （GOOGLE_SERVER_CLIENT_ID = Google 的 Web 客户端 ID；GOOGLE_IOS_CLIENT_ID
/// 仅 iOS 需要。Android 凭包名+SHA-1 自动匹配，无需在代码里传 client id。）
///
/// 未配置时对应账户类型的 OAuth 登录会被禁用，但通用 IMAP 仍可用。
class AppConfig {
  const AppConfig._();

  /// Google 的 **Web** OAuth 客户端 ID（形如 xxxx.apps.googleusercontent.com）。
  /// 作为 Google Identity Services 的 `serverClientId`：原生登录拿到 server
  /// auth code 后，由 Cloudflare Worker 用这个 Web 客户端（含 secret）兑换
  /// access/refresh token。两端（Android/iOS）都用它。
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Google 的 **iOS** OAuth 客户端 ID（仅 iOS 需要，作为 google_sign_in 的
  /// `clientId`；其反向 client id 还要登记到 Info.plist 的 URL scheme）。
  /// Android 凭「包名 + SHA-1」自动匹配，无需在代码里传。
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// Microsoft Entra ID 应用（客户端）ID（GUID）。
  static const String microsoftClientId = String.fromEnvironment(
    'MS_OAUTH_CLIENT_ID',
  );

  /// OAuth 重定向 scheme，必须与 android/app/build.gradle.kts 的
  /// appAuthRedirectScheme 以及 Microsoft 登记的重定向 URI 一致。
  /// 仅 **Microsoft** 走自定义 scheme（flutter_appauth）；Google 已改用 GIS
  /// 原生流程，不再使用自定义 URI scheme 回调。
  static const String redirectScheme = 'com.everyemail.app';

  /// Cloudflare Worker 基址：Graph webhook / FCM 注册，以及 Google 的 server
  /// auth code 兑换、refresh token 刷新都打到这里。
  static const String workerBaseUrl = 'https://ee-webhook.gemen.pp.ua';

  static bool get isGoogleConfigured => googleServerClientId.isNotEmpty;
  static bool get isMicrosoftConfigured => microsoftClientId.isNotEmpty;
}
