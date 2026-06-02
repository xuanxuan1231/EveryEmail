import 'package:drift/drift.dart';

import '../../../domain/enums/account_enums.dart';
import '../../../domain/enums/message_enums.dart';

/// 账户表。每行对应一个已添加的邮箱账户。
///
/// 密钥材料（OAuth refresh token / 密码）不存这里，存在 flutter_secure_storage，
/// 通过 [secretRef] 间接引用。
class Accounts extends Table {
  /// 内部稳定主键（UUID 字符串）。
  TextColumn get id => text()();

  TextColumn get email => text()();
  TextColumn get displayName => text()();

  /// 账户类型（gmailOAuth / microsoftGraph / genericImap）。
  IntColumn get accountType => intEnum<AccountType>()();

  /// 认证方式（oauth / password）。
  IntColumn get authType => intEnum<AuthType>()();

  /// 安全存储中密钥条目的键名（refresh token 或密码）。
  TextColumn get secretRef => text().nullable()();

  // —— IMAP 配置（genericImap / gmailOAuth 使用；microsoftGraph 为空）——
  TextColumn get imapHost => text().nullable()();
  IntColumn get imapPort => integer().nullable()();
  IntColumn get imapSocketType => intEnum<SocketType>().nullable()();

  // —— SMTP 配置 ——
  TextColumn get smtpHost => text().nullable()();
  IntColumn get smtpPort => integer().nullable()();
  IntColumn get smtpSocketType => intEnum<SocketType>().nullable()();

  /// IMAP/SMTP 登录用户名（通常即 email，但允许不同）。
  TextColumn get loginName => text().nullable()();

  /// 账户配色种子（用于多账户区分），存 ARGB。
  IntColumn get colorValue => integer().nullable()();

  /// 排序序号（多账户列表）。
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 文件夹（邮箱）表。隶属于某个账户。
class Folders extends Table {
  /// 内部稳定主键（UUID）。
  TextColumn get id => text()();

  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();

  /// 后端原生标识：IMAP 为文件夹路径（如 "INBOX/Work"），Graph 为 folderId。
  TextColumn get remoteId => text()();

  TextColumn get displayName => text()();

  /// 语义角色（inbox/sent/...）。
  IntColumn get folderType => intEnum<FolderType>()();

  /// 父文件夹（层级展示），顶层为空。
  TextColumn get parentId => text().nullable()();

  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get totalCount => integer().withDefault(const Constant(0))();

  /// 是否可被 IDLE/同步监听（如 INBOX）。
  BoolColumn get isSubscribed => boolean().withDefault(const Constant(true))();

  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 邮件信封表。一行对应一封邮件的列表级元数据（不含正文）。
class Messages extends Table {
  /// 内部稳定主键（UUID）。UI/正文/附件均以此关联。
  TextColumn get id => text()();

  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get folderId =>
      text().references(Folders, #id, onDelete: KeyAction.cascade)();

  // —— 后端身份（二选一，按 accountType 区分）——
  /// IMAP：UID。
  IntColumn get imapUid => integer().nullable()();

  /// IMAP：UIDVALIDITY（变更则整文件夹失效重同步）。
  IntColumn get imapUidValidity => integer().nullable()();

  /// Graph：immutable message id。
  TextColumn get graphMessageId => text().nullable()();

  // —— 信封字段 ——
  TextColumn get subject => text().withDefault(const Constant(''))();
  TextColumn get fromName => text().nullable()();
  TextColumn get fromEmail => text().nullable()();

  /// 收件人/抄送，JSON 数组字符串（[{name,email}]）。
  TextColumn get toRecipients => text().withDefault(const Constant('[]'))();
  TextColumn get ccRecipients => text().withDefault(const Constant('[]'))();

  DateTimeColumn get date => dateTime()();

  /// 预览片段。
  TextColumn get preview => text().withDefault(const Constant(''))();

  /// 归一化标志位的位掩码（见 [MessageFlag]）。
  IntColumn get flagsBitmask => integer().withDefault(const Constant(0))();

  BoolColumn get hasAttachments =>
      boolean().withDefault(const Constant(false))();

  /// 线程键：IMAP 由 References/In-Reply-To 推导，Graph 用 conversationId。
  TextColumn get threadKey => text().nullable()();

  /// RFC822 Message-ID 头。
  TextColumn get messageIdHeader => text().nullable()();

  /// 后端独有标签（如 Gmail labels / Graph categories），JSON 数组字符串。
  TextColumn get labels => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {folderId, imapUid},
        {accountId, graphMessageId},
      ];
}

/// 邮件正文表。与 [Messages] 一对一，按需下载。
class MessageBodies extends Table {
  TextColumn get messageId =>
      text().references(Messages, #id, onDelete: KeyAction.cascade)();

  /// 纯文本正文。
  TextColumn get plainText => text().nullable()();

  /// HTML 正文。
  TextColumn get htmlBody => text().nullable()();

  /// 下载状态。
  IntColumn get fetchState => intEnum<BodyFetchState>()
      .withDefault(Constant(BodyFetchState.notDownloaded.index))();

  /// 附件元数据 JSON 数组（[{partId,filename,mimeType,size,isInline,contentId,localPath}]）。
  /// 实际字节落文件系统，见 FileStore。
  TextColumn get attachmentsMeta => text().withDefault(const Constant('[]'))();

  DateTimeColumn get fetchedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {messageId};
}

/// 每文件夹的同步游标。与 [Folders] 一对一。
class SyncStates extends Table {
  TextColumn get folderId =>
      text().references(Folders, #id, onDelete: KeyAction.cascade)();

  // —— IMAP 游标 ——
  IntColumn get uidNext => integer().nullable()();
  IntColumn get uidValidity => integer().nullable()();

  /// CONDSTORE HIGHESTMODSEQ（增量取标志变更）。
  IntColumn get highestModSeq => integer().nullable()();

  // —— Graph 游标 ——
  /// delta query 返回的 @odata.deltaLink，下次只取增量。
  TextColumn get deltaLink => text().nullable()();

  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {folderId};
}

/// 发件箱 / 待推送的本地变更队列（乐观更新）。
///
/// 标记已读/移动/删除先写本地 + 入队，同步器再推送到后端并对账。
class OutboxOps extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();

  /// 操作类型："markRead" / "markUnread" / "flag" / "move" / "delete" / "sendDraft"。
  TextColumn get opType => text()();

  /// 操作载荷 JSON（涉及的 messageId 列表、目标 folderId 等）。
  TextColumn get payload => text().withDefault(const Constant('{}'))();

  /// 已尝试次数（用于退避/放弃）。
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  // 注：使用 autoIncrement() 的列会自动成为主键，无需重写 primaryKey。
}
