import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/navigation/predictive_back_shared_element.dart';
import '../../core/platform/system_settings.dart';
import '../../core/theme/theme_ext.dart';
import '../../data/local/database/app_database.dart';
import '../../data/settings/account_settings.dart';
import '../../data/settings/app_font_settings.dart';
import '../../data/settings/display_settings.dart';
import '../../data/settings/imap_realtime_settings.dart';
import '../../domain/enums/account_enums.dart';
import '../../domain/enums/message_enums.dart';
import '../../domain/models/account_config.dart';
import '../../domain/models/unified_mailbox.dart';
import 'widgets/account_profile_editors.dart';

/// 设置二级页与其入口按钮之间的共享元素 id。返回二级页时，页面会「收束」回
/// 对应的设置项按钮（与邮件详情收束回列表卡片一致）。
const String _displaySettingsReturnId = 'settings:display';
const String _notificationSettingsReturnId = 'settings:notifications';
const String _remoteImagesReturnId = 'settings:remote-images';
const String _securitySettingsReturnId = 'settings:security';
const String _addAccountReturnId = 'settings:add-account';
const String _aboutReturnId = 'settings:about';
const String _aboutLicensesReturnId = 'settings:about:licenses';
String _accountSettingsReturnId(String accountId) =>
    'settings:account:$accountId';
String _accountFoldersReturnId(String accountId) =>
    'settings:account:$accountId:folders';

/// 关于页外部链接。留空时对应入口与「链接」分组会自动隐藏；填入真实地址即可启用。
const String _aboutProjectUrl = '';
const String _aboutFeedbackEmail = '';

/// 计算设置项在所属分组内的圆角：分组整体是一个大圆角容器，只有首/尾项有外侧
/// 圆角、中间项为直角，使返回收束的终点形状与底层分组真实形状吻合。
BorderRadius _sectionTileRadius(
  BuildContext context, {
  required bool isFirst,
  required bool isLast,
}) {
  final corner = context.shapes.large.topLeft;
  final top = isFirst ? corner : Radius.zero;
  final bottom = isLast ? corner : Radius.zero;
  return BorderRadius.only(
    topLeft: top,
    topRight: top,
    bottomLeft: bottom,
    bottomRight: bottom,
  );
}

/// 把可跳转的设置项包成预见式返回的共享元素目标，二级页返回时收束回此按钮。
Widget _navigableSettingsTile({
  required BuildContext context,
  required String returnId,
  required bool isFirst,
  required bool isLast,
  required IconData icon,
  required Color iconColor,
  required String title,
  required VoidCallback onTap,
  String? subtitle,
  String? trailingLabel,
}) {
  _SettingsTile buildContent() => _SettingsTile(
    icon: icon,
    iconColor: iconColor,
    title: title,
    subtitle: subtitle,
    trailingLabel: trailingLabel,
    onTap: onTap,
  );

  return PredictiveBackSharedElementTarget(
    id: returnId,
    borderRadius: _sectionTileRadius(context, isFirst: isFirst, isLast: isLast),
    backgroundColor: context.colors.surfaceContainerHigh,
    previewBuilder: (_) => buildContent(),
    child: buildContent(),
  );
}

