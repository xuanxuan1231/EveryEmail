import '../../domain/enums/account_enums.dart';
import '../../domain/models/mailbox_folder.dart';
import '../../domain/models/message_envelope.dart';
import '../../domain/models/message_ref.dart';
import '../../domain/models/mime_content.dart';
import 'sync_types.dart';

/// 统一邮件后端抽象——本应用的架构基石。
///
/// IMAP（enough_mail）与 Microsoft Graph（REST）各自实现此接口，
/// 返回**归一化领域模型**。仓储层与 UI 只依赖此接口，不感知数据来自哪种协议。
///
/// 约定：
/// - 所有方法在网络异常时抛出 [MailBackendException]（或其子类）。
/// - [connect] 必须在其他操作前成功调用一次。
/// - 标志/文件夹语义已在实现内归一化（见 MessageFlag / FolderType）。
abstract interface class MailBackend {
  /// 后端对应的账户类型。
  AccountType get type;

  /// 是否支持服务端推送长连接（IMAP IDLE = true；Graph = false，用轮询）。
  bool get supportsIdle;

  /// 建立连接 / 校验凭据。IMAP：登录；Graph：验证 token + 探测端点。
  Future<void> connect();

  /// 释放连接资源。
  Future<void> disconnect();

  /// 列出全部文件夹（已归一化语义角色）。
  Future<List<MailboxFolder>> listFolders();

  /// 分页拉取信封（按日期/UID 倒序，新→旧）。
  Future<List<MessageEnvelope>> fetchEnvelopes(
    MailboxFolder folder, {
    PageCursor cursor = PageCursor.start,
    int limit = 50,
  });

  /// 拉取单封邮件的正文与附件元数据。
  Future<MimeContent> fetchMessageContent(MessageRef ref);

  /// 下载某个附件/部件的原始字节。
  Future<List<int>> fetchAttachmentBytes(MessageRef ref, String partId);

  /// 自上次 [token] 以来的增量同步。
  Future<SyncResult> syncDelta(MailboxFolder folder, SyncToken? token);

  /// 标记已读/未读。
  Future<void> markRead(List<MessageRef> refs, {required bool read});

  /// 标记加星/取消。
  Future<void> markFlagged(List<MessageRef> refs, {required bool flagged});

  /// 移动到目标文件夹。
  Future<void> moveToFolder(List<MessageRef> refs, MailboxFolder target);

  /// 删除（移到废纸篓或永久删除，由实现决定语义）。
  Future<void> delete(List<MessageRef> refs);

  /// 监听文件夹变化。IMAP：真 IDLE 事件流；Graph：轮询 delta 包装成事件流。
  Stream<MailboxEvent> watch(MailboxFolder folder);
}

/// 后端操作异常基类。
class MailBackendException implements Exception {
  const MailBackendException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'MailBackendException: $message${cause == null ? '' : ' (cause: $cause)'}';
}

/// 鉴权失败（token 失效 / 凭据错误）——上层应触发重新登录。
class MailAuthException extends MailBackendException {
  const MailAuthException(super.message, {super.cause});
}

/// 网络/连接异常——上层可重试/退避。
class MailConnectionException extends MailBackendException {
  const MailConnectionException(super.message, {super.cause});
}
