// Generates the Android launcher icons (adaptive + legacy + monochrome), the
// iOS app icons, the launch-screen logo for both platforms, and the web
// version's icons.
//
//   flutter test tool/generate_launcher_icons.dart
//
// Design (108 × 108 units = one adaptive-icon canvas, safe zone 66 units):
// "DJ" with "AUTHORS" under it, on the charcoal stripes of the app header.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:daily_juice/template/template_spec.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/template_fonts.dart';

const _res = 'android/app/src/main/res';
const _iosIcons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _iosLaunch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
const _web = 'web';

/// Pixel size of the 108-unit adaptive canvas per density.
const _adaptive = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

/// Legacy (pre-Android 8) icon sizes.
const _legacy = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

const _charcoal = Color(0xFF3D3D39);
const _white = Color(0xFFFFFFFF);

/// "AUTHORS" in a white tag (like the app header) or as plain letters.
bool tagged = true;

// ------------------------------------------------------------- layers --

void _background(Canvas c) {
  c.drawRect(const Rect.fromLTWH(0, 0, 108, 108), Paint()..color = _charcoal);
  final stripe = Paint()..color = const Color(0x14FFFFFF);
  for (var x = -108.0; x < 216; x += 15) {
    c.drawPath(
      Path()
        ..moveTo(x + 82, 0)
        ..lineTo(x + 88, 0)
        ..lineTo(x + 6, 108)
        ..lineTo(x, 108)
        ..close(),
      stripe,
    );
  }
}

TextPainter _text(String text, double size, double spacing, Color color) =>
    TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: TemplateSpec.condensed,
          fontWeight: FontWeight.w700,
          fontSize: size,
          letterSpacing: spacing,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

/// Draws [tp] with its caps centred on [centerX] and its baseline at [y].
void _paintCaps(
  Canvas c,
  TextPainter tp,
  double spacing,
  double centerX,
  double y,
) {
  final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  tp.paint(c, Offset(centerX - (tp.width - spacing) / 2, y - ascent));
}

/// "DJ" over "AUTHORS", centred in the safe zone. With [mask] true the
/// letters inside the tag are cut out (Android's one-colour themed icon).
void _foreground(Canvas c, {bool mask = false}) {
  const cx = 54.0;
  const djSize = 40.0, djSpacing = 0.6;
  const djCap = djSize * 0.70;
  const auSize = 8.2, auSpacing = 1.6;
  const auCap = auSize * 0.70;
  const gap = 6.0;
  final tagPadX = tagged ? 4.2 : 0.0, tagPadY = tagged ? 3.0 : 0.0;
  final tagH = auCap + 2 * tagPadY;

  final total = djCap + gap + tagH;
  final top = 54 - total / 2;
  final djBaseline = top + djCap;
  final tagTop = djBaseline + gap;
  final auBaseline = tagTop + tagPadY + auCap;

  _paintCaps(
    c,
    _text('DJ', djSize, djSpacing, _white),
    djSpacing,
    cx,
    djBaseline,
  );

  if (!tagged) {
    _paintCaps(
      c,
      _text('AUTHORS', auSize, auSpacing, _white),
      auSpacing,
      cx,
      auBaseline,
    );
    return;
  }

  final au = _text('AUTHORS', auSize, auSpacing, _charcoal);
  final tagW = au.width - auSpacing + 2 * tagPadX;
  final tag = RRect.fromRectAndRadius(
    Rect.fromLTWH(cx - tagW / 2, tagTop, tagW, tagH),
    const Radius.circular(1.8),
  );
  if (mask) {
    c.saveLayer(const Rect.fromLTWH(0, 0, 108, 108), Paint());
    c.drawRRect(tag, Paint()..color = _white);
    c.saveLayer(
      const Rect.fromLTWH(0, 0, 108, 108),
      Paint()..blendMode = BlendMode.dstOut,
    );
    _paintCaps(c, au, auSpacing, cx, auBaseline);
    c.restore();
    c.restore();
  } else {
    c.drawRRect(tag, Paint()..color = _white);
    _paintCaps(c, au, auSpacing, cx, auBaseline);
  }
}

// ------------------------------------------------------------- output --

Future<void> _png(String path, int size, void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(size / 108);
  draw(canvas);
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
}

