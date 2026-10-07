import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';

import '../core/juice_date.dart';
import 'template_spec.dart';
import 'text_measure.dart';

typedef S = TemplateSpec;

/// The author-supplied content to place into the template.
class TemplateContent {
  const TemplateContent({
    required this.authorFullName,
    required this.title,
    required this.date,
    required this.scripture,
    required this.scriptureReference,
    required this.message,
    required this.furtherStudy,
  });

  final String authorFullName;
  final String title;
  final DateTime? date;
  final String scripture;
  final String scriptureReference;
  final String message;
  final List<String> furtherStudy;

  TemplateContent copyWith({
    String? authorFullName,
    String? title,
    DateTime? date,
    String? scripture,
    String? scriptureReference,
    String? message,
    List<String>? furtherStudy,
  }) => TemplateContent(
    authorFullName: authorFullName ?? this.authorFullName,
    title: title ?? this.title,
    date: date ?? this.date,
    scripture: scripture ?? this.scripture,
    scriptureReference: scriptureReference ?? this.scriptureReference,
    message: message ?? this.message,
    furtherStudy: furtherStudy ?? this.furtherStudy,
  );
}

/// A run of text positioned on the page (x = pen start, y = baseline).
class PlacedText {
  const PlacedText(this.text, this.style, this.x, this.baseline);

  final String text;
  final TextStyle style;
  final double x;
  final double baseline;
}

/// The fully positioned page plus the fit checks that guard generation.
class TemplateLayout {
  const TemplateLayout({
    required this.texts,
    required this.divider2Top,
    required this.titleLines,
    required this.titleFits,
    required this.authorFits,
    required this.scriptureLines,
    required this.bodyLines,
    required this.bodyFits,
    required this.paragraphGap,
    required this.pageUsage,
    required this.furtherStudyFits,
    required this.bodyLineTexts,
    required this.scriptureLineTexts,
  });

  final List<PlacedText> texts;
  final double divider2Top;

  final int titleLines;
  final bool titleFits;
  final bool authorFits;
  final int scriptureLines;
  final int bodyLines;
  final bool bodyFits;

  /// 1.0 = one blank line between paragraphs (as the reference). Lower only
  /// when needed to fit, never below [TemplateSpec.paragraphGapMin].
  final double paragraphGap;

  /// Share of the message area used with standard spacing (can exceed 1.0
  /// when the content only fits with tightened paragraph spacing).
  final double pageUsage;
  final bool furtherStudyFits;

  /// The text of every body/scripture line, for tests and diagnostics.
  final List<String> bodyLineTexts;
  final List<String> scriptureLineTexts;

  bool get fits => titleFits && authorFits && bodyFits && furtherStudyFits;
  bool get spacingTightened => paragraphGap < 1.0;
}

class TemplateLayoutEngine {
  TemplateLayoutEngine._();

  /// Bumped whenever layout behaviour changes, so images exported by an
  /// older version are regenerated instead of reused.
  static const int revision = 5;

  static final RegExp _ws = RegExp(r'\s+');
  static final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

  static String _clean(String s) => s.replaceAll(_ws, ' ').trim();

  static TemplateLayout compute(TemplateContent c) {
    final texts = <PlacedText>[];

    final title = _layoutTitle(c.title);
    texts.addAll(title.texts);

    final authorFits = _layoutHeader(c, texts);

    final scripture = _layoutScripture(c.scripture, c.scriptureReference);
    texts.addAll(scripture.texts);

    final bodyFirstBaseline =
        scripture.divider2Top + S.bodyFirstBaselineBelowDivider2;
    final body = _fitBody(c.message, bodyFirstBaseline);
    texts.addAll(body.texts);

    final footerFits = _layoutFooter(c.furtherStudy, texts);

    return TemplateLayout(
      texts: texts,
      divider2Top: scripture.divider2Top,
      titleLines: title.lines,
      titleFits: title.fits,
      authorFits: authorFits,
      scriptureLines: scripture.lineTexts.length,
      bodyLines: body.lineTexts.length,
      bodyFits: body.fits,
      paragraphGap: body.gap,
      pageUsage: body.usage,
      furtherStudyFits: footerFits,
      bodyLineTexts: body.lineTexts,
      scriptureLineTexts: scripture.lineTexts,
    );
  }

  // ---------------------------------------------------------------- title --

  /// Checks only the title, for live validation while typing.
  static bool titleFits(String title) => _layoutTitle(title).fits;

