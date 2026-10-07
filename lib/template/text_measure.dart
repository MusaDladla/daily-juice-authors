import 'package:flutter/painting.dart';

/// Measures and paints single-line text with the template fonts.
///
/// Layout and painting share the same cached [TextPainter]s, so what the
/// layout engine measures is exactly what gets drawn.
class TextMeasure {
  TextMeasure._();

  static final Map<TextStyle, Map<String, TextPainter>> _cache = {};
  static final Map<TextStyle, double> _spaceCache = {};
  static const int _maxPerStyle = 1500;

  static TextPainter painter(TextStyle style, String text) {
    final byStyle = _cache.putIfAbsent(style, () => <String, TextPainter>{});
    final cached = byStyle[text];
    if (cached != null) return cached;
    if (byStyle.length >= _maxPerStyle) {
      for (final p in byStyle.values) {
        p.dispose();
      }
      byStyle.clear();
    }
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    byStyle[text] = tp;
    return tp;
  }

  /// Visual advance width of [text]. Letter spacing is applied between
  /// characters only (the engine also adds it after the last character,
  /// which is not part of the visible width).
  static double advance(TextStyle style, String text) {
    if (text.isEmpty) return 0;
    return painter(style, text).width - (style.letterSpacing ?? 0);
  }

  /// Width of one space between words, independent of side bearings.
  static double space(TextStyle style) => _spaceCache.putIfAbsent(
    style,
    () => advance(style, 'n n') - 2 * advance(style, 'n'),
  );

  /// Paints [text] with its alphabetic baseline at [baseline].
  static void paint(
    Canvas canvas,
    TextStyle style,
    String text,
    double x,
    double baseline,
  ) {
    if (text.isEmpty) return;
    final tp = painter(style, text);
    final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(x, baseline - ascent));
  }

  static void clear() {
    for (final byStyle in _cache.values) {
      for (final p in byStyle.values) {
        p.dispose();
      }
    }
    _cache.clear();
    _spaceCache.clear();
  }
}
