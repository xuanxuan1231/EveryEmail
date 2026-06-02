import 'package:flutter/material.dart';

import '../../../domain/models/mail_recipient.dart';

/// 收件人列表组件（可展开）。
class RecipientSection extends StatelessWidget {
  const RecipientSection({
    required this.toRecipients,
    required this.ccRecipients,
    super.key,
  });

  final List<MailRecipient> toRecipients;
  final List<MailRecipient> ccRecipients;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRecipients = toRecipients.isNotEmpty || ccRecipients.isNotEmpty;

    if (!hasRecipients) {
      return const SizedBox.shrink();
    }

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            Text(
              '收件人',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                RecipientUtils.formatRecipients(toRecipients, maxCount: 2),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        children: [
          // 收件人列表
          if (toRecipients.isNotEmpty) ...[
            _RecipientGroup(
              label: '收件人',
              recipients: toRecipients,
            ),
            const SizedBox(height: 8),
          ],

          // 抄送列表
          if (ccRecipients.isNotEmpty) ...[
            _RecipientGroup(
              label: '抄送',
              recipients: ccRecipients,
            ),
          ],
        ],
      ),
    );
  }
}

/// 收件人分组。
class _RecipientGroup extends StatelessWidget {
  const _RecipientGroup({
    required this.label,
    required this.recipients,
  });

  final String label;
  final List<MailRecipient> recipients;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label (${recipients.length})',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ...recipients.map((recipient) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (recipient.name != null)
                          Text(
                            recipient.name!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        Text(
                          recipient.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
