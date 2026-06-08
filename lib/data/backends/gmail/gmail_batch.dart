import 'dart:convert';

/// Gmail 批量响应（multipart/mixed）里的一个子响应：HTTP 状态码 + 解析出的 JSON
/// （仅 200 时有意义）。见 [parseGmailBatchResponse]。
class GmailBatchPart {
  const GmailBatchPart(this.status, this.json);

  final int status;
  final Map<String, dynamic>? json;
}

/// 从 `multipart/mixed` 的 Content-Type 头里取 boundary（去掉可选引号）。
String? gmailBatchBoundary(String contentType) =>
    RegExp(r'boundary=("?)([^";]+)\1').firstMatch(contentType)?.group(2);

/// 解析 Gmail `/batch/gmail/v1` 的 multipart/mixed 响应为**按序**的子响应列表
/// （Gmail 保证子响应与子请求同序）。每段内层是一个 HTTP 响应，body 为单个 JSON
/// 对象——内层头无花括号，故取首个 `{` 到末个 `}` 作为 body。
List<GmailBatchPart> parseGmailBatchResponse(String body, String contentType) {
  final boundary = gmailBatchBoundary(contentType);
  if (boundary == null || body.isEmpty) return const [];
  final parts = <GmailBatchPart>[];
  for (final seg in body.split('--$boundary')) {
    final s = seg.trim();
    if (s.isEmpty || s == '--') continue; // 前导段 / 结尾 "--"
    final httpIdx = s.indexOf('HTTP/');
    if (httpIdx < 0) continue;
    final inner = s.substring(httpIdx);
    final status =
        int.tryParse(
          RegExp(r'^HTTP/\d\.\d\s+(\d{3})').firstMatch(inner)?.group(1) ?? '',
        ) ??
        0;
    Map<String, dynamic>? json;
    final start = inner.indexOf('{');
    final end = inner.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        json =
            jsonDecode(inner.substring(start, end + 1)) as Map<String, dynamic>;
      } catch (_) {
        json = null;
      }
    }
    parts.add(GmailBatchPart(status, json));
  }
  return parts;
}
