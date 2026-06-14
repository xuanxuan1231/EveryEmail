import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/mail_list_colors.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/settings/display_settings.dart';
import '../../../domain/enums/message_enums.dart';

bool gmailMobileMessageIsRead(Message message) {
  return (message.flagsBitmask & (1 << MessageFlag.seen.index)) != 0;
}

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
    this.displaySettings = DisplaySettings.defaults,
    this.paintBackgroundTint = true,
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
  final DisplaySettings displaySettings;
  final bool paintBackgroundTint;

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
            displaySettings: displaySettings,
            paintBackgroundTint: paintBackgroundTint,
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
    this.displaySettings = DisplaySettings.defaults,
    this.paintBackgroundTint = true,
    this.conversationCount,
    this.participantsLabel,
    super.key,
  });

  final Message message;
  final String? accountEmail;
  final Color? accountColor;
  final bool isSelected;
  final VoidCallback? onStarTap;
  final bool showAccountLabel;
  final DisplaySettings displaySettings;
  final bool paintBackgroundTint;

  /// 会话视图：该会话在当前窗口内的邮件数。为 null（或 ≤1）时按单封展示，
  /// 外观与非会话模式完全一致。>1 时在参与者行尾显示计数徽标。
  final int? conversationCount;

  /// 会话视图：参与者摘要（已把当前用户显示为「我」）。为 null 时回退到单封发件人。
  final String? participantsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final isRead = gmailMobileMessageIsRead(message);
    final isFlagged =
        (message.flagsBitmask & (1 << MessageFlag.flagged.index)) != 0;
    final showPreview =
        displaySettings.previewLines > 0 && message.preview.trim().isNotEmpty;
    final showStar = displaySettings.showStarButton;
    final showAccountIndicator =
        showAccountLabel &&
        displaySettings.showAccountLabels &&
        accountEmail != null;
    final unreadAccent = colors.tertiary;
    final itemTint = mailListMessageItemTintColor(
      theme,
      isRead: isRead,
      isSelected: isSelected,
    );
    final primaryText = isRead ? colors.onSurfaceVariant : colors.onSurface;
    final secondaryText = colors.onSurfaceVariant.withValues(
      alpha: isRead ? 0.78 : 0.9,
    );
    final metaText = isRead
        ? colors.onSurfaceVariant.withValues(alpha: 0.72)
        : unreadAccent;

    return ColoredBox(
      color: paintBackgroundTint ? itemTint : Colors.transparent,
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(
              color: isRead || !displaySettings.showUnreadIndicator
                  ? Colors.transparent
                  : unreadAccent,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (displaySettings.showSenderAvatar) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: isSelected
                        ? _buildSelectedAvatar(theme)
                        : _buildAvatar(theme),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showAccountIndicator) ...[
                            _buildAccountIndicator(theme),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              _subjectLabel,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: primaryText,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (message.hasAttachments &&
                              displaySettings.showAttachmentIcon) ...[
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                Symbols.attach_file,
                                size: 18,
                                color: secondaryText,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 96),
                            child: Text(
                              _formatDate(
                                message.date,
                                displaySettings.timeFormat,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.w500,
                                color: metaText,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              participantsLabel ?? _senderLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.w500,
                                color: secondaryText,
                                height: 1.35,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversationCount != null &&
                              conversationCount! > 1) ...[
                            const SizedBox(width: 6),
                            _buildCountBadge(theme, isRead),
                          ],
                        ],
                      ),
                      if (showPreview || showStar) ...[
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showPreview)
                              Expanded(
                                child: Text(
                                  message.preview,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    color: secondaryText,
                                    height: 1.35,
                                  ),
                                  maxLines: displaySettings.previewLines,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else
                              const Spacer(),
                            if (showStar) ...[
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
                                          ? Symbols.star
                                          : Symbols.star_border,
                                      size: 22,
                                      color: isFlagged
                                          ? _starColor(colors)
                                          : colors.onSurfaceVariant.withValues(
                                              alpha: dark ? 0.58 : 0.5,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
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

  /// 会话计数徽标：参与者行尾的小圆角数字（如「3」），随已读弱化。
  Widget _buildCountBadge(ThemeData theme, bool isRead) {
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(
          alpha: isRead ? 0.7 : 1,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$conversationCount',
        style: TextStyle(
          fontSize: 11,
          fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
          color: colors.onSurfaceVariant,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildAccountIndicator(ThemeData theme) {
    final color = _toneListAccent(
      accountColor ?? theme.colorScheme.outline,
      theme,
    );

    return Tooltip(
      message: accountEmail ?? '',
      child: Semantics(
        label: accountEmail == null ? null : '账户 $accountEmail',
        child: Container(
          width: 5,
          height: 18,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
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
      child: Icon(Symbols.check, color: theme.colorScheme.onPrimary, size: 24),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    final initial = _senderLabel[0].toUpperCase();
    final color = _toneListAccent(
      _generateColorFromEmail(message.fromEmail ?? _senderLabel),
      theme,
    );
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: onColor,
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

  String get _subjectLabel {
    return message.subject.isEmpty ? '(无主题)' : message.subject;
  }

  String _formatDate(DateTime date, MailListTimeFormat format) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(messageDate).inDays;

    return switch (format) {
      MailListTimeFormat.twentyFourHour => _formatTwentyFourHourDate(
        date,
        now,
        diff,
      ),
      MailListTimeFormat.dateOnly => _formatDateOnly(date, now),
      MailListTimeFormat.smart => _formatSmartDate(date, now, diff),
    };
  }

  String _formatSmartDate(DateTime date, DateTime now, int diff) {
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

  String _formatTwentyFourHourDate(DateTime date, DateTime now, int diff) {
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff == 0) {
      return time;
    } else if (diff == 1) {
      return '昨天 $time';
    } else if (date.year == now.year) {
      return '${date.month}/${date.day}';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }

  String _formatDateOnly(DateTime date, DateTime now) {
    if (date.year == now.year) {
      return '${date.month}月${date.day}日';
    }
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// 根据邮箱地址生成一致的颜色（Gmail 风格的柔和色）。
  Color _generateColorFromEmail(String email) {
    if (email.isEmpty) return const Color(0xFF9E9E9E);

    final hash = email.hashCode;

    const colors = [
      Color(0xFFB75644),
      Color(0xFFB43E6A),
      Color(0xFF8B5FA8),
      Color(0xFF5E6FAE),
      Color(0xFF3F7EA8),
      Color(0xFF2F8A8C),
      Color(0xFF3F8751),
      Color(0xFF777F34),
      Color(0xFFB06B2E),
      Color(0xFFA35445),
      Color(0xFF6F6A62),
      Color(0xFF60727B),
    ];

    return colors[hash.abs() % colors.length];
  }

  Color _toneListAccent(Color color, ThemeData theme) {
    final hsl = HSLColor.fromColor(color);
    final dark = theme.colorScheme.brightness == Brightness.dark;
    final saturation = hsl.saturation < 0.08
        ? 0.0
        : (hsl.saturation * 0.82).clamp(0.38, 0.74).toDouble();
    final lightness = dark
        ? hsl.lightness.clamp(0.5, 0.68).toDouble()
        : hsl.lightness.clamp(0.34, 0.5).toDouble();

    return hsl.withSaturation(saturation).withLightness(lightness).toColor();
  }

  Color _starColor(ColorScheme colors) {
    return colors.brightness == Brightness.dark
        ? const Color(0xFFFFD36A)
        : const Color(0xFFE0A100);
  }
}
