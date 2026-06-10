import 'package:shared_preferences/shared_preferences.dart';

/// 应用颜色模式。
enum AppColorMode { system, light, dark }

/// 邮件列表时间显示方式。
enum MailListTimeFormat { smart, twentyFourHour, dateOnly }

/// 显示相关设置。
class DisplaySettings {
  const DisplaySettings({
    required this.colorMode,
    required this.previewLines,
    required this.timeFormat,
    required this.showSenderAvatar,
    required this.showAccountLabels,
    required this.showAttachmentIcon,
    required this.showUnreadIndicator,
    required this.showStarButton,
    required this.conversationView,
    required this.prefetchBodies,
  });

  static const DisplaySettings defaults = DisplaySettings(
    colorMode: AppColorMode.system,
    previewLines: 1,
    timeFormat: MailListTimeFormat.smart,
    showSenderAvatar: true,
    showAccountLabels: true,
    showAttachmentIcon: true,
    showUnreadIndicator: true,
    showStarButton: true,
    conversationView: true,
    prefetchBodies: true,
  );

  final AppColorMode colorMode;
  final int previewLines;
  final MailListTimeFormat timeFormat;
  final bool showSenderAvatar;
  final bool showAccountLabels;
  final bool showAttachmentIcon;
  final bool showUnreadIndicator;
  final bool showStarButton;

  /// 会话视图：把同一往来（同 threadKey）的邮件在列表里折叠成一条会话，
  /// 点开后整条会话按时间堆叠展示。关闭则回到一封一行。
  final bool conversationView;

  /// 自动预取邮件正文（点开即见内容）。关闭后仅在点击邮件时按需下载。
  final bool prefetchBodies;

  DisplaySettings copyWith({
    AppColorMode? colorMode,
    int? previewLines,
    MailListTimeFormat? timeFormat,
    bool? showSenderAvatar,
    bool? showAccountLabels,
    bool? showAttachmentIcon,
    bool? showUnreadIndicator,
    bool? showStarButton,
    bool? conversationView,
    bool? prefetchBodies,
  }) {
    return DisplaySettings(
      colorMode: colorMode ?? this.colorMode,
      previewLines: previewLines ?? this.previewLines,
      timeFormat: timeFormat ?? this.timeFormat,
      showSenderAvatar: showSenderAvatar ?? this.showSenderAvatar,
      showAccountLabels: showAccountLabels ?? this.showAccountLabels,
      showAttachmentIcon: showAttachmentIcon ?? this.showAttachmentIcon,
      showUnreadIndicator: showUnreadIndicator ?? this.showUnreadIndicator,
      showStarButton: showStarButton ?? this.showStarButton,
      conversationView: conversationView ?? this.conversationView,
      prefetchBodies: prefetchBodies ?? this.prefetchBodies,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DisplaySettings &&
            colorMode == other.colorMode &&
            previewLines == other.previewLines &&
            timeFormat == other.timeFormat &&
            showSenderAvatar == other.showSenderAvatar &&
            showAccountLabels == other.showAccountLabels &&
            showAttachmentIcon == other.showAttachmentIcon &&
            showUnreadIndicator == other.showUnreadIndicator &&
            showStarButton == other.showStarButton &&
            conversationView == other.conversationView &&
            prefetchBodies == other.prefetchBodies;
  }

  @override
  int get hashCode => Object.hash(
    colorMode,
    previewLines,
    timeFormat,
    showSenderAvatar,
    showAccountLabels,
    showAttachmentIcon,
    showUnreadIndicator,
    showStarButton,
    conversationView,
    prefetchBodies,
  );
}

/// 显示设置持久化。
class DisplaySettingsStore {
  const DisplaySettingsStore._();