/// Writes an opaque RGB PNG: App Store icons must not have an alpha channel,
/// which `toByteData(format: png)` always includes.
Future<void> _rgbPng(String path, int size, void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(size / 108);
  draw(canvas);
  final image = await recorder.endRecording().toImage(size, size);
  final rgba = (await image.toByteData())!.buffer.asUint8List();
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      raw.add([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
  }
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    out
      ..add(_u32(data.length))
      ..add(body)
      ..add(_u32(_crc32(body)));
  }

  chunk('IHDR', [..._u32(size), ..._u32(size), 8, 2, 0, 0, 0]);
  chunk('IDAT', ZLibEncoder().convert(raw.takeBytes()));
  chunk('IEND', const []);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(out.takeBytes());
}

List<int> _u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = crc & 1 == 1 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

/// The full icon in a rounded square (legacy launchers, launch screen).
void _composite(Canvas c) {
  c.clipRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 108, 108),
      const Radius.circular(24),
    ),
  );
  _background(c);
  // Legacy icons have no system mask: enlarge the artwork slightly.
  c.translate(54, 54);
  c.scale(1.22);
  c.translate(-54, -54);
  _foreground(c);
}

/// What a launcher shows of an adaptive icon: the central 72 of 108 units.
void _visible(Canvas c) {
  c.scale(108 / 72);
  c.translate(-18, -18);
  _background(c);
  _foreground(c);
}

/// Review sheet: circle mask, rounded-square mask and a small size, for
/// both "AUTHORS" styles.
Future<void> _preview(String path) async {
  const cell = 108.0;
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  c.scale(2);
  c.drawRect(
    const Rect.fromLTWH(0, 0, 3 * cell + 40, 2 * cell + 30),
    Paint()..color = const Color(0xFFECE9E4),
  );
  for (var row = 0; row < 2; row++) {
    tagged = row == 0;
    final y = 10 + row * (cell + 10);
    c.save();
    c.translate(10, y);
    c.clipPath(Path()..addOval(const Rect.fromLTWH(0, 0, cell, cell)));
    _visible(c);
    c.restore();
    c.save();
    c.translate(20 + cell, y);
    c.clipRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, cell, cell),
        const Radius.circular(30),
      ),
    );
    _visible(c);
    c.restore();
    c.save();
    c.translate(30 + 2 * cell, y + 30);
    c.scale(48 / 108);
    _composite(c);
    c.restore();
  }
  tagged = true;
  final image = await recorder.endRecording().toImage(
    (2 * (3 * cell + 40)).round(),
    (2 * (2 * cell + 30)).round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(loadTemplateFonts);

  test('generate launcher icons', () async {
    final preview = Platform.environment['DJ_ICON_PREVIEW'];
    if (preview != null) {
      await _preview(preview);
      return;
    }
    for (final e in _adaptive.entries) {
      await _png(
        '$_res/mipmap-${e.key}/ic_launcher_background.png',
        e.value,
        _background,
      );
      await _png(
        '$_res/mipmap-${e.key}/ic_launcher_foreground.png',
        e.value,
        _foreground,
      );
      await _png(
        '$_res/mipmap-${e.key}/ic_launcher_monochrome.png',
        e.value,
        (c) => _foreground(c, mask: true),
      );
    }
    for (final e in _legacy.entries) {
      await _png('$_res/mipmap-${e.key}/ic_launcher.png', e.value, _composite);
    }
    await _png('$_res/drawable-xxhdpi/launch_logo.png', 288, _composite);

    // iOS: full-bleed squares (the system rounds the corners), each size
    // read from the file name, e.g. Icon-App-83.5x83.5@2x.png = 167 px.
    final name = RegExp(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png$');
    for (final f in Directory(_iosIcons).listSync().whereType<File>()) {
      final m = name.firstMatch(f.path);
      if (m == null) continue;
      final px = (double.parse(m[1]!) * int.parse(m[2]!)).round();
      await _rgbPng(f.path, px, _visible);
    }
    for (final s in const {'': 96, '@2x': 192, '@3x': 288}.entries) {
      await _png('$_iosLaunch/LaunchImage${s.key}.png', s.value, _composite);
    }

    // Web version: browser/manifest icons, maskable icons (whole adaptive
    // canvas, so any mask shape keeps the safe zone), and the iPhone Home
    // Screen icon, which must be opaque because iOS rounds it itself.
    for (final px in const [192, 512]) {
      await _png('$_web/icons/Icon-$px.png', px, _composite);
      await _rgbPng('$_web/icons/Icon-maskable-$px.png', px, (c) {
        _background(c);
        _foreground(c);
      });
    }
    await _rgbPng('$_web/icons/apple-touch-icon.png', 180, _visible);
    await _png('$_web/favicon.png', 32, _composite);
  });
}
