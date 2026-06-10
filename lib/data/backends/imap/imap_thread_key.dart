/// 从 IMAP 邮件头推导稳定的「会话根键」，供跨往来把同一会话的邮件归并到一起。
///
/// 优先取 References 链首（线程根），否则 In-Reply-To，最后退回自身 Message-ID。
/// 同一会话的所有回复，其 References 头都以同一个根 message-id 开头，故取链首即得
/// 一个在会话内稳定共享的键。
///
/// 注意：
/// - 历史上这里误存了 References 头**原文**（整条链），导致每封回复键不同、无法归并；
///   现取链首根 id 修正（见 app_database 的 v5 迁移恢复既有数据）。
/// - References 仅在邮件被完整抓取（`FetchPreference.fullWhenWithinSize` 命中小邮件）
///   时可得；体积较大的邮件可能仅退回自身 Message-ID（多为独立邮件，无需归并）。
/// - 返回 message-id 原文（含尖括号），不做大小写规整，以与既有数据/迁移保持一致。
String? deriveImapThreadKey({
  String? references,
  String? inReplyTo,
  String? messageId,
}) {
  return firstMessageId(references) ??
      firstMessageId(inReplyTo) ??
      firstMessageId(messageId);
}

/// 取头里第一个 `<...>` message-id；无尖括号时取首个空白分隔 token。空/无则返回 null。
String? firstMessageId(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final match = RegExp(r'<[^>]+>').firstMatch(trimmed);
  if (match != null) return match.group(0);

  final token = trimmed.split(RegExp(r'\s+')).first;
  return token.isEmpty ? null : token;
}
