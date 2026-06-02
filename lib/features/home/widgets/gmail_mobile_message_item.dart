import 'package:flutter/material.dart';

import '../../../data/local/database/app_database.dart';
import '../../../domain/enums/message_enums.dart';

/// Gmail 移动 App 风格的邮件列表项。
///
/// 特点（基于 Android/iOS Gmail App）：
/// - 大头像（56x56px）
/// - 发件人在最上面（粗体，与时间同行）
/// - 主题单独一行（中等粗细）
/// - 预览单独一行（小字，灰色）
/// - 未读邮件左侧有蓝色粗竖条（4px）
/// - 星标在右下角
/// - 更大的垂直间距
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
    final isRead = (message.flagsBitmask & (1 << MessageFlag.seen.index)) != 0;
    final isFlagged = (message.flagsBitmask & (1 << MessageFlag.flagged.index)) != 0;

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 未读指示器（左侧蓝色竖条）
              Container(
                width: 4,
                height: 80,
                color: isRead ? Colors.transparent : theme.colorScheme.primary,
              ),

              // 主要内容区域
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 选择模式下的复选框或头像
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                            ),
                            child: Icon(
                              Icons.check,
                              color: theme.colorScheme.onPrimary,
                              size: 28,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _buildAvatar(theme),
                        ),

                      // 邮件信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 第一行：发件人和时间
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    message.fromName ?? message.fromEmail ?? '未知发件人',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
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
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            // 第二行：主题（单独一行）
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    message.subject.isEmpty ? '(无主题)' : message.subject,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                      height: 1.4,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // 附件图标
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

                            // 第三行：预览（单独一行）+ 星标
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    message.preview.isEmpty ? '' : message.preview,
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
                                // 星标
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: onStarTap,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      isFlagged ? Icons.star : Icons.star_border_outlined,
                                      size: 22,
                                      color: isFlagged
                                          ? const Color(0xFFF9AB00) // Gmail 黄色
                                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // 账户标签（仅在统一收件箱显示）
                            if (showAccountLabel && accountEmail != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    height: 18,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: accountColor ?? Colors.grey,
                                        width: 1,
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
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    final initial = (message.fromName ?? message.fromEmail ?? '?')[0].toUpperCase();
    final color = accountColor ?? _generateColorFromEmail(message.fromEmail ?? '');

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(messageDate).inDays;

    if (diff == 0) {
      // 今天：显示时间
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? '下午' : '上午';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$period$displayHour:$minute';
    } else if (diff == 1) {
      // 昨天
      return '昨天';
    } else if (diff < 7) {
      // 一周内：显示星期
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[date.weekday - 1];
    } else if (date.year == now.year) {
      // 今年：显示月日
      return '${date.month}月${date.day}日';
    } else {
      // 往年：显示年份
      return '${date.year}年';
    }
  }

  /// 根据邮箱地址生成一致的颜色（Gmail 风格的柔和色）。
  Color _generateColorFromEmail(String email) {
    if (email.isEmpty) return const Color(0xFF9E9E9E);

    final hash = email.hashCode;

    // Gmail 使用的柔和色调
    const colors = [
      Color(0xFFE57373), // 红色
      Color(0xFFF06292), // 粉色
      Color(0xFFBA68C8), // 紫色
      Color(0xFF9575CD), // 深紫色
      Color(0xFF7986CB), // 靛蓝
      Color(0xFF64B5F6), // 蓝色
      Color(0xFF4FC3F7), // 浅蓝
      Color(0xFF4DD0E1), // 青色
      Color(0xFF4DB6AC), // 蓝绿
      Color(0xFF81C784), // 绿色
      Color(0xFFAED581), // 浅绿
      Color(0xFFFFB74D), // 橙色
      Color(0xFFFF8A65), // 深橙
      Color(0xFFA1887F), // 棕色
      Color(0xFF90A4AE), // 蓝灰
    ];

    return colors[hash.abs() % colors.length];
  }
}
