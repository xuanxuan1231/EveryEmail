import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/settings/display_settings.dart';
import '../../../domain/enums/message_enums.dart';
import '../../../domain/models/mail_recipient.dart';

/// 单封邮件的头部列表行（Gmail 会话式阅读页的一行）。
///
/// 结构（为后续「一封会话里多封邮件」铺垫，目前一封邮件 = 一行）：
/// - 首行：发件人头像 + （发件人名/时间、收件人折叠行）+ 回复按钮 + 更多按钮。
/// - 上半行：发件人名称 + 发件时间（精确到天，跟随 [DisplaySettings.timeFormat]）。
/// - 下半行：收件人摘要（凡是当前用户账户邮箱显示成「我」），点击展开/收起。
/// - 展开区：发件人 / 收件人 / 抄送的完整 `name<email>` 与明确的完整发件时间，
///   撑满列表行宽度减去两侧内距（不缩进到头像下方）。
///
/// 回复 / 转发 / 打印暂无对应能力，先弹占位提示；星标走 [MessageFlag.flagged]。
class MessageHeaderTile extends ConsumerStatefulWidget {
  const MessageHeaderTile({
    required this.message,
    required this.selfEmails,
    required this.displaySettings,
    required this.collapsed,
    required this.onToggleCollapsed,
    super.key,
  });

  final Message message;

  /// 当前用户全部账户邮箱（小写），用于把收件人里的自己显示成「我」。
  final Set<String> selfEmails;

  final DisplaySettings displaySettings;

  /// 是否折叠正文。折叠态隐藏操作按钮与「收件人：」行，并在收件人位置
  /// 以较小字号显示一行正文预览（适合一个列表行高度）。
  final bool collapsed;

  /// 点击头像那一行时切换正文折叠。
  final VoidCallback onToggleCollapsed;

  @override
  ConsumerState<MessageHeaderTile> createState() => _MessageHeaderTileState();
}

class _MessageHeaderTileState extends ConsumerState<MessageHeaderTile> {
  /// 头部行的统一最小高度，按折叠态两行预览撑起的高度取值，
  /// 让折叠/展开两态的点击区高度一致。
  static const double _headerRowMinHeight = 72;

  /// 收件人详情（发件人/收件人/抄送/时间）是否展开。仅在非折叠态有意义。
  bool _recipientExpanded = false;

  Message get _message => widget.message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final to = RecipientUtils.parseRecipients(_message.toRecipients);
    final cc = RecipientUtils.parseRecipients(_message.ccRecipients);

