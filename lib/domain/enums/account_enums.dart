/// 账户类型，决定使用哪个 [MailBackend] 实现与认证方式。
enum AccountType {
  /// Gmail / Google Workspace —— OAuth (XOAUTH2)，邮件走 IMAP/SMTP。
  gmailOAuth,

  /// Microsoft 个人/工作账户 —— OAuth，邮件走 Microsoft Graph REST。
  microsoftGraph,

  /// 通用 IMAP/SMTP —— 密码或应用专用密码 + 自动配置。
  genericImap,
}

/// 认证方式。
enum AuthType {
  /// OAuth2：在安全存储中保存 refresh token。
  oauth,

  /// 密码 / 应用专用密码：在安全存储中保存密码。
  password,
}

/// 连接加密方式。
enum SocketType {
  /// 明文（不推荐，仅兼容老服务器）。
  plain,

  /// 隐式 TLS / SSL（如 IMAP 993、SMTP 465）。
  ssl,

  /// STARTTLS（如 IMAP 143、SMTP 587 升级加密）。
  starttls,
}
