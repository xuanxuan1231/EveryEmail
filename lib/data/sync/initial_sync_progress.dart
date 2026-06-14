enum InitialSyncStage {
  connecting,
  listingFolders,
  savingFolders,
  syncingInbox,
  savingMessages,
  updatingCursor,
  enablingRealtime,
  complete,
}

class InitialSyncProgress {
  const InitialSyncProgress({
    required this.stage,
    required this.progress,
    this.currentFolderName,
    this.folderIndex,
    this.folderCount,
    this.fetchedMessages = 0,
    this.savedMessages = 0,
    this.updatedMessages = 0,
    this.removedMessages = 0,
    this.statusMessage,
  }) : assert(progress >= 0.0 && progress <= 1.0);

  final InitialSyncStage stage;

  /// Normalized progress in the 0.0-1.0 range.
  final double progress;
  final String? currentFolderName;
  final int? folderIndex;
  final int? folderCount;
  final int fetchedMessages;
  final int savedMessages;
  final int updatedMessages;
  final int removedMessages;
  final String? statusMessage;

  InitialSyncProgress copyWith({
    InitialSyncStage? stage,
    double? progress,
    String? currentFolderName,
    int? folderIndex,
    int? folderCount,
    int? fetchedMessages,
    int? savedMessages,
    int? updatedMessages,
    int? removedMessages,
    String? statusMessage,
  }) {
    return InitialSyncProgress(
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      currentFolderName: currentFolderName ?? this.currentFolderName,
      folderIndex: folderIndex ?? this.folderIndex,
      folderCount: folderCount ?? this.folderCount,
      fetchedMessages: fetchedMessages ?? this.fetchedMessages,
      savedMessages: savedMessages ?? this.savedMessages,
      updatedMessages: updatedMessages ?? this.updatedMessages,
      removedMessages: removedMessages ?? this.removedMessages,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

typedef InitialSyncProgressCallback =
    void Function(InitialSyncProgress progress);
