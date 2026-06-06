import 'package:flutter/material.dart';

import '../../../data/local/database/app_database.dart';
import '../../../domain/enums/message_enums.dart';

/// Gmail 移动 App 风格的邮件列表项。
///
/// 保留旧的整项可点击包装，用于还没有迁移到 M3ECardList 的调用点。
/// 已迁移的列表应优先使用 [GmailMobileMessageCardContent] 作为卡片内容。
class GmailMobileMessageItem extends StatelessWidget {
  const GmailMobileMessageItem({
    required this.message,
    required this.onTap,
    this.accountEmail,
    this.accountColor,
    this.isSelected = false,
    this.onLongPress,
    this.onStarTap,
    this.showAccountLabel = false,
    super.key,
  });

  final Message message;
  final VoidCallback onTap;
  final String? accountEmail;
  final Color? accountColor;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onStarTap;
  final bool showAccountLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: GmailMobileMessageCardContent(
            message: message,
            accountEmail: accountEmail,
            accountColor: accountColor,
            isSelected: isSelected,
            onStarTap: onStarTap,
            showAccountLabel: showAccountLabel,
          ),
        ),
      ),
    );
  }
}

/// Gmail 风格邮件内容，适合作为 `M3ECardList` / `M3ECard` 的 child。
///
/// 特点（基于 Android/iOS Gmail App）：
/// - 发件人头像（48x48px）
/// - 发件人与时间同行
/// - 主题与预览独立成行
/// - 未读邮件左侧有强调色竖条
/// - 星标在右下角
class GmailMobileMessageCardContent extends StatelessWidget {
  const GmailMobileMessageCardContent({
    required this.message,
    this.accountEmail,
    this.accountColor,
    this.isSelected = false,
    this.onStarTap,
    this.showAccountLabel = false,
    super.key,
  });

  final Message message;
  final String? accountEmail;
  final Color? accountColor;
  final bool isSelected;
  final VoidCallback? onStarTap;
  final bool showAccountLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = (message.flagsBitmask & (1 << MessageFlag.seen.index)) != 0;
    final isFlagged =
        (message.flagsBitmask & (1 << MessageFlag.flagged.index)) != 0;

    return ColoredBox(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
          : Colors.transparent,
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(
              color: isRead ? Colors.transparent : theme.colorScheme.primary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: isSelected
                      ? _buildSelectedAvatar(theme)
                      : _buildAvatar(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _senderLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(message.date),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message.subject.isEmpty
                                  ? '(无主题)'
                                  : message.subject,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                                height: 1.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (message.hasAttachments) ...[
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.attach_file,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              message.preview,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: isFlagged ? '取消星标' : '星标',
                            child: InkResponse(
                              onTap: onStarTap,
                              radius: 20,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  isFlagged
                                      ? Icons.star
                                      : Icons.star_border_outlined,
                                  size: 22,
                                  color: isFlagged
                                      ? const Color(0xFFF9AB00)
                                      : theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showAccountLabel && accountEmail != null) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: accountColor ?? Colors.grey,
                              ),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text(
                                accountEmail!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: accountColor ?? Colors.grey,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAvatar(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary,
      ),
      child: Icon(Icons.check, color: theme.colorScheme.onPrimary, size: 24),
    );
  }

  Widget _buildAvatar() {
    final initial = _senderLabel[0].toUpperCase();
    final color = _generateColorFromEmail(message.fromEmail ?? _senderLabel);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String get _senderLabel {
    final name = message.fromName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = message.fromEmail?.trim();
    if (email != null && email.isNotEmpty) return email;

    return '未知发件人';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(messageDate).inDays;

    if (diff == 0) {
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? '下午' : '上午';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$period$displayHour:$minute';
    } else if (diff == 1) {
      return '昨天';
    } else if (diff < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[date.weekday - 1];
    } else if (date.year == now.year) {
      return '${date.month}月${date.day}日';
    } else {
      return '${date.year}年';
    }
  }

  /// 根据邮箱地址生成一致的颜色（Gmail 风格的柔和色）。
  Color _generateColorFromEmail(String email) {
    if (email.isEmpty) return const Color(0xFF9E9E9E);

    final hash = email.hashCode;

    const colors = [
      Color(0xFFE57373),
      Color(0xFFF06292),
      Color(0xFFBA68C8),
      Color(0xFF9575CD),
      Color(0xFF7986CB),
      Color(0xFF64B5F6),
      Color(0xFF4FC3F7),
      Color(0xFF4DD0E1),
      Color(0xFF4DB6AC),
      Color(0xFF81C784),
      Color(0xFFAED581),
      Color(0xFFFFB74D),
      Color(0xFFFF8A65),
      Color(0xFFA1887F),
      Color(0xFF90A4AE),
    ];

    return colors[hash.abs() % colors.length];
  }
}