    // 实时标志位：仅在 flag 变化时 tick，重建范围限定在本行（不含正文 WebView）。
    final flags =
        ref.watch(messageFlagsProvider(_message.id)).value ??
        _message.flagsBitmask;
    final isFlagged = (flags & (1 << MessageFlag.flagged.index)) != 0;
    final collapsed = widget.collapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 点击头像那一行切换正文折叠。点击区与水波纹覆盖整个头部区域
        // （含四周留白），而非仅标题行本身。内层的「收件人」行与操作按钮各自
        // 有独立手势，会拦截各自范围内的点击，不会误触发折叠。
        InkWell(
          onTap: widget.onToggleCollapsed,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, collapsed ? 16 : 4, 12),
            // 统一头部行高度：折叠态两行预览较高，给展开态也设同样的最小高度，
            // 使两种状态的点击区/水波纹高度一致。
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _headerRowMinHeight),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(theme),
                  const SizedBox(width: 14),
                  Expanded(child: _buildSummary(theme, to, collapsed)),
                  if (!collapsed) ...[
                    const SizedBox(width: 4),
                    _buildActionButton(
                      icon: Icons.reply,
                      tooltip: '回复',
                      onPressed: () => _notImplemented('回复'),
                    ),
                    _buildMoreButton(isFlagged: isFlagged),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!collapsed)
          AnimatedCrossFade(
            alignment: Alignment.topLeft,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _buildDetails(theme, to, cc),
            crossFadeState: _recipientExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOutCubic,
          ),
      ],
    );
  }

  // —— 首行：头像 + 摘要 + 按钮 ——

  Widget _buildSummary(ThemeData theme, List<MailRecipient> to, bool collapsed) {
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                _senderLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _collapsedTime(_message.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (collapsed)
          // 折叠态：在原收件人位置以较小字号显示最多两行正文预览。
          Text(
            _previewText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          )
        else
          InkWell(
            onTap: () => setState(() => _recipientExpanded = !_recipientExpanded),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '收件人：${_recipientsSummary(to)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _recipientExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    // 与下方「更多」按钮使用一致的尺寸（默认 48 点击区 + 22 图标 + 默认内边距），
    // 确保两个按钮图标在同一水平线上。
    return IconButton(
      icon: Icon(icon),
      iconSize: 22,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildMoreButton({required bool isFlagged}) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      iconSize: 22,
      tooltip: '更多',
      onSelected: (value) {
        switch (value) {
          case 'forward':
            _notImplemented('转发');
          case 'star':
            _toggleStar(isFlagged);
          case 'print':
            _notImplemented('打印');
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'forward',
          child: Row(
            children: [
              Icon(Icons.forward_outlined),
              SizedBox(width: 12),
              Text('转发'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'star',
          child: Row(
            children: [
              Icon(isFlagged ? Icons.star : Icons.star_border),
              const SizedBox(width: 12),
              Text(isFlagged ? '取消星标' : '星标'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'print',
          child: Row(
            children: [
              Icon(Icons.print_outlined),
              SizedBox(width: 12),
              Text('打印'),
            ],
          ),
        ),
      ],
    );
  }

  // —— 展开详情 ——

  Widget _buildDetails(
    ThemeData theme,
    List<MailRecipient> to,
    List<MailRecipient> cc,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow(theme, '发件人', _fromDetail()),
          if (to.isNotEmpty)
            _detailRow(theme, '收件人', to.map(_recipientDetail).join('\n')),
          if (cc.isNotEmpty)
            _detailRow(theme, '抄送', cc.map(_recipientDetail).join('\n')),
          _detailRow(theme, '时间', _explicitTime(_message.date), last: true),
        ],
      ),
    );
  }

  Widget _detailRow(
    ThemeData theme,
    String label,
    String value, {
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // —— 动作 ——

  Future<void> _toggleStar(bool isFlagged) async {
    try {
      await ref
          .read(syncServiceProvider)
          .setMessageFlag(
            _message.id,
            flag: MessageFlag.flagged,
            value: !isFlagged,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFlagged ? '已取消星标' : '已加星标')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  void _notImplemented(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label功能开发中')));
  }

  // —— 文案与格式化 ——

  String get _senderLabel {
    final name = _message.fromName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = _message.fromEmail?.trim();
    if (email != null && email.isNotEmpty) return email;

    return '未知发件人';
  }

  /// 折叠态显示的一行正文预览（取信封 preview 摘要）。
  String get _previewText {
    final preview = _message.preview.trim();
    return preview.isEmpty ? '（无正文预览）' : preview;
  }

  String _fromDetail() {
    final name = _message.fromName?.trim();
    final email = _message.fromEmail?.trim();
    if (name != null && name.isNotEmpty && email != null && email.isNotEmpty) {
      return '$name <$email>';
    }
    if (email != null && email.isNotEmpty) return email;
    if (name != null && name.isNotEmpty) return name;
    return '未知发件人';
  }

  String _recipientDetail(MailRecipient recipient) {
    final name = recipient.name?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name <${recipient.email}>';
    }
    return recipient.email;
  }

  /// 收件人摘要：把当前用户账户邮箱显示成「我」，超过 3 人折叠为「等 N 人」。
  String _recipientsSummary(List<MailRecipient> to) {
    if (to.isEmpty) return '(无收件人)';

    final names = to
        .map(
          (r) => widget.selfEmails.contains(r.email.trim().toLowerCase())
              ? '我'
              : r.displayName,
        )
        .toList();

    const maxCount = 3;
    if (names.length <= maxCount) return names.join('、');
    return '${names.take(maxCount).join('、')} 等 ${names.length} 人';
  }

  /// 折叠态时间：精确到天，跟随用户的显示时间格式设置。
  String _collapsedTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(messageDay).inDays;

    return switch (widget.displaySettings.timeFormat) {
      MailListTimeFormat.dateOnly => _dayDate(date, now),
      MailListTimeFormat.twentyFourHour =>
        '${_dayDate(date, now)} ${_two(date.hour)}:${_two(date.minute)}',
      MailListTimeFormat.smart => switch (diff) {
        0 => '今天',
        1 => '昨天',
        _ when diff > 1 && diff < 7 => _weekday(date),
        _ => _dayDate(date, now),
      },
    };
  }

  /// 展开态时间：明确到分钟，含星期，无歧义。
  String _explicitTime(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日 '
        '${_weekday(date)} ${_two(date.hour)}:${_two(date.minute)}';
  }

  String _dayDate(DateTime date, DateTime now) {
    if (date.year == now.year) {
      return '${date.month}月${date.day}日';
    }
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _weekday(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday - 1];
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  // —— 头像（与邮件列表项一致的哈希取色 + 首字母）——

  Widget _buildAvatar(ThemeData theme) {
    final initial = _senderLabel.characters.first.toUpperCase();
    final color = _toneAccent(
      _colorFromEmail(_message.fromEmail ?? _senderLabel),
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

  /// 根据邮箱地址生成一致的颜色（Gmail 风格的柔和色）。
  Color _colorFromEmail(String email) {
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

  Color _toneAccent(Color color, ThemeData theme) {
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
}