  static ({List<PlacedText> texts, int lines, bool fits}) _layoutTitle(
    String raw,
  ) {
    final text = _clean(raw).toUpperCase();
    if (text.isEmpty) return (texts: const [], lines: 0, fits: true);

    const style = S.titleStyle;
    final maxW = S.titleMaxWidth;
    final cx = S.titleBox.center.dx;
    final cy = S.titleBox.center.dy;
    final w = TextMeasure.advance(style, text);
    final words = text.split(' ');
    // A comfortable title stays on one line. A longer one moves to two
    // balanced lines at the same size; a single long word stays on one line
    // as long as it fits the box.
    if (w <= S.titleSingleLineMax || words.length < 2) {
      return (
        texts: [PlacedText(text, style, cx - w / 2, cy + S.titleCapHeight / 2)],
        lines: 1,
        fits: w <= maxW,
      );
    }
    var bestSplit = 1;
    var bestWidth = double.infinity;
    for (var i = 1; i < words.length; i++) {
      final a = TextMeasure.advance(style, words.sublist(0, i).join(' '));
      final b = TextMeasure.advance(style, words.sublist(i).join(' '));
      final widest = math.max(a, b);
      if (widest < bestWidth) {
        bestWidth = widest;
        bestSplit = i;
      }
    }
    final line1 = words.sublist(0, bestSplit).join(' ');
    final line2 = words.sublist(bestSplit).join(' ');
    final w1 = TextMeasure.advance(style, line1);
    final w2 = TextMeasure.advance(style, line2);
    final base1 = cy - S.titleLinePitch / 2 + S.titleCapHeight / 2;
    return (
      texts: [
        PlacedText(line1, style, cx - w1 / 2, base1),
        PlacedText(line2, style, cx - w2 / 2, base1 + S.titleLinePitch),
      ],
      lines: 2,
      fits: bestWidth <= maxW,
    );
  }

  // --------------------------------------------------------------- header --

  static String authorLine(String fullName) =>
      'AUTHOR: ${_clean(fullName).toUpperCase()}';

  /// Whether a name fits on the author line (used by profile validation).
  static bool authorFits(String fullName) =>
      S.authorX + TextMeasure.advance(S.authorStyle, authorLine(fullName)) <=
      S.authorMaxRight;

  static bool _layoutHeader(TemplateContent c, List<PlacedText> out) {
    final author = authorLine(c.authorFullName);
    out.add(PlacedText(author, S.authorStyle, S.authorX, S.headerBaseline));
    final fits = authorFits(c.authorFullName);

    final date = c.date;
    if (date != null) {
      final d = TemplateDate.of(date);
      final wd = TextMeasure.advance(S.weekdayStyle, d.weekday);
      out.add(
        PlacedText(
          d.weekday,
          S.weekdayStyle,
          S.weekdayInkRight - wd,
          S.headerBaseline,
        ),
      );
      final numW = TextMeasure.advance(S.dateNumberStyle, d.day);
      out.add(
        PlacedText(
          d.day,
          S.dateNumberStyle,
          S.dateNumberX,
          S.dateNumberBaseline,
        ),
      );
      out.add(
        PlacedText(
          d.suffix,
          S.dateSuffixStyle,
          S.dateNumberX + numW + S.dateSuffixGap,
          S.dateSuffixBaseline,
        ),
      );
    }
    return fits;
  }

  // ------------------------------------------------------------ scripture --

  static double get _divider2BaseTop =>
      S.scriptureFirstBaseline +
      (S.scriptureSlots - 1) * S.scriptureLinePitch +
      S.referenceBaselineGap +
      S.divider2GapBelowReference;

  static String referenceDisplay(String reference) {
    final r = _clean(reference);
    if (r.isEmpty) return '';
    return r.startsWith('(') ? r : '($r)';
  }

