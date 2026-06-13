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

    test('reserves declared image dimensions per axis on blocked images', () {
      // Width + height: both axes are marked, so neither min-width nor
      // min-height floors the placeholder — it keeps the image's own box.
      final both = buildSanitizedEmailHtmlForTesting(
        '<img src="https://cdn.example/banner.png" width="600" height="200">',
      );
      expect(both, contains('data-ee-w=""'));
      expect(both, contains('data-ee-h=""'));
      expect(both, contains('width="600"'));
      expect(both, contains('height="200"'));
      // The shared normalization rule + per-axis floor rules ship.
      expect(both, contains('#email-root img'));
      expect(both, contains('max-width: 100%'));
      expect(both, contains(':not([data-ee-w]):not([src])'));
      expect(both, contains(':not([data-ee-h]):not([src])'));
      // Width-only icon (e.g. width="24"): width is reserved (data-ee-w) so the
      // 112px min-width never inflates it; only the unknown height is floored.
      final widthOnly = buildSanitizedEmailHtmlForTesting(
        '<img src="https://cdn.example/icon.png" width="24">',
      );
      expect(widthOnly, contains('data-ee-w=""'));
      expect(widthOnly, isNot(contains('data-ee-h=""')));

      // Height-only (height + style width:100%): both axes have a usable size.
      final heightAndFluid = buildSanitizedEmailHtmlForTesting(
        '<img src="https://cdn.example/c.png" height="20" style="width:100%">',
      );
      expect(heightAndFluid, contains('data-ee-w=""'));
      expect(heightAndFluid, contains('data-ee-h=""'));

      // max-width is NOT a usable width: a height-only image keeps min-width.
      final maxWidthOnly = buildSanitizedEmailHtmlForTesting(
        '<img src="https://cdn.example/d.png" height="20" style="max-width:100%">',
      );
      expect(maxWidthOnly, contains('data-ee-h=""'));
      expect(maxWidthOnly, isNot(contains('data-ee-w=""')));

      // No dimensions anywhere: neither axis marked, both floors apply.
      final blank = buildSanitizedEmailHtmlForTesting(
        '<img src="https://cdn.example/tracker.png">',
      );
      expect(blank, contains('data-ee-remote-src='));
      expect(blank, isNot(contains('data-ee-w=""')));
      expect(blank, isNot(contains('data-ee-h=""')));
    });

    test('does not mark axes once remote images are loaded', () {
      final html = buildSanitizedEmailHtmlForTesting(
        '<img src="https://cdn.example/banner.png" width="600" height="200">',
        loadRemoteImages: true,
      );
      expect(html, contains('src="https://cdn.example/banner.png"'));
      expect(html, isNot(contains('data-ee-w=""')));
      expect(html, isNot(contains('data-ee-h=""')));
      expect(html, isNot(contains('data-ee-remote-src=')));
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

    test('preserves fixed width email layout and scales the viewport', () {
      final html = buildSanitizedEmailHtmlForTesting('''
<table width="640" style="width:640px; min-width:640px">
  <tr><td nowrap style="white-space:nowrap">Wide CTA</td></tr>
</table>
''');

      expect(html, contains('width="640"'));
      expect(html, contains('width:640px; min-width:640px'));
      expect(html, contains('white-space:nowrap'));
      expect(html, contains('transform: scale(var(--ee-scale))'));
      expect(html, isNot(contains('table[width]')));
      expect(html, isNot(contains('white-space: normal !important')));
    });

    test('inverts a light-only email in dark mode via the filter path', () {
      final html = buildSanitizedEmailHtmlForTesting(
        '<p>Hello</p>',
        backgroundColorValue: 0xff101214,
        foregroundColorValue: 0xfff4f6f8,
        linkColorValue: 0xff8ab4f8,
        borderColorValue: 0xff3c4043,
      );

      // No dark declaration in the email -> filter path: the body is flagged for
      // inversion and rendered with a light, pre-compensated palette.
      expect(html, contains('<html data-ee-invert="on">'));
      expect(html, contains('filter: invert(1) hue-rotate(180deg)'));
      expect(html, contains('<meta name="color-scheme" content="light">'));
      expect(html, contains('color-scheme: light;'));
      // Pre-image under invert(1) hue-rotate(180deg): inverting alone would emit
      // #efedeb / #0b0907 and land off-hue after the filter (the card seam this
      // corrects). The hue-rotate-compensated pre-image rounds to these.
      expect(html, contains('--ee-bg: #eceef0;'));
      expect(html, contains('--ee-fg: #080a0c;'));
      expect(html, contains('--ee-border: #bcc0c3;'));
      expect(html, isNot(contains('--ee-bg: #101214;')));
      // The link uses a fixed light-theme blue that the filter brightens.
      expect(html, contains('--ee-link: #1a73e8;'));

      // Light mode keeps the app palette verbatim and never flags inversion.
      final lightHtml = buildSanitizedEmailHtmlForTesting('<p>Hi</p>');
      expect(lightHtml, contains('<html>'));
      expect(lightHtml, contains('--ee-bg: #ffffff;'));
    });

    test('filter-path palette lands back on the app colors', () {
      // The whole point of the pre-compensated palette: after the WebView runs
      // invert(1) hue-rotate(180deg) on the body, our surface/text/border must
      // land on the exact app colors so the body is seamless with the card. A
      // plain invert ignores the hue-rotate and drifts tinted surfaces off-hue
      // (e.g. an indigo card's blue channel by ~14) — a visible dark-mode seam.
      const bg = 0xff302f37; // indigo-tinted dark card from the real theme
      const fg = 0xffe5e1e9;
      const border = 0xff47464f;
      final html = buildSanitizedEmailHtmlForTesting(
        '<p>Hi</p>',
        backgroundColorValue: bg,
        foregroundColorValue: fg,
        linkColorValue: 0xffc4c0ff,
        borderColorValue: border,
      );

      int channel(String name) {
        final hex = RegExp('--ee-$name: #([0-9a-f]{6});').firstMatch(html)!;
        return int.parse('ff${hex.group(1)}', radix: 16);
      }

      // Simulate the CSS filter (invert THEN hue-rotate 180°) on what we emit.
      int filtered(int v) => _hueRotate180(_invert(v));
      // Each emitted channel, run through the filter, returns the app color
      // (±1 LSB rounding between Dart and the engine is imperceptible).
      _expectClose(filtered(channel('bg')), bg);
      _expectClose(filtered(channel('fg')), fg);
      _expectClose(filtered(channel('border')), border);
    });

    test('honors an email that ships its own dark color-scheme', () {
      final html = buildSanitizedEmailHtmlForTesting(
        '<style>@media (prefers-color-scheme: dark){body{background:#111}}</style>'
        '<p>Hi</p>',
        backgroundColorValue: 0xff101214,
        foregroundColorValue: 0xfff4f6f8,
        linkColorValue: 0xff8ab4f8,
        borderColorValue: 0xff3c4043,
      );

      // Email declares dark support -> render natively dark, no invert filter:
      // the <html> tag carries no data-ee-invert attribute and color-scheme is
      // dark so the email's prefers-color-scheme:dark rules match.
      expect(html, contains('<html>'));
      expect(html, contains('<meta name="color-scheme" content="dark">'));
      expect(html, contains('color-scheme: dark;'));
      // The app's dark palette is used verbatim, not pre-compensated.
      expect(html, contains('--ee-bg: #101214;'));
      expect(html, contains('--ee-link: #8ab4f8;'));
      expect(html, isNot(contains('--ee-bg: #eceef0;')));
    });

    test('contains body padding inside the width to avoid right-edge clipping', () {
      // An email that sets its own body padding must not shove content past the
      // WebView's right edge: our body is forced to width:100%, so it has to be
      // border-box or the padding adds outside the width and overflows/clips.
      final html = buildSanitizedEmailHtmlForTesting(
        '<style>body { padding: 10px; }</style><p>Hi</p>',
      );
      expect(html, contains('box-sizing: border-box !important'));
    });

    test('measures content height without using viewport height feedback', () {
      final html = buildSanitizedEmailHtmlForTesting('<p>Hello</p>');

      expect(html, contains('__EveryEmailMeasureHeight'));
      expect(html, contains('EveryEmailReady'));
      expect(html, contains("document.readyState === 'complete'"));
      expect(html, contains('email-viewport'));
      expect(html, isNot(contains('html.clientHeight')));
      expect(html, isNot(contains('constrainWidth')));
      // Late reflow is recovered by observing the content node only; observing
      // documentElement/body would re-introduce the height feedback loop.
      expect(html, contains('ResizeObserver'));
      expect(html, contains('.observe(root)'));
      expect(html, isNot(contains('observe(document.documentElement')));
      expect(html, isNot(contains('observe(document.body')));
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

// --- CSS filter simulation, mirroring the document's data-ee-invert rule ---

int _invert(int value) {
  final r = 0xff - ((value >> 16) & 0xff);
  final g = 0xff - ((value >> 8) & 0xff);
  final b = 0xff - (value & 0xff);
  return 0xff000000 | (r << 16) | (g << 8) | b;
}

int _hueRotate180(int value) {
  final red = (value >> 16) & 0xff;
  final green = (value >> 8) & 0xff;
  final blue = value & 0xff;
  int channel(double v) => v.clamp(0, 255).round();
  final r = channel(-0.574 * red + 1.430 * green + 0.144 * blue);
  final g = channel(0.426 * red + 0.430 * green + 0.144 * blue);
  final b = channel(0.426 * red + 1.430 * green - 0.856 * blue);
  return 0xff000000 | (r << 16) | (g << 8) | b;
}

void _expectClose(int actual, int expected) {
  int delta(int shift) =>
      (((actual >> shift) & 0xff) - ((expected >> shift) & 0xff)).abs();
  expect(
    delta(16) <= 1 && delta(8) <= 1 && delta(0) <= 1,
    isTrue,
    reason:
        'filtered 0x${actual.toRadixString(16)} should match app color '
        '0x${expected.toRadixString(16)} within 1 LSB per channel',
  );
}