/// 应用设置首页。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final accountsAsync = ref.watch(accountsStreamProvider);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('设置')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsSection(
                    title: '通用',
                    children: [
                      _navigableSettingsTile(
                        context: context,
                        returnId: _displaySettingsReturnId,
                        isFirst: true,
                        isLast: false,
                        icon: Symbols.dark_mode,
                        iconColor: colors.primary,
                        title: '显示',
                        subtitle: '颜色、字体、邮件列表',
                        onTap: () => context.push('/settings/display'),
                      ),
                      _navigableSettingsTile(
                        context: context,
                        returnId: _notificationSettingsReturnId,
                        isFirst: false,
                        isLast: false,
                        icon: Symbols.notifications,
                        iconColor: colors.tertiary,
                        title: '通知',
                        subtitle: '系统通知设置',
                        onTap: () => context.push('/settings/notifications'),
                      ),
                      _navigableSettingsTile(
                        context: context,
                        returnId: _securitySettingsReturnId,
                        isFirst: false,
                        isLast: false,
                        icon: Symbols.shield,
                        iconColor: colors.primary,
                        title: '安全',
                        subtitle: '远程图片加载与信任名单',
                        onTap: () => context.push('/settings/security'),
                      ),
                      _SettingsTile(
                        icon: Symbols.cloud_sync,
                        iconColor: colors.secondary,
                        title: '网络',
                        subtitle: '连接与同步',
                        trailingLabel: '自动',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _AccountsSection(
                    accountsAsync: accountsAsync,
                    onOpenAccount: (account) {
                      context.push(
                        '/settings/accounts/${Uri.encodeComponent(account.id)}',
                      );
                    },
                    onAddAccount: () => context.push(
                      Uri(
                        path: '/onboarding/add',
                        queryParameters: {'returnId': _addAccountReturnId},
                      ).toString(),
                    ),
                    onReorder: (oldIndex, newIndex, accounts) {
                      unawaited(
                        _reorderAccounts(
                          context,
                          ref,
                          accounts,
                          oldIndex,
                          newIndex,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: '杂项',
                    children: [
                      _navigableSettingsTile(
                        context: context,
                        returnId: _aboutReturnId,
                        isFirst: true,
                        isLast: true,
                        icon: Symbols.info_rounded,
                        iconColor: colors.primary,
                        title: '关于',
                        subtitle: 'EveryEmail',
                        onTap: () => context.push('/settings/about'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _reorderAccounts(
    BuildContext context,
    WidgetRef ref,
    List<Account> accounts,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < 0 || oldIndex >= accounts.length) return;
    if (newIndex < 0 || newIndex >= accounts.length) return;
    if (oldIndex == newIndex) return;

    final ordered = [...accounts];
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);

    try {
      await ref
          .read(accountRepositoryProvider)
          .reorderAccounts(ordered.map((account) => account.id).toList());
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('账户顺序保存失败: $error')));
    }
  }

  static void _showChoiceSheet<T>({
    required BuildContext context,
    required String title,
    required T selected,
    required List<_SettingsChoice<T>> choices,
    required ValueChanged<T> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: Material(
                    color: colors.surfaceContainerHigh,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: choices.length,
                      separatorBuilder: (_, _) => const _SectionDivider(),
                      itemBuilder: (context, index) {
                        final choice = choices[index];
                        return _SettingsTile(
                          icon: choice.icon,
                          iconColor: choice.iconColor ?? colors.primary,
                          title: choice.title,
                          subtitle: choice.subtitle,
                          trailing: choice.value == selected
                              ? Icon(
                                  Symbols.check_rounded,
                                  color: colors.primary,
                                )
                              : null,
                          onTap: () {
                            Navigator.of(context).pop();
                            onSelected(choice.value);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fontDescription(AppFont font) {
    return switch (font) {
      AppFont.system => '系统默认字体',
      AppFont.googleSansFlex => 'Google Sans Flex',
    };
  }

  static String _colorModeLabel(AppColorMode mode) {
    return switch (mode) {
      AppColorMode.system => '自动',
      AppColorMode.light => '浅色',
      AppColorMode.dark => '深色',
    };
  }

  static String _previewLinesLabel(int lines) {
    return switch (lines) {
      0 => '不显示',
      1 => '1 行',
      2 => '2 行',
      _ => '3 行',
    };
  }

  static String _timeFormatLabel(MailListTimeFormat format) {
    return switch (format) {
      MailListTimeFormat.smart => '智能',
      MailListTimeFormat.twentyFourHour => '24 小时',
      MailListTimeFormat.dateOnly => '仅日期',
    };
  }

  static String _folderSyncScopeLabel(AccountFolderSyncScope scope) {
    return switch (scope) {
      AccountFolderSyncScope.inboxOnly => '仅收件箱',
      AccountFolderSyncScope.standard => '标准文件夹',
      AccountFolderSyncScope.subscribed => '已订阅',
      AccountFolderSyncScope.all => '全部',
    };
  }

  static String _accountTypeLabel(AccountType type) {
    return switch (type) {
      AccountType.gmailOAuth => 'Gmail',
      AccountType.microsoftGraph => 'Microsoft',
      AccountType.genericImap => 'IMAP',
    };
  }

  static String _authTypeLabel(AuthType type) {
    return switch (type) {
      AuthType.oauth => 'OAuth',
      AuthType.password => '密码',
    };
  }
}

class _SettingsChoice<T> {
  const _SettingsChoice({
    required this.value,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
  });

  final T value;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
}

/// 显示设置二级页。
class DisplaySettingsPage extends ConsumerWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final appFont = ref.watch(appFontProvider);
    final displaySettings = ref.watch(displaySettingsProvider);
    final useGoogleSansFlex = appFont == AppFont.googleSansFlex;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final scaffold = Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('显示')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsSection(
                    title: '外观',
                    children: [
                      _SettingsTile(
                        icon: Symbols.brightness_auto,
                        iconColor: colors.primary,
                        title: '颜色模式',
                        subtitle: '自动、浅色或深色',
                        trailingLabel: SettingsPage._colorModeLabel(
                          displaySettings.colorMode,
                        ),
                        onTap: () {
                          SettingsPage._showChoiceSheet<AppColorMode>(
                            context: context,
                            title: '颜色模式',
                            selected: displaySettings.colorMode,
                            choices: const [
                              _SettingsChoice(
                                value: AppColorMode.system,
                                icon: Symbols.brightness_auto,
                                title: '自动',
                                subtitle: '跟随系统浅色或深色模式',
                              ),
                              _SettingsChoice(
                                value: AppColorMode.light,
                                icon: Symbols.light_mode,
                                title: '浅色',
                                subtitle: '始终使用浅色界面',
                              ),
                              _SettingsChoice(
                                value: AppColorMode.dark,
                                icon: Symbols.dark_mode,
                                title: '深色',
                                subtitle: '始终使用深色界面',
                              ),
                            ],
                            onSelected: (mode) {
                              unawaited(
                                ref
                                    .read(displaySettingsProvider.notifier)
                                    .setColorMode(mode),
                              );
                            },
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Symbols.text_fields_rounded,
                        iconColor: colors.primary,
                        title: '字体',
                        subtitle: SettingsPage._fontDescription(appFont),
                        trailing: Switch(
                          value: useGoogleSansFlex,
                          onChanged: (enabled) {
                            ref
                                .read(appFontProvider.notifier)
                                .set(
                                  enabled
                                      ? AppFont.googleSansFlex
                                      : AppFont.system,
                                );
                          },
                        ),
                        onTap: () {
                          ref
                              .read(appFontProvider.notifier)
                              .set(
                                useGoogleSansFlex
                                    ? AppFont.system
                                    : AppFont.googleSansFlex,
                              );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: '邮件列表',
                    children: [
                      _SettingsTile(
                        icon: Symbols.notes,
                        iconColor: colors.secondary,
                        title: '预览行数',
                        subtitle: '控制列表中正文摘要占用的行数',
                        trailingLabel: SettingsPage._previewLinesLabel(
                          displaySettings.previewLines,
                        ),
                        onTap: () {
                          SettingsPage._showChoiceSheet<int>(
                            context: context,
                            title: '预览行数',
                            selected: displaySettings.previewLines,
                            choices: const [
                              _SettingsChoice(
                                value: 0,
                                icon: Symbols.subject_rounded,
                                title: '不显示',
                                subtitle: '隐藏正文摘要，让列表更紧凑',
                              ),
                              _SettingsChoice(
                                value: 1,
                                icon: Symbols.short_text_rounded,
                                title: '1 行',
                                subtitle: '显示一行正文摘要',
                              ),
                              _SettingsChoice(
                                value: 2,
                                icon: Symbols.notes,
                                title: '2 行',
                                subtitle: '显示两行正文摘要',
                              ),
                              _SettingsChoice(
                                value: 3,
                                icon: Symbols.article,
                                title: '3 行',
                                subtitle: '显示更多正文摘要',
                              ),
                            ],
                            onSelected: (lines) {
                              unawaited(
                                ref
                                    .read(displaySettingsProvider.notifier)
                                    .setPreviewLines(lines),
                              );
                            },
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Symbols.schedule_rounded,
                        iconColor: colors.secondary,
                        title: '时间格式',
                        subtitle: '控制邮件列表右侧时间显示',
                        trailingLabel: SettingsPage._timeFormatLabel(
                          displaySettings.timeFormat,
                        ),
                        onTap: () {
                          SettingsPage._showChoiceSheet<MailListTimeFormat>(
                            context: context,
                            title: '时间格式',
                            selected: displaySettings.timeFormat,
                            choices: const [
                              _SettingsChoice(
                                value: MailListTimeFormat.smart,
                                icon: Symbols.schedule_rounded,
                                title: '智能',
                                subtitle: '今天显示时间，近期显示昨天或星期',
                              ),
                              _SettingsChoice(
                                value: MailListTimeFormat.twentyFourHour,
                                icon: Symbols.access_time_rounded,
                                title: '24 小时',
                                subtitle: '今天显示 HH:mm，昨天显示昨天 HH:mm',
                              ),
                              _SettingsChoice(
                                value: MailListTimeFormat.dateOnly,
                                icon: Symbols.calendar_today,
                                title: '仅日期',
                                subtitle: '列表中优先显示日期',
                              ),
                            ],
                            onSelected: (format) {
                              unawaited(
                                ref
                                    .read(displaySettingsProvider.notifier)
                                    .setTimeFormat(format),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: '可见性',
                    children: [
                      _SettingsTile(
                        icon: Symbols.account_circle,
                        iconColor: colors.tertiary,
                        title: '发件人头像',
                        subtitle: '在邮件列表左侧显示发件人首字母头像',
                        trailing: Switch(
                          value: displaySettings.showSenderAvatar,
                          onChanged: (visible) {
                            unawaited(
                              ref
                                  .read(displaySettingsProvider.notifier)
                                  .setShowSenderAvatar(visible),
                            );
                          },
                        ),
                        onTap: () {
                          unawaited(
                            ref
                                .read(displaySettingsProvider.notifier)
                                .setShowSenderAvatar(
                                  !displaySettings.showSenderAvatar,
                                ),
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Symbols.label_outline_rounded,
                        iconColor: colors.tertiary,
                        title: '账户标签',
                        subtitle: '在统一收件箱和搜索结果中显示账户来源',
                        trailing: Switch(
                          value: displaySettings.showAccountLabels,
                          onChanged: (visible) {
                            unawaited(
                              ref
                                  .read(displaySettingsProvider.notifier)
                                  .setShowAccountLabels(visible),
                            );
                          },
                        ),
                        onTap: () {
                          unawaited(
                            ref
                                .read(displaySettingsProvider.notifier)
                                .setShowAccountLabels(
                                  !displaySettings.showAccountLabels,
                                ),
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Symbols.attach_file,
                        iconColor: colors.tertiary,
                        title: '附件图标',
                        subtitle: '有附件的邮件在主题行显示回形针',
                        trailing: Switch(
                          value: displaySettings.showAttachmentIcon,
                          onChanged: (visible) {
                            unawaited(
                              ref
                                  .read(displaySettingsProvider.notifier)
                                  .setShowAttachmentIcon(visible),
                            );
                          },
                        ),
                        onTap: () {
                          unawaited(
                            ref
                                .read(displaySettingsProvider.notifier)
                                .setShowAttachmentIcon(
                                  !displaySettings.showAttachmentIcon,
                                ),
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Symbols.mark_email_unread,
                        iconColor: colors.tertiary,
                        title: '未读强调条',
                        subtitle: '未读邮件左侧显示强调色竖条',
                        trailing: Switch(
                          value: displaySettings.showUnreadIndicator,
                          onChanged: (visible) {
                            unawaited(
                              ref
                                  .read(displaySettingsProvider.notifier)
                                  .setShowUnreadIndicator(visible),
                            );
                          },
                        ),
                        onTap: () {
                          unawaited(
                            ref
                                .read(displaySettingsProvider.notifier)
                                .setShowUnreadIndicator(
                                  !displaySettings.showUnreadIndicator,
                                ),
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Symbols.star_border_rounded,
                        iconColor: colors.tertiary,
                        title: '星标按钮',
                        subtitle: '在邮件列表右侧显示星标按钮',
                        trailing: Switch(
                          value: displaySettings.showStarButton,
                          onChanged: (visible) {
                            unawaited(
                              ref
                                  .read(displaySettingsProvider.notifier)
                                  .setShowStarButton(visible),
                            );
                          },
                        ),
                        onTap: () {
                          unawaited(
                            ref
                                .read(displaySettingsProvider.notifier)
                                .setShowStarButton(
                                  !displaySettings.showStarButton,
                                ),
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Symbols.forum,
                        iconColor: colors.tertiary,
                        title: '会话视图',
                        subtitle: '把同一往来的邮件归为一条会话，点开按时间展开',
                        trailing: Switch(
                          value: displaySettings.conversationView,
                          onChanged: (enabled) {
                            unawaited(
                              ref
                                  .read(displaySettingsProvider.notifier)
                                  .setConversationView(enabled),
                            );
                          },
                        ),
                        onTap: () {
                          unawaited(
                            ref
                                .read(displaySettingsProvider.notifier)
                                .setConversationView(
                                  !displaySettings.conversationView,
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: '性能',
                    children: [
                      _SettingsTile(
                        icon: Symbols.bolt,
                        iconColor: colors.tertiary,
                        title: '自动预取正文',
                        subtitle: '后台提前下载邮件正文，点开即见内容（仅 Wi‑Fi/非计费网络）',
                        trailing: Switch(
                          value: displaySettings.prefetchBodies,
                          onChanged: (enabled) {
                            unawaited(
                              ref
                                  .read(displaySettingsProvider.notifier)
                                  .setPrefetchBodies(enabled),
                            );
                          },
                        ),
                        onTap: () {
                          unawaited(
                            ref
                                .read(displaySettingsProvider.notifier)
                                .setPrefetchBodies(
                                  !displaySettings.prefetchBodies,
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return PredictiveBackReturnTarget(
      id: _displaySettingsReturnId,
      child: scaffold,
    );
  }
}

/// 「安全」二级页：邮件安全与隐私相关设置的归集入口。目前提供「邮件中的
/// 图片」（远程图片拦截与信任名单）；后续安全类设置可继续归入此页。
class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final scaffold = Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('安全')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsSection(
                    title: '隐私',
                    children: [
                      _navigableSettingsTile(
                        context: context,
                        returnId: _remoteImagesReturnId,
                        isFirst: true,
                        isLast: true,
                        icon: Symbols.image,
                        iconColor: colors.primary,
                        title: '邮件中的图片',
                        subtitle: '远程图片自动加载与信任名单',
                        onTap: () => context.push('/settings/remote-images'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return PredictiveBackReturnTarget(
      id: _securitySettingsReturnId,
      child: scaffold,
    );
  }
}

/// 「邮件中的图片」二级页：管理远程图片自动加载的信任名单。
///
/// 非受信发件人的远程图片默认拦截（防跟踪像素）；这里可整体开关预置信任
/// 名单（知名服务商官方域名），并移除曾在邮件里手动信任过的发件人。
class RemoteImageSettingsPage extends ConsumerWidget {
  const RemoteImageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final trust = ref.watch(remoteImageTrustProvider);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final trustedSenders = trust.trustedSenders.toList()..sort();

    final scaffold = Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('邮件中的图片')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    child: Text(
                      '邮件里的远程图片可能被用来跟踪阅读行为，默认拦截。'
                      '受信发件人的图片会自动显示；其他邮件点「加载图片」后可选择信任该发件人。',
                      style: context.texts.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _SettingsSection(
                    title: '自动加载',
                    children: [
                      _SettingsTile(
                        icon: Symbols.verified,
                        iconColor: colors.primary,
                        title: '预置信任名单',
                        subtitle: '知名服务商官方域名的通知邮件自动显示图片',
                        trailing: Switch(
                          value: trust.presetEnabled,
                          onChanged: (enabled) {
                            unawaited(
                              ref
                                  .read(remoteImageTrustProvider.notifier)
                                  .setPresetEnabled(enabled),
                            );
                          },
                        ),
                        onTap: () {
                          unawaited(
                            ref
                                .read(remoteImageTrustProvider.notifier)
                                .setPresetEnabled(!trust.presetEnabled),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection.custom(
                    title: '我信任的发件人',
                    child: trustedSenders.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              '还没有手动信任的发件人。在邮件里点「加载图片」后，可选择信任该发件人。',
                              style: context.texts.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (
                                var i = 0;
                                i < trustedSenders.length;
                                i++
                              ) ...[
                                if (i > 0) const _SectionDivider(),
                                _SettingsTile(
                                  icon: Symbols.person_outline,
                                  iconColor: colors.tertiary,
                                  title: trustedSenders[i],
                                  trailing: IconButton(
                                    icon: const Icon(Symbols.delete_outline),
                                    tooltip: '移除',
                                    onPressed: () {
                                      unawaited(
                                        ref
                                            .read(
                                              remoteImageTrustProvider.notifier,
                                            )
                                            .revokeSender(trustedSenders[i]),
                                      );
                                    },
                                  ),
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
    );

    return PredictiveBackReturnTarget(
      id: _remoteImagesReturnId,
      child: scaffold,
    );
  }
}

/// 通知设置二级页。新邮件走系统 notification 推送，声音/震动/重要性/开关均由
/// 系统通知渠道管理——这里提供一个跳转入口。
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final scaffold = Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('通知')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsSection(
                    title: '通知',
                    children: [
                      _SettingsTile(
                        icon: Symbols.open_in_new_rounded,
                        iconColor: colors.tertiary,
                        title: '系统通知设置',
                        subtitle: '按账户开关、提示音与震动由系统管理',
                        onTap: () {
                          unawaited(SystemSettings.openNotificationSettings());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '新邮件通知由系统直接推送，并按账户分类。如需逐个账户开关通知，或调整提示音、震动，请前往系统通知设置。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return PredictiveBackReturnTarget(
      id: _notificationSettingsReturnId,
      child: scaffold,
    );
  }
}

/// 关于页二级页。展示应用信息、版本、开源许可与相关链接，返回时收束回设置页
/// 「关于」入口按钮。
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final packageInfo = ref.watch(packageInfoProvider);
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;
    final versionLabel = buildNumber.isEmpty
        ? version
        : '$version ($buildNumber)';
    final hasLinks =
        _aboutProjectUrl.isNotEmpty || _aboutFeedbackEmail.isNotEmpty;

    final scaffold = Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('关于')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AboutHeader(version: version),
                  const SizedBox(height: 24),
                  _SettingsSection(
                    title: '应用',
                    children: [
                      _SettingsTile(
                        icon: Symbols.verified,
                        iconColor: colors.primary,
                        title: '版本',
                        subtitle: '当前安装的应用版本',
                        trailingLabel: versionLabel,
                      ),
                      _navigableSettingsTile(
                        context: context,
                        returnId: _aboutLicensesReturnId,
                        isFirst: false,
                        isLast: true,
                        icon: Symbols.description,
                        iconColor: colors.secondary,
                        title: '开源许可',
                        subtitle: '查看第三方库与许可证',
                        onTap: () => context.push('/settings/about/licenses'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: '技术',
                    children: [
                      _SettingsTile(
                        icon: Symbols.bolt,
                        iconColor: colors.tertiary,
                        title: '实时同步',
                        subtitle: 'IMAP IDLE 与 Microsoft Graph 推送',
                        enabled: false,
                      ),
                      _SettingsTile(
                        icon: Symbols.palette,
                        iconColor: colors.tertiary,
                        title: '设计语言',
                        subtitle: 'Material 3 Expressive',
                        enabled: false,
                      ),
                      _SettingsTile(
                        icon: Symbols.flutter_dash,
                        iconColor: colors.tertiary,
                        title: '构建框架',
                        subtitle: 'Flutter',
                        enabled: false,
                      ),
                    ],
                  ),
                  if (hasLinks) ...[
                    const SizedBox(height: 20),
                    _SettingsSection(
                      title: '链接',
                      children: [
                        if (_aboutProjectUrl.isNotEmpty)
                          _SettingsTile(
                            icon: Symbols.code_rounded,
                            iconColor: colors.primary,
                            title: '项目主页',
                            subtitle: _aboutProjectUrl,
                            onTap: () => _openUrl(context, _aboutProjectUrl),
                          ),
                        if (_aboutFeedbackEmail.isNotEmpty)
                          _SettingsTile(
                            icon: Symbols.feedback,
                            iconColor: colors.primary,
                            title: '反馈与建议',
                            subtitle: _aboutFeedbackEmail,
                            onTap: () =>
                                _openFeedback(context, _aboutFeedbackEmail),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    '© 2026 EveryEmail',
                    textAlign: TextAlign.center,
                    style: context.texts.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return PredictiveBackReturnTarget(id: _aboutReturnId, child: scaffold);
  }

  static Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text('无法打开链接: $url')));
    }
  }

  static Future<void> _openFeedback(BuildContext context, String email) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent('EveryEmail 反馈')}',
    );
    final opened = await launchUrl(uri);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text('无法发送邮件: $email')));
    }
  }
}

/// 关于页顶部的应用标识区：图标 + 名称 + 版本徽标 + 简介。
class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Symbols.mark_email_unread_rounded,
            size: 44,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'EveryEmail',
          style: texts.headlineSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '版本 $version',
            style: texts.labelLarge?.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Thunderbird 风格的邮件客户端\n'
          'IMAP IDLE · Microsoft Graph · Material 3 Expressive',
          textAlign: TextAlign.center,
          style: texts.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 0,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// 开源许可页，作为关于页「开源许可」按钮的预见式返回目标：用 GoRouter 子路由
/// (`/settings/about/licenses`) push，返回时收束回该按钮。包一层品牌信息。
class AppLicensePage extends ConsumerWidget {
  const AppLicensePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PredictiveBackReturnTarget(
      id: _aboutLicensesReturnId,
      child: LicensePage(
        applicationName: 'EveryEmail',
        applicationVersion: ref.watch(packageInfoProvider).version,
        applicationIcon: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Symbols.mark_email_unread_rounded,
            size: 48,
            color: context.colors.primary,
          ),
        ),
      ),
    );
  }
}

/// 单个账户的设置二级页。
class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final accountsAsync = ref.watch(accountsStreamProvider);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final content = accountsAsync.when(
      loading: () => Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(title: const Text('账户')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(title: const Text('账户')),
        body: Center(child: Text('账户加载失败: $error')),
      ),
      data: (accounts) {
        final account = _findAccount(accounts, accountId);
        if (account == null) {
          return Scaffold(
            backgroundColor: colors.surface,
            appBar: AppBar(title: const Text('账户')),
            body: const Center(child: Text('账户不存在')),
          );
        }

        final settings = ref.watch(accountSettingsProvider(account.id));
        final imapRealtime = account.accountType == AccountType.genericImap
            ? ref.watch(imapRealtimeSettingsProvider(account.id))
            : ImapRealtimeConfig.defaults;

        return Scaffold(
          backgroundColor: colors.surface,
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(title: Text(account.displayName)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding + 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AccountProfileHeader(
                        account: account,
                        settings: settings,
                      ),
                      const SizedBox(height: 20),
                      _SettingsSection(
                        title: '资料',
                        children: [
                          _SettingsTile(
                            icon: Symbols.account_circle,
                            iconColor: colors.primary,
                            title: '头像',
                            subtitle: _avatarSummary(settings),
                            trailing: _AccountTileTrailing(
                              child: AccountAvatar(
                                account: account,
                                settings: settings,
                                radius: 18,
                              ),
                            ),
                            onTap: () => _showAvatarSheet(
                              context,
                              ref,
                              account,
                              settings,
                            ),
                          ),
                          _SettingsTile(
                            icon: Symbols.badge,
                            iconColor: colors.primary,
                            title: '名称',
                            subtitle: account.displayName,
                            onTap: () => _showNameEditor(context, ref, account),
                          ),
                          _SettingsTile(
                            icon: Symbols.palette,
                            iconColor: _accountColor(context, account),
                            title: '颜色',
                            subtitle: '账户标签和头像颜色',
                            trailing: _AccountTileTrailing(
                              child: _ColorDot(
                                color: _accountColor(context, account),
                              ),
                            ),
                            onTap: () => _showColorSheet(context, ref, account),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SettingsSection(
                        title: '邮件收发',
                        children: [
                          _SettingsTile(
                            icon: Symbols.cloud_download,
                            iconColor: colors.secondary,
                            title: '接收邮件',
                            subtitle: '同步此账户的新邮件和变更',
                            trailing: Switch(
                              value: settings.receiveEnabled,
                              onChanged: (enabled) {
                                unawaited(
                                  ref
                                      .read(
                                        accountSettingsProvider(
                                          account.id,
                                        ).notifier,
                                      )
                                      .setReceiveEnabled(enabled),
                                );
                              },
                            ),
                            onTap: () {
                              unawaited(
                                ref
                                    .read(
                                      accountSettingsProvider(
                                        account.id,
                                      ).notifier,
                                    )
                                    .setReceiveEnabled(
                                      !settings.receiveEnabled,
                                    ),
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: Symbols.send,
                            iconColor: colors.secondary,
                            title: '发送邮件',
                            subtitle: '允许此账户用于发信',
                            trailing: Switch(
                              value: settings.sendEnabled,
                              onChanged: (enabled) {
                                unawaited(
                                  ref
                                      .read(
                                        accountSettingsProvider(
                                          account.id,
                                        ).notifier,
                                      )
                                      .setSendEnabled(enabled),
                                );
                              },
                            ),
                            onTap: () {
                              unawaited(
                                ref
                                    .read(
                                      accountSettingsProvider(
                                        account.id,
                                      ).notifier,
                                    )
                                    .setSendEnabled(!settings.sendEnabled),
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: Symbols.drafts,
                            iconColor: colors.secondary,
                            title: '草稿自动重试',
                            subtitle: '本地草稿保存后自动同步到服务端草稿箱',
                            trailing: Switch(
                              value: settings.draftSyncAutoRetry,
                              onChanged: (enabled) {
                                unawaited(
                                  ref
                                      .read(
                                        accountSettingsProvider(
                                          account.id,
                                        ).notifier,
                                      )
                                      .setDraftSyncAutoRetry(enabled),
                                );
                                if (enabled) {
                                  unawaited(
                                    ref
                                        .read(draftSyncQueueServiceProvider)
                                        .processQueue(),
                                  );
                                }
                              },
                            ),
                            onTap: () {
                              final enabled = !settings.draftSyncAutoRetry;
                              unawaited(
                                ref
                                    .read(
                                      accountSettingsProvider(
                                        account.id,
                                      ).notifier,
                                    )
                                    .setDraftSyncAutoRetry(enabled),
                              );
                              if (enabled) {
                                unawaited(
                                  ref
                                      .read(draftSyncQueueServiceProvider)
                                      .processQueue(),
                                );
                              }
                            },
                          ),
                          _SettingsTile(
                            icon: Symbols.timer,
                            iconColor: colors.secondary,
                            title: '草稿重试间隔',
                            subtitle: '草稿同步失败后再次自动尝试',
                            enabled: settings.draftSyncAutoRetry,
                            trailingLabel: _pollingIntervalLabel(
                              settings.draftSyncRetryInterval,
                            ),
                            onTap: settings.draftSyncAutoRetry
                                ? () => _showDraftRetryIntervalSheet(
                                    context,
                                    ref,
                                    account.id,
                                    settings.draftSyncRetryInterval,
                                  )
                                : null,
                          ),
                          _SettingsTile(
                            icon: Symbols.sync,
                            iconColor: colors.secondary,
                            title: '实时同步',
                            subtitle: '前台自动监听或响应推送触发',
                            enabled: settings.receiveEnabled,
                            trailing: Switch(
                              value: settings.realtimeSyncEnabled,
                              onChanged: settings.receiveEnabled
                                  ? (enabled) {
                                      unawaited(
                                        ref
                                            .read(
                                              accountSettingsProvider(
                                                account.id,
                                              ).notifier,
                                            )
                                            .setRealtimeSyncEnabled(enabled),
                                      );
                                    }
                                  : null,
                            ),
                            onTap: settings.receiveEnabled
                                ? () {
                                    unawaited(
                                      ref
                                          .read(
                                            accountSettingsProvider(
                                              account.id,
                                            ).notifier,
                                          )
                                          .setRealtimeSyncEnabled(
                                            !settings.realtimeSyncEnabled,
                                          ),
                                    );
                                  }
                                : null,
                          ),
                          if (account.accountType ==
                              AccountType.genericImap) ...[
                            _SettingsTile(
                              icon: Symbols.bolt,
                              iconColor: colors.secondary,
                              title: '使用 IMAP IDLE',
                              subtitle: '服务器支持时保持长连接；关闭后按间隔轮询',
                              enabled:
                                  settings.receiveEnabled &&
                                  settings.realtimeSyncEnabled,
                              trailing: Switch(
                                value: imapRealtime.idleEnabled,
                                onChanged:
                                    settings.receiveEnabled &&
                                        settings.realtimeSyncEnabled
                                    ? (enabled) {
                                        unawaited(
                                          ref
                                              .read(
                                                imapRealtimeSettingsProvider(
                                                  account.id,
                                                ).notifier,
                                              )
                                              .setIdleEnabled(enabled),
                                        );
                                      }
                                    : null,
                              ),
                              onTap:
                                  settings.receiveEnabled &&
                                      settings.realtimeSyncEnabled
                                  ? () {
                                      unawaited(
                                        ref
                                            .read(
                                              imapRealtimeSettingsProvider(
                                                account.id,
                                              ).notifier,
                                            )
                                            .setIdleEnabled(
                                              !imapRealtime.idleEnabled,
                                            ),
                                      );
                                    }
                                  : null,
                            ),
                            _SettingsTile(
                              icon: Symbols.timer,
                              iconColor: colors.secondary,
                              title: '轮询间隔',
                              subtitle: imapRealtime.idleEnabled
                                  ? '关闭 IDLE 后按此频率检查新邮件'
                                  : '按此频率检查新邮件',
                              enabled:
                                  settings.receiveEnabled &&
                                  settings.realtimeSyncEnabled,
                              trailingLabel: _pollingIntervalLabel(
                                imapRealtime.pollingInterval,
                              ),
                              onTap:
                                  settings.receiveEnabled &&
                                      settings.realtimeSyncEnabled
                                  ? () {
                                      _showPollingIntervalSheet(
                                        context,
                                        ref,
                                        account.id,
                                        imapRealtime.pollingInterval,
                                      );
                                    }
                                  : null,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SettingsSection(
                        title: '文件夹',
                        children: [
                          _navigableSettingsTile(
                            context: context,
                            returnId: _accountFoldersReturnId(account.id),
                            isFirst: true,
                            isLast: false,
                            icon: Symbols.folder_open,
                            iconColor: colors.tertiary,
                            title: '管理文件夹',
                            subtitle: '逐个控制显示、同步、通知与统一化',
                            onTap: () => context.push(
                              '/settings/accounts/${Uri.encodeComponent(account.id)}/folders',
                            ),
                          ),
                          _SettingsTile(
                            icon: Symbols.folder_copy,
                            iconColor: colors.tertiary,
                            title: '同步范围',
                            subtitle: '控制此账户拉取哪些文件夹',
                            trailingLabel: SettingsPage._folderSyncScopeLabel(
                              settings.folderSyncScope,
                            ),
                            onTap: () {
                              SettingsPage._showChoiceSheet<
                                AccountFolderSyncScope
                              >(
                                context: context,
                                title: '同步范围',
                                selected: settings.folderSyncScope,
                                choices: const [
                                  _SettingsChoice(
                                    value: AccountFolderSyncScope.inboxOnly,
                                    icon: Symbols.inbox,
                                    title: '仅收件箱',
                                    subtitle: '只同步收件箱邮件',
                                  ),
                                  _SettingsChoice(
                                    value: AccountFolderSyncScope.standard,
                                    icon: Symbols.folder_special,
                                    title: '标准文件夹',
                                    subtitle: '同步收件箱、已发送和草稿',
                                  ),
                                  _SettingsChoice(
                                    value: AccountFolderSyncScope.subscribed,
                                    icon: Symbols.fact_check,
                                    title: '已订阅',
                                    subtitle: '同步服务器标记为已订阅的文件夹',
                                  ),
                                  _SettingsChoice(
                                    value: AccountFolderSyncScope.all,
                                    icon: Symbols.all_inbox,
                                    title: '全部',
                                    subtitle: '同步此账户的全部文件夹',
                                  ),
                                ],
                                onSelected: (scope) {
                                  unawaited(
                                    ref
                                        .read(
                                          accountSettingsProvider(
                                            account.id,
                                          ).notifier,
                                        )
                                        .setFolderSyncScope(scope),
                                  );
                                },
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: Symbols.report_gmailerrorred,
                            iconColor: colors.tertiary,
                            title: '垃圾箱和废纸篓',
                            subtitle: '允许同步垃圾邮件和已删除邮件文件夹',
                            trailing: Switch(
                              value: settings.syncSpamAndTrash,
                              onChanged: (enabled) {
                                unawaited(
                                  ref
                                      .read(
                                        accountSettingsProvider(
                                          account.id,
                                        ).notifier,
                                      )
                                      .setSyncSpamAndTrash(enabled),
                                );
                              },
                            ),
                            onTap: () {
                              unawaited(
                                ref
                                    .read(
                                      accountSettingsProvider(
                                        account.id,
                                      ).notifier,
                                    )
                                    .setSyncSpamAndTrash(
                                      !settings.syncSpamAndTrash,
                                    ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SettingsSection(
                        title: '搜索',
                        children: [
                          _SettingsTile(
                            icon: Symbols.search,
                            iconColor: colors.secondary,
                            title: '纳入搜索',
                            subtitle: '全局搜索包含此账户邮件',
                            trailing: Switch(
                              value: settings.includeInSearch,
                              onChanged: (enabled) {
                                unawaited(
                                  ref
                                      .read(
                                        accountSettingsProvider(
                                          account.id,
                                        ).notifier,
                                      )
                                      .setIncludeInSearch(enabled),
                                );
                              },
                            ),
                            onTap: () {
                              unawaited(
                                ref
                                    .read(
                                      accountSettingsProvider(
                                        account.id,
                                      ).notifier,
                                    )
                                    .setIncludeInSearch(
                                      !settings.includeInSearch,
                                    ),
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: Symbols.manage_search,
                            iconColor: colors.secondary,
                            title: '搜索垃圾箱和废纸篓',
                            subtitle: '全局搜索包含此账户的垃圾邮件和已删除邮件',
                            enabled: settings.includeInSearch,
                            trailing: Switch(
                              value: settings.searchSpamAndTrash,
                              onChanged: settings.includeInSearch
                                  ? (enabled) {
                                      unawaited(
                                        ref
                                            .read(
                                              accountSettingsProvider(
                                                account.id,
                                              ).notifier,
                                            )
                                            .setSearchSpamAndTrash(enabled),
                                      );
                                    }
                                  : null,
                            ),
                            onTap: settings.includeInSearch
                                ? () {
                                    unawaited(
                                      ref
                                          .read(
                                            accountSettingsProvider(
                                              account.id,
                                            ).notifier,
                                          )
                                          .setSearchSpamAndTrash(
                                            !settings.searchSpamAndTrash,
                                          ),
                                    );
                                  }
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SettingsSection(
                        title: '账户',
                        children: [
                          if (account.accountType == AccountType.genericImap)
                            _SettingsTile(
                              icon: Symbols.tune,
                              iconColor: colors.tertiary,
                              title: '服务器配置',
                              subtitle: _serverConfigSummary(account),
                              onTap: () => _showServerConfigEditor(
                                context,
                                ref,
                                account,
                              ),
                            ),
                          _SettingsTile(
                            icon: Symbols.alternate_email_rounded,
                            iconColor: colors.tertiary,
                            title: '邮箱地址',
                            subtitle: account.email,
                            enabled: false,
                          ),
                          _SettingsTile(
                            icon: Symbols.dns,
                            iconColor: colors.tertiary,
                            title: '类型',
                            subtitle:
                                '${SettingsPage._accountTypeLabel(account.accountType)} · ${SettingsPage._authTypeLabel(account.authType)}',
                            enabled: false,
                          ),
                          _SettingsTile(
                            icon: Symbols.delete_outline_rounded,
                            iconColor: colors.error,
                            titleColor: colors.error,
                            title: '删除账户',
                            subtitle: '移除此账户及其所有本地邮件与缓存',
                            onTap: () =>
                                _confirmDeleteAccount(context, ref, account),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return PredictiveBackReturnTarget(
      id: _accountSettingsReturnId(accountId),
      child: content,
    );
  }

  static Account? _findAccount(List<Account> accounts, String accountId) {
    for (final account in accounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  static String _pollingIntervalLabel(Duration interval) {
    if (interval.inSeconds < 60) return '${interval.inSeconds} 秒';
    return '${interval.inMinutes} 分钟';
  }

  static void _showPollingIntervalSheet(
    BuildContext context,
    WidgetRef ref,
    String accountId,
    Duration selected,
  ) {
    SettingsPage._showChoiceSheet<Duration>(
      context: context,
      title: '轮询间隔',
      selected: selected,
      choices: const [
        _SettingsChoice(
          value: Duration(seconds: 30),
          icon: Symbols.speed,
          title: '30 秒',
          subtitle: '最快检查频率，耗电更多',
        ),
        _SettingsChoice(
          value: Duration(minutes: 1),
          icon: Symbols.timer,
          title: '1 分钟',
          subtitle: '较快收到新邮件',
        ),
        _SettingsChoice(
          value: Duration(minutes: 2),
          icon: Symbols.timer,
          title: '2 分钟',
          subtitle: '延迟和耗电较均衡',
        ),
        _SettingsChoice(
          value: Duration(minutes: 5),
          icon: Symbols.schedule,
          title: '5 分钟',
          subtitle: '更省电，通知会稍慢',
        ),
        _SettingsChoice(
          value: Duration(minutes: 10),
          icon: Symbols.schedule,
          title: '10 分钟',
          subtitle: '适合低频账户',
        ),
        _SettingsChoice(
          value: Duration(minutes: 15),
          icon: Symbols.battery_saver,
          title: '15 分钟',
          subtitle: '最省电，实时性最低',
        ),
      ],
      onSelected: (interval) {
        unawaited(
          ref
              .read(imapRealtimeSettingsProvider(accountId).notifier)
              .setPollingInterval(interval),
        );
      },
    );
  }

  static void _showDraftRetryIntervalSheet(
    BuildContext context,
    WidgetRef ref,
    String accountId,
    Duration selected,
  ) {
    SettingsPage._showChoiceSheet<Duration>(
      context: context,
      title: '草稿重试间隔',
      selected: selected,
      choices: const [
        _SettingsChoice(
          value: Duration(minutes: 1),
          icon: Symbols.speed,
          title: '1 分钟',
          subtitle: '更快同步，网络异常时更频繁尝试',
        ),
        _SettingsChoice(
          value: Duration(minutes: 5),
          icon: Symbols.timer,
          title: '5 分钟',
          subtitle: '默认间隔，兼顾及时性和耗电',
        ),
        _SettingsChoice(
          value: Duration(minutes: 10),
          icon: Symbols.timer,
          title: '10 分钟',
          subtitle: '适合一般后台重试',
        ),
        _SettingsChoice(
          value: Duration(minutes: 15),
          icon: Symbols.schedule,
          title: '15 分钟',
          subtitle: '减少网络请求',
        ),
        _SettingsChoice(
          value: Duration(minutes: 30),
          icon: Symbols.schedule,
          title: '30 分钟',
          subtitle: '适合低频账户',
        ),
        _SettingsChoice(
          value: Duration(hours: 1),
          icon: Symbols.battery_saver,
          title: '1 小时',
          subtitle: '最少自动尝试',
        ),
      ],
      onSelected: (interval) {
        unawaited(
          ref
              .read(accountSettingsProvider(accountId).notifier)
              .setDraftSyncRetryInterval(interval),
        );
        unawaited(ref.read(draftSyncQueueServiceProvider).processQueue());
      },
    );
  }

  static String _serverConfigSummary(Account account) {
    final imapHost = account.imapHost?.trim();
    final smtpHost = account.smtpHost?.trim();
    final parts = <String>[
      if (imapHost != null && imapHost.isNotEmpty)
        'IMAP $imapHost:${account.imapPort ?? 993}',
      if (smtpHost != null && smtpHost.isNotEmpty)
        'SMTP $smtpHost:${account.smtpPort ?? 465}',
    ];
    return parts.isEmpty ? '未配置服务器' : parts.join(' · ');
  }

  static Future<void> _showServerConfigEditor(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _AccountServerConfigEditorSheet(
        account: account,
        onSave:
            ({
              required String loginName,
              required ServerConfig imap,
              required ServerConfig smtp,
            }) async {
              await ref
                  .read(accountRepositoryProvider)
                  .updateServerConfig(
                    account.id,
                    loginName: loginName,
                    imap: imap,
                    smtp: smtp,
                  );
              await ref.read(syncServiceProvider).invalidateBackend(account.id);
            },
      ),
    );

    if (saved != true || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('服务器配置已保存')));
  }

  static Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('删除账户'),
          content: Text(
            '确定要删除「${account.displayName}」（${account.email}）吗？\n\n'
            '此账户的所有本地邮件、文件夹与缓存附件都会被移除，且无法撤销。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await ref.read(accountRepositoryProvider).removeAccount(account.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除账户 ${account.email}')));
      context.pop(); // 返回账户列表（设置页）
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除账户失败: $error')));
    }
  }

  static void _showNameEditor(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _AccountNameEditorSheet(
        initialName: account.displayName,
        onSave: (name) {
          unawaited(
            ref
                .read(accountRepositoryProvider)
                .updateAccountProfile(account.id, displayName: name),
          );
        },
      ),
    );
  }

  static void _showAvatarSheet(
    BuildContext context,
    WidgetRef ref,
    Account account,
    AccountSettings settings,
  ) {
    showAccountAvatarSheet(context, account: account, settings: settings);
  }

  static String _avatarSummary(AccountSettings settings) {
    return switch (settings.avatarMode) {
      AccountAvatarMode.text =>
        settings.avatarText == null
            ? '文字 · 名称首字母'
            : '文字 · ${settings.avatarText}',
      AccountAvatarMode.icon =>
        '图标 · ${_avatarIconLabel(settings.avatarIconId)}',
      AccountAvatarMode.image =>
        settings.avatarImagePath == null ? '图片' : '图片 · 已选择',
    };
  }

  static String _avatarIconLabel(String? iconId) {
    return avatarIconPreset(iconId)?.label ?? '预设图标';
  }

  static void _showColorSheet(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final selected = account.colorValue;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '颜色',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  AccountColorDot(
                    color: colors.primary,
                    selected: selected == null,
                    tooltip: '默认',
                    onTap: () {
                      Navigator.of(context).pop();
                      unawaited(
                        ref
                            .read(accountRepositoryProvider)
                            .updateAccountProfile(
                              account.id,
                              colorValue: const Value<int?>(null),
                            ),
                      );
                    },
                  ),
                  for (final value in kAccountColorValues)
                    AccountColorDot(
                      color: Color(value),
                      selected: selected == value,
                      tooltip: '#${value.toRadixString(16).toUpperCase()}',
                      onTap: () {
                        Navigator.of(context).pop();
                        unawaited(
                          ref
                              .read(accountRepositoryProvider)
                              .updateAccountProfile(
                                account.id,
                                colorValue: Value(value),
                              ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Color _accountColor(BuildContext context, Account account) {
    return account.colorValue == null
        ? Theme.of(context).colorScheme.primary
        : Color(account.colorValue!);
  }
}

/// 「管理文件夹」二级页：列出某账户的全部文件夹（含被隐藏的），点击弹窗逐个设置
/// 显示 / 同步 / 通知 / 统一化。返回时收束回账户设置页的「管理文件夹」按钮。
class AccountFoldersPage extends ConsumerWidget {
  const AccountFoldersPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final foldersAsync = ref.watch(accountFoldersProvider(accountId));

    final scaffold = Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('管理文件夹')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding + 24),
              child: foldersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 56),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _SettingsSection(
                  title: '文件夹',
                  children: [
                    _SettingsTile(
                      icon: Symbols.error_outline_rounded,
                      iconColor: colors.error,
                      title: '文件夹加载失败',
                      subtitle: '$error',
                      enabled: false,
                    ),
                  ],
                ),
                data: (folders) {
                  if (folders.isEmpty) {
                    return _SettingsSection(
                      title: '文件夹',
                      children: [
                        _SettingsTile(
                          icon: Symbols.folder_off,
                          iconColor: colors.onSurfaceVariant,
                          title: '暂无文件夹',
                          subtitle: '同步账户后这里会列出全部文件夹',
                          enabled: false,
                        ),
                      ],
                    );
                  }

                  return _SettingsSection(
                    title: '文件夹 · ${folders.length}',
                    children: [
                      for (final folder in folders)
                        _SettingsTile(
                          icon: _folderTypeIcon(folder.folderType),
                          iconColor: colors.tertiary,
                          title: folder.displayName,
                          subtitle: _folderFlagsSummary(folder),
                          onTap: () =>
                              _showFolderSettingsSheet(context, ref, folder),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    return PredictiveBackReturnTarget(
      id: _accountFoldersReturnId(accountId),
      child: scaffold,
    );
  }

  static void _showFolderSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _FolderSettingsSheet(folder: folder),
    );
  }
}

/// 单个文件夹的设置弹窗（底部弹出）：四个开关即时写穿数据库（乐观本地态 + 持久化）。
class _FolderSettingsSheet extends ConsumerStatefulWidget {
  const _FolderSettingsSheet({required this.folder});

  final Folder folder;

  @override
  ConsumerState<_FolderSettingsSheet> createState() =>
      _FolderSettingsSheetState();
}

class _FolderSettingsSheetState extends ConsumerState<_FolderSettingsSheet> {
  late bool _visible;
  late bool _syncEnabled;
  late bool _unified;

  @override
  void initState() {
    super.initState();
    _visible = widget.folder.visible;
    _syncEnabled = widget.folder.syncEnabled;
    _unified = widget.folder.unified;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final folder = widget.folder;
    final canUnify = UnifiedMailbox.isUnifiedFolderType(folder.folderType);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconBadge(
                icon: _folderTypeIcon(folder.folderType),
                color: colors.tertiary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folder.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _folderTypeLabel(folder.folderType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: colors.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Symbols.visibility,
                  iconColor: colors.tertiary,
                  title: '显示文件夹',
                  subtitle: '在侧边栏文件夹列表中显示',
                  trailing: Switch(value: _visible, onChanged: _setVisible),
                  onTap: () => _setVisible(!_visible),
                ),
                const _SectionDivider(),
                _SettingsTile(
                  icon: Symbols.sync,
                  iconColor: colors.secondary,
                  title: '启用同步',
                  subtitle: '拉取此文件夹的新邮件和变更',
                  trailing: Switch(
                    value: _syncEnabled,
                    onChanged: _setSyncEnabled,
                  ),
                  onTap: () => _setSyncEnabled(!_syncEnabled),
                ),
                const _SectionDivider(),
                _SettingsTile(
                  icon: Symbols.all_inbox,
                  iconColor: colors.tertiary,
                  title: '统一化',
                  subtitle: canUnify ? '纳入统一账户的聚合视图' : '仅收件箱、已发送、草稿支持统一化',
                  enabled: canUnify,
                  trailing: Switch(
                    value: canUnify && _unified,
                    onChanged: canUnify ? _setUnified : null,
                  ),
                  onTap: canUnify ? () => _setUnified(!_unified) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setVisible(bool value) {
    setState(() => _visible = value);
    _write(visible: value);
  }

  void _setSyncEnabled(bool value) {
    setState(() => _syncEnabled = value);
    _write(syncEnabled: value);
  }

  void _setUnified(bool value) {
    setState(() => _unified = value);
    _write(unified: value);
  }

  void _write({
    bool? visible,
    bool? syncEnabled,
    bool? notificationsEnabled,
    bool? unified,
  }) {
    unawaited(
      ref
          .read(databaseProvider)
          .folderDao
          .updateFolderFlags(
            widget.folder.id,
            visible: visible,
            syncEnabled: syncEnabled,
            notificationsEnabled: notificationsEnabled,
            unified: unified,
          ),
    );
  }
}

/// 文件夹列表项的状态摘要：显示/隐藏始终给出，开启的同步/通知/统一再依次列出。
String _folderFlagsSummary(Folder folder) {
  final canUnify = UnifiedMailbox.isUnifiedFolderType(folder.folderType);
  final parts = <String>[
    folder.visible ? '显示' : '隐藏',
    if (folder.syncEnabled) '同步',
    if (canUnify && folder.unified) '统一',
  ];
  return parts.join(' · ');
}

IconData _folderTypeIcon(FolderType type) {
  return switch (type) {
    FolderType.inbox => Symbols.inbox,
    FolderType.sent => Symbols.send,
    FolderType.drafts => Symbols.drafts,
    FolderType.trash => Symbols.delete_outline_rounded,
    FolderType.spam => Symbols.report_gmailerrorred,
    FolderType.archive => Symbols.archive,
    FolderType.custom => Symbols.folder,
  };
}

String _folderTypeLabel(FolderType type) {
  return switch (type) {
    FolderType.inbox => '收件箱',
    FolderType.sent => '已发送',
    FolderType.drafts => '草稿',
    FolderType.trash => '废纸篓',
    FolderType.spam => '垃圾邮件',
    FolderType.archive => '归档',
    FolderType.custom => '自定义文件夹',
  };
}

class _AccountNameEditorSheet extends StatefulWidget {
  const _AccountNameEditorSheet({
    required this.initialName,
    required this.onSave,
  });

  final String initialName;
  final ValueChanged<String> onSave;

  @override
  State<_AccountNameEditorSheet> createState() =>
      _AccountNameEditorSheetState();
}

class _AccountNameEditorSheetState extends State<_AccountNameEditorSheet>
    with WidgetsBindingObserver {
  late final TextEditingController _controller;
  Timer? _keyboardInsetTimer;
  double _keyboardInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardInsetTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _keyboardInsetTimer ??= Timer(
      const Duration(milliseconds: 48),
      _updateKeyboardInset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: _keyboardInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '名称',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: '账户名称'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('账户名称不能为空')));
      return;
    }

    Navigator.of(context).pop();
    widget.onSave(name);
  }

  void _updateKeyboardInset() {
    _keyboardInsetTimer = null;
    if (!mounted) return;

    final view = View.of(context);
    final nextInset = view.viewInsets.bottom / view.devicePixelRatio;
    if ((_keyboardInset - nextInset).abs() < 1) return;

    setState(() {
      _keyboardInset = nextInset;
    });
  }
}

class _AccountServerConfigEditorSheet extends StatefulWidget {
  const _AccountServerConfigEditorSheet({
    required this.account,
    required this.onSave,
  });

  final Account account;
  final Future<void> Function({
    required String loginName,
    required ServerConfig imap,
    required ServerConfig smtp,
  })
  onSave;

  @override
  State<_AccountServerConfigEditorSheet> createState() =>
      _AccountServerConfigEditorSheetState();
}

class _AccountServerConfigEditorSheetState
    extends State<_AccountServerConfigEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _loginNameController = TextEditingController(
    text: widget.account.loginName?.trim().isNotEmpty == true
        ? widget.account.loginName!.trim()
        : widget.account.email,
  );
  late final TextEditingController _imapHostController = TextEditingController(
    text: widget.account.imapHost ?? '',
  );
  late final TextEditingController _imapPortController = TextEditingController(
    text: (widget.account.imapPort ?? 993).toString(),
  );
  late final TextEditingController _smtpHostController = TextEditingController(
    text: widget.account.smtpHost ?? '',
  );
  late final TextEditingController _smtpPortController = TextEditingController(
    text: (widget.account.smtpPort ?? 465).toString(),
  );

  late SocketType _imapSocketType =
      widget.account.imapSocketType ?? SocketType.ssl;
  late SocketType _smtpSocketType =
      widget.account.smtpSocketType ?? SocketType.ssl;

  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _loginNameController.dispose();
    _imapHostController.dispose();
    _imapPortController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '服务器配置',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _loginNameController,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '登录名',
                  prefixIcon: Icon(Symbols.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: _requiredValidator('请输入登录名'),
              ),
              const SizedBox(height: 20),
              _buildServerGroup(
                context,
                title: 'IMAP',
                hostController: _imapHostController,
                portController: _imapPortController,
                socketType: _imapSocketType,
                onSocketTypeChanged: (type) {
                  if (type == null) return;
                  setState(() {
                    _imapSocketType = type;
                    _adjustPort(
                      controller: _imapPortController,
                      socketType: type,
                      sslPort: 993,
                      startTlsPort: 143,
                    );
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildServerGroup(
                context,
                title: 'SMTP',
                hostController: _smtpHostController,
                portController: _smtpPortController,
                socketType: _smtpSocketType,
                onSocketTypeChanged: (type) {
                  if (type == null) return;
                  setState(() {
                    _smtpSocketType = type;
                    _adjustPort(
                      controller: _smtpPortController,
                      socketType: type,
                      sslPort: 465,
                      startTlsPort: 587,
                    );
                  });
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onErrorContainer,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerGroup(
    BuildContext context, {
    required String title,
    required TextEditingController hostController,
    required TextEditingController portController,
    required SocketType socketType,
    required ValueChanged<SocketType?> onSocketTypeChanged,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: hostController,
          enabled: !_saving,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: '$title 服务器',
            prefixIcon: const Icon(Symbols.dns),
            border: const OutlineInputBorder(),
          ),
          validator: _requiredValidator('请输入$title 服务器地址'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: portController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '端口',
                  border: OutlineInputBorder(),
                ),
                validator: _portValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<SocketType>(
                initialValue: socketType,
                decoration: const InputDecoration(
                  labelText: '加密方式',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: SocketType.ssl,
                    child: Text('SSL/TLS'),
                  ),
                  DropdownMenuItem(
                    value: SocketType.starttls,
                    child: Text('STARTTLS'),
                  ),
                  DropdownMenuItem(value: SocketType.plain, child: Text('无')),
                ],
                onChanged: _saving ? null : onSocketTypeChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  FormFieldValidator<String> _requiredValidator(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }

  String? _portValidator(String? value) {
    final port = int.tryParse(value?.trim() ?? '');
    if (port == null) return '请输入端口';
    if (port < 1 || port > 65535) return '端口范围 1-65535';
    return null;
  }

  void _adjustPort({
    required TextEditingController controller,
    required SocketType socketType,
    required int sslPort,
    required int startTlsPort,
  }) {
    final current = int.tryParse(controller.text.trim());
    if (socketType == SocketType.ssl && current == startTlsPort) {
      controller.text = sslPort.toString();
    } else if (socketType == SocketType.starttls && current == sslPort) {
      controller.text = startTlsPort.toString();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(
        loginName: _loginNameController.text.trim(),
        imap: ServerConfig(
          host: _imapHostController.text.trim(),
          port: int.parse(_imapPortController.text.trim()),
          socketType: _imapSocketType,
        ),
        smtp: ServerConfig(
          host: _smtpHostController.text.trim(),
          port: int.parse(_smtpPortController.text.trim()),
          socketType: _smtpSocketType,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = '保存失败: $error';
      });
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children})
    : child = null;

  const _SettingsSection.custom({required this.title, required this.child})
    : children = const <Widget>[];

  final String title;
  final List<Widget> children;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            title,
            style: context.texts.titleSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        Material(
          color: colors.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: context.shapes.large),
          child: child ?? Column(children: _separatedChildren(context)),
        ),
      ],
    );
  }

  List<Widget> _separatedChildren(BuildContext context) {
    final result = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) result.add(const _SectionDivider());
      result.add(children[index]);
    }
    return result;
  }
}

class _AccountsSection extends StatelessWidget {
  const _AccountsSection({
    required this.accountsAsync,
    required this.onOpenAccount,
    required this.onAddAccount,
    required this.onReorder,
  });

  final AsyncValue<List<Account>> accountsAsync;
  final ValueChanged<Account> onOpenAccount;
  final VoidCallback onAddAccount;
  final void Function(int oldIndex, int newIndex, List<Account> accounts)
  onReorder;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection.custom(
      title: '账户',
      child: accountsAsync.when(
        data: (accounts) => _buildAccounts(context, accounts),
        loading: () => const SizedBox(
          height: 88,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => _SettingsTile(
          icon: Symbols.error_outline_rounded,
          iconColor: context.colors.error,
          title: '账户加载失败',
          subtitle: '$error',
          enabled: false,
        ),
      ),
    );
  }

  Widget _buildAccounts(BuildContext context, List<Account> accounts) {
    if (accounts.isEmpty) {
      return Column(
        children: [
          _navigableSettingsTile(
            context: context,
            returnId: _addAccountReturnId,
            isFirst: true,
            isLast: true,
            icon: Symbols.person_add_alt,
            iconColor: context.colors.primary,
            title: '添加账户',
            subtitle: 'Gmail、Microsoft 或 IMAP',
            onTap: onAddAccount,
          ),
        ],
      );
    }

    return Column(
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          buildDefaultDragHandles: false,
          itemCount: accounts.length,
          onReorderItem: (oldIndex, newIndex) {
            onReorder(oldIndex, newIndex, accounts);
          },
          itemBuilder: (context, index) {
            final account = accounts[index];
            return PredictiveBackSharedElementTarget(
              key: ValueKey(account.id),
              id: _accountSettingsReturnId(account.id),
              borderRadius: _sectionTileRadius(
                context,
                isFirst: index == 0,
                isLast: false,
              ),
              backgroundColor: context.colors.surfaceContainerHigh,
              previewBuilder: (context) => Consumer(
                builder: (context, ref, _) {
                  final settings = ref.watch(
                    accountSettingsProvider(account.id),
                  );
                  return _AccountTileContent(
                    account: account,
                    settings: settings,
                  );
                },
              ),
              child: _AccountOrderTile(
                account: account,
                index: index,
                showDivider: index > 0,
                onTap: () => onOpenAccount(account),
              ),
            );
          },
        ),
        const _SectionDivider(),
        _navigableSettingsTile(
          context: context,
          returnId: _addAccountReturnId,
          isFirst: false,
          isLast: true,
          icon: Symbols.add_circle_outline_rounded,
          iconColor: context.colors.primary,
          title: '添加账户',
          subtitle: 'Gmail、Microsoft 或 IMAP',
          onTap: onAddAccount,
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.iconColor,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.trailingLabel,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final Color? iconColor;
  final Color? titleColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? trailingLabel;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = enabled
        ? colors.onSurface
        : colors.onSurfaceVariant.withValues(alpha: 0.56);
    final titleForeground = enabled ? (titleColor ?? foreground) : foreground;
    final secondary = enabled
        ? colors.onSurfaceVariant
        : colors.onSurfaceVariant.withValues(alpha: 0.48);
    final effectiveIconColor = enabled
        ? iconColor ?? colors.primary
        : colors.onSurfaceVariant.withValues(alpha: 0.56);

    return InkWell(
      onTap: enabled ? onTap : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              _IconBadge(icon: icon, color: effectiveIconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: titleForeground,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: secondary,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_hasTrailing) ...[
                const SizedBox(width: 12),
                _buildTrailing(context, secondary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasTrailing =>
      trailing != null || trailingLabel != null || onTap != null;

  Widget _buildTrailing(BuildContext context, Color labelColor) {
    if (trailing != null) return trailing!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailingLabel != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 116),
            child: Text(
              trailingLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: labelColor,
                letterSpacing: 0,
              ),
            ),
          ),
        if (onTap != null)
          Icon(Symbols.chevron_right_rounded, color: labelColor),
      ],
    );
  }
}

class _AccountOrderTile extends ConsumerWidget {
  const _AccountOrderTile({
    required this.account,
    required this.index,
    required this.showDivider,
    required this.onTap,
  });

  final Account account;
  final int index;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final settings = ref.watch(accountSettingsProvider(account.id));

    return ColoredBox(
      color: colors.surfaceContainerHigh,
      child: Column(
        children: [
          if (showDivider) const _SectionDivider(),
          InkWell(
            onTap: onTap,
            child: _AccountTileContent(
              account: account,
              settings: settings,
              dragIndex: index,
            ),
          ),
        ],
      ),
    );
  }
}

/// 账户设置项的内容行（头像 + 名称/邮箱 + 跳转箭头）。在设置列表中是可拖动重排
/// 的入口按钮；在预见式返回收束时作为该按钮的预览（预览态不显示拖动手柄）。
class _AccountTileContent extends StatelessWidget {
  const _AccountTileContent({
    required this.account,
    required this.settings,
    this.dragIndex,
  });

  final Account account;
  final AccountSettings settings;

  /// 非空时在行尾显示重排拖动手柄；为空（预览态）时以等宽占位保持箭头位置一致。
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dragIndex = this.dragIndex;

    // 始终绘制拖动手柄图标，预览态（dragIndex 为空）只是去掉重排监听，避免返回
    // 收束时手柄先消失再出现的闪烁。
    final dragHandle = SizedBox.square(
      dimension: 48,
      child: Icon(Symbols.drag_handle_rounded, color: colors.onSurfaceVariant),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            AccountAvatar(account: account, settings: settings),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    account.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Symbols.chevron_right_rounded, color: colors.onSurfaceVariant),
            if (dragIndex != null)
              Semantics(
                label: '调整 ${account.displayName} 顺序',
                button: true,
                child: ReorderableDragStartListener(
                  index: dragIndex,
                  child: dragHandle,
                ),
              )
            else
              dragHandle,
          ],
        ),
      ),
    );
  }
}

class _AccountProfileHeader extends StatelessWidget {
  const _AccountProfileHeader({required this.account, required this.settings});

  final Account account;
  final AccountSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          AccountAvatar(account: account, settings: settings, radius: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTileTrailing extends StatelessWidget {
  const _AccountTileTrailing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(width: 8),
        Icon(Symbols.chevron_right_rounded, color: color),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: context.shapes.medium,
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 76,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.56),
    );
  }
}