  static ({List<PlacedText> texts, List<String> lineTexts, double divider2Top})
  _layoutScripture(String scripture, String reference) {
    const style = S.scriptureStyle;
    final words = _clean(
      scripture,
    ).split(' ').where((w) => w.isNotEmpty).toList();
    final lines = _wrap(
      words,
      maxWidth: (_) => S.scriptureMaxWidth,
      measureLine: (ws) => TextMeasure.advance(style, ws.join(' ')),
      measureWord: (w) => TextMeasure.advance(style, w),
    ).map((l) => l.join(' ')).toList();

    final n = lines.length;
    // The scripture area takes exactly the space the verse needs: the
    // template's 4 lines sit as in the artwork; a shorter verse closes the
    // gap (the message moves up) and a longer one moves the message down.
    const first = S.scriptureFirstBaseline;
    final extra = (n - S.scriptureSlots) * S.scriptureLinePitch;

    final texts = <PlacedText>[];
    for (var i = 0; i < n; i++) {
      final w = TextMeasure.advance(style, lines[i]);
      texts.add(
        PlacedText(
          lines[i],
          style,
          S.centerX - w / 2,
          first + i * S.scriptureLinePitch,
        ),
      );
    }
    final ref = referenceDisplay(reference);
    if (ref.isNotEmpty) {
      final refBaseline =
          first + (n - 1) * S.scriptureLinePitch + S.referenceBaselineGap;
      final w = TextMeasure.advance(S.referenceStyle, ref);
      texts.add(
        PlacedText(ref, S.referenceStyle, S.centerX - w / 2, refBaseline),
      );
    }
    return (
      texts: texts,
      lineTexts: lines,
      divider2Top: _divider2BaseTop + extra,
    );
  }

  // ----------------------------------------------------------------- body --

  static List<String> paragraphsOf(String message) => message
      .replaceAll('\r\n', '\n')
      .split('\n')
      .map(_clean)
      .where((p) => p.isNotEmpty)
      .toList();

  static ({
    List<PlacedText> texts,
    List<String> lineTexts,
    bool fits,
    double gap,
    double usage,
  })
  _fitBody(String message, double firstBaseline) {
    final paragraphs = paragraphsOf(message);
    final available = S.bodyMaxLastBaseline - firstBaseline + S.bodyLinePitch;
    if (paragraphs.isEmpty) {
      return (
        texts: const [],
        lineTexts: const [],
        fits: true,
        gap: 1,
        usage: 0,
      );
    }
    var body = _layoutBody(paragraphs, firstBaseline, 1.0);
    final used = body.lastBaseline - firstBaseline + S.bodyLinePitch;
    final usage = used / available;
    if (body.lastBaseline <= S.bodyMaxLastBaseline + 0.01) {
      return (
        texts: body.texts,
        lineTexts: body.lineTexts,
        fits: true,
        gap: 1,
        usage: usage,
      );
    }
    final gaps = paragraphs.length - 1;
    if (gaps > 0) {
      final overflow = body.lastBaseline - S.bodyMaxLastBaseline;
      final gap =
          ((1 - overflow / (gaps * S.bodyLinePitch)) * 100).floorToDouble() /
          100;
      if (gap >= S.paragraphGapMin) {
        body = _layoutBody(paragraphs, firstBaseline, gap);
        return (
          texts: body.texts,
          lineTexts: body.lineTexts,
          fits: true,
          gap: gap,
          usage: usage,
        );
      }
    }
    return (
      texts: body.texts,
      lineTexts: body.lineTexts,
      fits: false,
      gap: 1,
      usage: usage,
    );
  }

  static ({List<PlacedText> texts, List<String> lineTexts, double lastBaseline})
  _layoutBody(List<String> paragraphs, double firstBaseline, double gap) {
    const style = S.bodyStyle;
    final space = TextMeasure.space(style);
    final texts = <PlacedText>[];
    final lineTexts = <String>[];
    var y = firstBaseline;
    var lastBaseline = firstBaseline;

    for (var p = 0; p < paragraphs.length; p++) {
      var words = paragraphs[p].split(' ');
      var indentX = S.bodyLeft;
      var indentLines = 0;
      var minLines = 1;

      if (p == 0) {
        final split = _splitDropCap(words.first);
        texts.add(
          PlacedText(
            split.cap,
            S.dropCapStyle,
            S.dropCapX,
            y + (S.dropCapLines - 1) * S.bodyLinePitch,
          ),
        );
        indentX =
            S.dropCapX +
            TextMeasure.advance(S.dropCapStyle, split.cap) +
            S.dropCapGap;
        indentLines = S.dropCapLines;
        minLines = S.dropCapLines;
        words = [if (split.rest.isNotEmpty) split.rest, ...words.skip(1)];
      }

      double lineStart(int i) => i < indentLines ? indentX : S.bodyLeft;
      double lineWidth(int i) => S.bodyRight - lineStart(i);

      final lines = _wrap(
        words,
        maxWidth: lineWidth,
        measureLine: (ws) =>
            ws.fold<double>(0, (a, w) => a + TextMeasure.advance(style, w)) +
            space * (ws.length - 1),
        measureWord: (w) => TextMeasure.advance(style, w),
      );

      for (var i = 0; i < lines.length; i++) {
        final ws = lines[i];
        final widths = [for (final w in ws) TextMeasure.advance(style, w)];
        final isLast = i == lines.length - 1;
        final wordGap = (!isLast && ws.length > 1)
            ? (lineWidth(i) - widths.fold<double>(0, (a, b) => a + b)) /
                  (ws.length - 1)
            : space;
        var x = lineStart(i);
        final baseline = y + i * S.bodyLinePitch;
        for (var k = 0; k < ws.length; k++) {
          texts.add(PlacedText(ws[k], style, x, baseline));
          x += widths[k] + wordGap;
        }
        lineTexts.add(ws.join(' '));
      }

      final occupied = math.max(lines.length, minLines);
      lastBaseline = y + (occupied - 1) * S.bodyLinePitch;
      y = lastBaseline + S.bodyLinePitch * (1 + gap);
    }
    return (texts: texts, lineTexts: lineTexts, lastBaseline: lastBaseline);
  }

