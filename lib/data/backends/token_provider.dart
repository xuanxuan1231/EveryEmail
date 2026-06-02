/// 为后端提供有效 OAuth access token 的回调。
///
/// 实现方（OAuth 服务）负责按需用 refresh token 刷新（过期前），
/// 后端只管在每次需要鉴权时调用它取一个当前有效的 access token。
typedef AccessTokenProvider = Future<String> Function();