  static const String _colorModeKey = 'display.colorMode';
  static const String _previewLinesKey = 'display.previewLines';
  static const String _timeFormatKey = 'display.timeFormat';
  static const String _showSenderAvatarKey = 'display.showSenderAvatar';
  static const String _showAccountLabelsKey = 'display.showAccountLabels';
  static const String _showAttachmentIconKey = 'display.showAttachmentIcon';
  static const String _showUnreadIndicatorKey = 'display.showUnreadIndicator';
  static const String _showStarButtonKey = 'display.showStarButton';
  static const String _conversationViewKey = 'display.conversationView';
  static const String _prefetchBodiesKey = 'display.prefetchBodies';

  static Future<DisplaySettings> read() async {
    final prefs = await SharedPreferences.getInstance();
    return DisplaySettings(
      colorMode: _parseColorMode(prefs.getString(_colorModeKey)),
      previewLines: _parsePreviewLines(prefs.getInt(_previewLinesKey)),
      timeFormat: _parseTimeFormat(prefs.getString(_timeFormatKey)),
      showSenderAvatar:
          prefs.getBool(_showSenderAvatarKey) ??
          DisplaySettings.defaults.showSenderAvatar,
      showAccountLabels:
          prefs.getBool(_showAccountLabelsKey) ??
          DisplaySettings.defaults.showAccountLabels,
      showAttachmentIcon:
          prefs.getBool(_showAttachmentIconKey) ??
          DisplaySettings.defaults.showAttachmentIcon,
      showUnreadIndicator:
          prefs.getBool(_showUnreadIndicatorKey) ??
          DisplaySettings.defaults.showUnreadIndicator,
      showStarButton:
          prefs.getBool(_showStarButtonKey) ??
          DisplaySettings.defaults.showStarButton,
      conversationView:
          prefs.getBool(_conversationViewKey) ??
          DisplaySettings.defaults.conversationView,
      prefetchBodies:
          prefs.getBool(_prefetchBodiesKey) ??
          DisplaySettings.defaults.prefetchBodies,
    );
  }

  static Future<void> write(DisplaySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorModeKey, _encodeColorMode(settings.colorMode));
    await prefs.setInt(_previewLinesKey, settings.previewLines);
    await prefs.setString(
      _timeFormatKey,
      _encodeTimeFormat(settings.timeFormat),
    );
    await prefs.setBool(_showSenderAvatarKey, settings.showSenderAvatar);
    await prefs.setBool(_showAccountLabelsKey, settings.showAccountLabels);
    await prefs.setBool(_showAttachmentIconKey, settings.showAttachmentIcon);
    await prefs.setBool(_showUnreadIndicatorKey, settings.showUnreadIndicator);
    await prefs.setBool(_showStarButtonKey, settings.showStarButton);
    await prefs.setBool(_conversationViewKey, settings.conversationView);
    await prefs.setBool(_prefetchBodiesKey, settings.prefetchBodies);
  }

  static AppColorMode _parseColorMode(String? raw) {
    return switch (raw) {
      'light' => AppColorMode.light,
      'dark' => AppColorMode.dark,
      _ => AppColorMode.system,
    };
  }

  static String _encodeColorMode(AppColorMode mode) {
    return switch (mode) {
      AppColorMode.system => 'system',
      AppColorMode.light => 'light',
      AppColorMode.dark => 'dark',
    };
  }

  static int _parsePreviewLines(int? raw) {
    if (raw == null) return DisplaySettings.defaults.previewLines;
    if (raw < 0) return 0;
    if (raw > 3) return 3;
    return raw;
  }

  static MailListTimeFormat _parseTimeFormat(String? raw) {
    return switch (raw) {
      'twentyFourHour' => MailListTimeFormat.twentyFourHour,
      'dateOnly' => MailListTimeFormat.dateOnly,
      _ => MailListTimeFormat.smart,
    };
  }

  static String _encodeTimeFormat(MailListTimeFormat format) {
    return switch (format) {
      MailListTimeFormat.smart => 'smart',
      MailListTimeFormat.twentyFourHour => 'twentyFourHour',
      MailListTimeFormat.dateOnly => 'dateOnly',
    };
  }
}