  /// The drop cap is the first letter, together with any opening
  /// punctuation before it (e.g. `“B`).
  static ({String cap, String rest}) _splitDropCap(String word) {
    final chars = word.characters.toList();
    var i = 0;
    while (i < chars.length && !_letterOrDigit.hasMatch(chars[i])) {
      i++;
    }
    if (i >= chars.length) i = 0;
    return (
      cap: chars.sublist(0, i + 1).join(),
      rest: chars.sublist(i + 1).join(),
    );
  }

  // --------------------------------------------------------------- footer --

  static String furtherStudyLine(List<String> refs) => refs
      .map(_clean)
      .where((r) => r.isNotEmpty)
      .map((r) => r.toUpperCase())
      .join(S.furtherStudySeparator);

  static bool furtherStudyFits(List<String> refs) =>
      TextMeasure.advance(S.furtherStudyStyle, furtherStudyLine(refs)) <=
      S.furtherStudyMaxWidth;

  static bool _layoutFooter(List<String> refs, List<PlacedText> out) {
    const h = S.furtherStudyHeading;
    final hw = TextMeasure.advance(S.furtherStudyHeadingStyle, h);
    out.add(
      PlacedText(
        h,
        S.furtherStudyHeadingStyle,
        S.centerX - hw / 2,
        S.furtherStudyHeadingBaseline,
      ),
    );

    final line = furtherStudyLine(refs);
    final w = TextMeasure.advance(S.furtherStudyStyle, line);
    if (line.isNotEmpty) {
      out.add(
        PlacedText(
          line,
          S.furtherStudyStyle,
          S.centerX - w / 2,
          S.furtherStudyBaseline,
        ),
      );
    }
    out.add(
      PlacedText(
        S.nextPageText,
        S.nextPageStyle,
        S.nextPageX,
        S.nextPageBaseline,
      ),
    );
    return w <= S.furtherStudyMaxWidth;
  }

  // ------------------------------------------------------------- wrapping --

  /// Greedy line breaking. A single word wider than a whole line (e.g. a
  /// pasted URL) is broken across lines so nothing can run off the page.
  static List<List<String>> _wrap(
    List<String> words, {
    required double Function(int lineIndex) maxWidth,
    required double Function(List<String> words) measureLine,
    required double Function(String word) measureWord,
  }) {
    final lines = <List<String>>[];
    var current = <String>[];

    void flush() {
      if (current.isNotEmpty) {
        lines.add(current);
        current = <String>[];
      }
    }

    for (final word in words) {
      if (word.isEmpty) continue;
      final candidate = [...current, word];
      if (measureLine(candidate) <= maxWidth(lines.length)) {
        current = candidate;
        continue;
      }
      flush();
      if (measureWord(word) <= maxWidth(lines.length)) {
        current = [word];
        continue;
      }
      // Hard-break an over-long word.
      var piece = '';
      for (final ch in word.characters) {
        if (piece.isNotEmpty &&
            measureWord(piece + ch) > maxWidth(lines.length)) {
          lines.add([piece]);
          piece = ch;
        } else {
          piece += ch;
        }
      }
      current = [piece];
    }
    flush();
    return lines;
  }
}
