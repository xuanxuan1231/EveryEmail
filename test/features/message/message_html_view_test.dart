import 'package:everyemail/features/message/widgets/message_html_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageHtmlView sanitizer', () {
    test('removes active content and tracking resources', () {
      final html = buildSanitizedEmailHtmlForTesting('''
<html>
  <head>
    <style>
      @import url("https://tracker.example/style.css");
      @font-face { font-family: x; src: url("https://tracker.example/font.woff2"); }
      .remote { background-image: url("https://tracker.example/pixel.png"); position: fixed; }
    </style>
  </head>
  <body>
    <script nonce="known">alert(1)</script>
    <iframe src="https://evil.example"></iframe>
    <form action="https://evil.example"><input name="token"></form>
    <a href="javascript:alert(1)" onclick="steal()" ping="https://tracker.example/ping" nonce="known">bad</a>
    <img src="https://tracker.example/pixel.png" srcset="https://tracker.example/2x.png 2x" onerror="steal()">
    <img src="data:image/png;base64,abcd">
  </body>
</html>
''');

      expect(html, contains('Content-Security-Policy'));
      expect(html, contains("script-src 'nonce-"));
      expect(html, contains('<script nonce="'));
      expect(html, isNot(contains('<script nonce="known">alert')));
      expect(html, isNot(contains('<iframe')));
      expect(html, isNot(contains('<form')));
      expect(html, isNot(contains('<input')));
      expect(html, isNot(contains('javascript:')));
      expect(html, isNot(contains('onclick')));
      expect(html, isNot(contains('onerror')));
      expect(html, isNot(contains('ping=')));
      expect(html, isNot(contains('@import')));
      expect(html, isNot(contains('@font-face')));
      expect(
        html,
        isNot(contains('background-image: url("https://tracker.example')),
      );
      expect(
        html,
        isNot(contains('<img src="https://tracker.example/pixel.png"')),
      );
      expect(html, isNot(contains('srcset=')));
      expect(
        html,
        contains('data-ee-remote-src="https://tracker.example/pixel.png"'),
      );
      expect(html, isNot(contains('position: fixed')));
      expect(html, contains('data:image/png;base64,abcd'));
    });

    test('loads remote images only after explicit opt in', () {
      final html = buildSanitizedEmailHtmlForTesting('''
<style>.hero { background-image: url("https://cdn.example/hero.png"); }</style>
<img src="https://cdn.example/pixel.png" srcset="https://cdn.example/2x.png 2x">
''', loadRemoteImages: true);

      expect(html, contains('img-src data: cid: http: https:'));
      expect(
        html,
        contains('background-image: url("https://cdn.example/hero.png")'),
      );
      expect(html, contains('src="https://cdn.example/pixel.png"'));
      expect(html, isNot(contains('srcset=')));
      expect(html, contains('referrerpolicy="no-referrer"'));
      expect(html, contains('loading="lazy"'));
    });

    test('keeps only safe link schemes', () {
      final html = buildSanitizedEmailHtmlForTesting('''
<a href="https://example.com">https</a>
<a href="http://example.com">http</a>
<a href="mailto:user@example.com">mail</a>
<a href="tel:+123456">tel</a>
<a href="#section">anchor</a>
<a href="/relative/path">relative</a>
<a href="data:text/html,hello">data</a>
''');

      expect(html, contains('href="https://example.com"'));
      expect(html, contains('href="http://example.com"'));
      expect(html, contains('href="mailto:user@example.com"'));
      expect(html, contains('href="tel:+123456"'));
      expect(html, contains('href="#section"'));
      expect(html, isNot(contains('href="/relative/path"')));
      expect(html, isNot(contains('href="data:text/html,hello"')));
      expect(html, contains('rel="noopener noreferrer nofollow"'));
      expect(html, contains('referrerpolicy="no-referrer"'));
    });
  });
}
