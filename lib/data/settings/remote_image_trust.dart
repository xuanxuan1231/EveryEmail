import 'package:shared_preferences/shared_preferences.dart';

/// 预置信任域名：发件人域名命中（含子域名，如 mail.alipay.com）即自动加载
/// 远程图片，省去用户对常见官方通知邮件的逐封确认。
///
/// 收录标准（须同时满足）：
/// - 域名归企业自身所有，普通用户无法注册该域名下的邮箱地址——因此个人邮箱
///   域名（gmail.com / qq.com / 163.com / outlook.com 等）永远不收录；
/// - 发信以事务、通知类为主（验证码、账单、安全提醒等用户大概率想看图）；
/// - 知名品牌，普遍部署 SPF/DKIM/DMARC，伪造 From 的邮件大多在收件服务端
///   就被拒收或落入垃圾箱。
///
/// 刻意不收录银行类域名：银行是钓鱼伪造的重灾区，宁可让用户手动点一次
/// 「加载图片」。
const Set<String> kPresetTrustedImageSenderDomains = {
  // 开发与办公
  'github.com',
  'gitlab.com',
  'atlassian.com',
  'slack.com',
  'notion.so',
  'figma.com',
  'dropbox.com',
  'zoom.us',
  // 平台账号
  'google.com',
  'apple.com',
  'microsoft.com',
  'openai.com',
  'anthropic.com',
  // 电商与支付
  'amazon.com',
  'paypal.com',
  'stripe.com',
  // 社交与内容
  'linkedin.com',
  'spotify.com',
  'netflix.com',
  // 游戏
  'steampowered.com',
  'epicgames.com',
  // 国内服务（weixin.qq.com 是微信官方发信子域，按整段匹配，
  // 不会放行个人 qq.com 邮箱）
  'alipay.com',
  'taobao.com',
  'tmall.com',
  'jd.com',
  'meituan.com',
  'bilibili.com',
  'zhihu.com',
  'xiaomi.com',
  'huawei.com',
  'tencent.com',
  'weixin.qq.com',
  'aliyun.com',
  'baidu.com',
  '12306.cn',
  'ctrip.com',
  'trip.com',
};

/// 远程图片信任设置：决定哪些发件人的邮件自动加载远程图片。
///
/// 信任有两层：用户手动信任的发件人地址（精确匹配）、预置信任域名
/// （[kPresetTrustedImageSenderDomains]，可整体关闭）。
class RemoteImageTrust {
  const RemoteImageTrust({
    required this.trustedSenders,
    required this.presetEnabled,
  });

  static const RemoteImageTrust defaults = RemoteImageTrust(
    trustedSenders: <String>{},
    presetEnabled: true,
  );

  /// 用户手动信任的发件人地址（已小写规范化）。
  final Set<String> trustedSenders;

  /// 是否启用预置信任域名。
  final bool presetEnabled;

  /// 该发件人的远程图片是否自动加载。
  bool isTrustedSender(String? email) {
    final normalized = normalizeSenderEmail(email);
    if (normalized == null) return false;
    if (trustedSenders.contains(normalized)) return true;
    if (!presetEnabled) return false;

    final domain = normalized.substring(normalized.lastIndexOf('@') + 1);
    if (domain.isEmpty) return false;
    for (final preset in kPresetTrustedImageSenderDomains) {
      if (domain == preset || domain.endsWith('.$preset')) return true;
    }
    return false;
  }

  /// 规范化发件人地址：去空白、小写；不是合法形态（缺 @）返回 null。
  static String? normalizeSenderEmail(String? email) {
    final normalized = email?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    final at = normalized.lastIndexOf('@');
    if (at <= 0 || at == normalized.length - 1) return null;
    return normalized;
  }

  RemoteImageTrust copyWith({
    Set<String>? trustedSenders,
    bool? presetEnabled,
  }) {
    return RemoteImageTrust(
      trustedSenders: trustedSenders ?? this.trustedSenders,
      presetEnabled: presetEnabled ?? this.presetEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RemoteImageTrust &&
            presetEnabled == other.presetEnabled &&
            trustedSenders.length == other.trustedSenders.length &&
            trustedSenders.containsAll(other.trustedSenders);
  }

  @override
  int get hashCode =>
      Object.hash(presetEnabled, Object.hashAllUnordered(trustedSenders));
}

/// 远程图片信任设置持久化。
class RemoteImageTrustStore {
  const RemoteImageTrustStore._();

  static const String _trustedSendersKey = 'remoteImages.trustedSenders';
  static const String _presetEnabledKey = 'remoteImages.presetEnabled';

  static Future<RemoteImageTrust> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_trustedSendersKey) ?? const <String>[];
    final senders = <String>{
      for (final entry in raw) ?RemoteImageTrust.normalizeSenderEmail(entry),
    };
    return RemoteImageTrust(
      trustedSenders: senders,
      presetEnabled:
          prefs.getBool(_presetEnabledKey) ??
          RemoteImageTrust.defaults.presetEnabled,
    );
  }

  static Future<void> write(RemoteImageTrust trust) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _trustedSendersKey,
      trust.trustedSenders.toList()..sort(),
    );
    await prefs.setBool(_presetEnabledKey, trust.presetEnabled);
  }
}
