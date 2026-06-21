/// 文件夹的语义角色。用于在 UI 中用统一图标/排序呈现，
/// 屏蔽 IMAP 特殊用途标志（\Sent 等）与 Graph 已知文件夹名的差异。
enum FolderType { inbox, sent, drafts, trash, spam, archive, custom }

/// 归一化的邮件标志位。IMAP 的 \Seen/\Flagged/\Answered/\Draft/\Deleted
/// 与 Graph 的 isRead/flag/isDraft 都映射到这一组。
enum MessageFlag { seen, flagged, answered, draft, deleted }

/// 邮件正文/附件在本地的下载状态。
enum BodyFetchState {
  /// 仅有信封，正文未下载。
  notDownloaded,

  /// 正文已下载，附件可能未下载。
  partial,

  /// 正文与附件均已下载。
  full,
}

/// 发送队列任务状态。
enum SendTaskStatus {
  /// 等待发送（新建或等待重试）。
  queued,

  /// 正在发送。
  sending,

  /// 发送失败（需用户关注 / 手动重试）。
  failed,
}

/// 草稿同步队列任务状态。
enum DraftSyncTaskStatus {
  /// 等待同步或等待下一次自动重试。
  queued,

  /// 正在同步。
  syncing,

  /// 同步失败。若账户开启自动重试，到达 nextAttemptAt 后会再次尝试。
  failed,
}
