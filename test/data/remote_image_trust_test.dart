import 'package:everyemail/data/settings/remote_image_trust.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('默认启用预置名单且没有手动信任的发件人', () async {
    final trust = await RemoteImageTrustStore.read();

    expect(trust, RemoteImageTrust.defaults);
    expect(trust.presetEnabled, isTrue);
    expect(trust.trustedSenders, isEmpty);
  });

  test('手动信任的发件人按地址精确匹配且大小写不敏感', () {
    const trust = RemoteImageTrust(
      trustedSenders: {'newsletter@example.com'},
      presetEnabled: false,
    );

    expect(trust.isTrustedSender('newsletter@example.com'), isTrue);
    expect(trust.isTrustedSender('  Newsletter@Example.COM '), isTrue);
    expect(trust.isTrustedSender('other@example.com'), isFalse);
    expect(trust.isTrustedSender(null), isFalse);
    expect(trust.isTrustedSender(''), isFalse);
    expect(trust.isTrustedSender('not-an-email'), isFalse);
  });

  test('预置名单按域名（含子域名）匹配知名服务商', () {
    const trust = RemoteImageTrust.defaults;

    expect(trust.isTrustedSender('notifications@github.com'), isTrue);
    expect(trust.isTrustedSender('no-reply@accounts.google.com'), isTrue);
    expect(trust.isTrustedSender('service@mail.alipay.com'), isTrue);
    expect(trust.isTrustedSender('newsletter@weixin.qq.com'), isTrue);
  });

  test('预置名单不放行个人邮箱域名与相似域名', () {
    const trust = RemoteImageTrust.defaults;

    // weixin.qq.com 在名单里，但个人 qq.com 邮箱绝不能因此受信。
    expect(trust.isTrustedSender('12345678@qq.com'), isFalse);
    expect(trust.isTrustedSender('someone@gmail.com'), isFalse);
    expect(trust.isTrustedSender('someone@163.com'), isFalse);
    // 后缀拼接的伪造域名（evilgithub.com）不能匹配 github.com。
    expect(trust.isTrustedSender('phish@evilgithub.com'), isFalse);
    expect(trust.isTrustedSender('phish@github.com.evil.io'), isFalse);
  });

  test('关闭预置名单后仅手动信任的发件人生效', () {
    const trust = RemoteImageTrust(
      trustedSenders: {'notifications@github.com'},
      presetEnabled: false,
    );

    expect(trust.isTrustedSender('notifications@github.com'), isTrue);
    expect(trust.isTrustedSender('no-reply@accounts.google.com'), isFalse);
  });

  test('信任设置可保存并读回，存储里的脏数据会被规范化或过滤', () async {
    const trust = RemoteImageTrust(
      trustedSenders: {'a@b.com', 'c@d.com'},
      presetEnabled: false,
    );

    await RemoteImageTrustStore.write(trust);
    expect(await RemoteImageTrustStore.read(), trust);

    SharedPreferences.setMockInitialValues({
      'remoteImages.trustedSenders': [' Mixed@Case.COM ', '', 'no-at-sign'],
    });
    final cleaned = await RemoteImageTrustStore.read();
    expect(cleaned.trustedSenders, {'mixed@case.com'});
  });
}
