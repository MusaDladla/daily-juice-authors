import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/browser_text_box.dart';
import '../../template/photo_crop.dart';
import '../../template/template_layout.dart';
import '../../template/template_painter.dart';
import '../theme.dart';

/// A part of the Daily Juice page that can be tapped in the LIVE PREVIEW.
enum PagePart {
  photo,
  title,
  author,
  date,
  scripture,
  reference,
  message,
  furtherStudy;

  /// Parts typed straight onto the page, in page order.
  static const editable = [title, scripture, reference, message, furtherStudy];

  /// Photo and author name come from the profile.
  bool get locked => this == photo || this == author;

  String get label => switch (this) {
    photo || author => 'PROFILE',
    title => 'TITLE',
    date => 'DATE',
    scripture => 'THEME SCRIPTURE',
    reference => 'SCRIPTURE REFERENCE',
    message => 'MAIN MESSAGE',
    furtherStudy => 'FURTHER STUDY',
  };
}

/// Where each part sits on the page, in template pixels.
class PageGeometry {
  PageGeometry._();

  /// Baseline of the Scripture reference line.
  static double referenceBaseline(TemplateLayout layout) =>
      S.scriptureFirstBaseline +
      (layout.scriptureLines - 1) * S.scriptureLinePitch +
      S.referenceBaselineGap;

  /// First baseline of the Main Message.
  static double messageBaseline(TemplateLayout layout) =>
      layout.divider2Top + S.bodyFirstBaselineBelowDivider2;

  /// The tappable area of every part.
  static Map<PagePart, Rect> regions(TemplateLayout layout) {
    final refBase = referenceBaseline(layout);
    return {
      PagePart.photo: S.photo,
      PagePart.title: S.titleBox,
      PagePart.author: Rect.fromLTRB(
        S.authorBar.left,
        S.authorBar.top,
        S.authorMaxRight - 12,
        S.authorBar.bottom,
      ),
      PagePart.date: Rect.fromLTRB(
        S.authorMaxRight,
        S.authorBar.top,
        S.authorBar.right,
        S.authorBar.bottom,
      ),
      // With no verse yet, the page has no room for it: the whole space
      // between the rules is the Theme Scripture (the reference follows it
      // with ›), so it can still be tapped.
      if (layout.scriptureLines == 0)
        PagePart.scripture: Rect.fromLTRB(
          S.dividerLeft,
          S.divider1Top + 17,
          S.dividerRight,
          layout.divider2Top - 4,
        )
      else ...{
        PagePart.scripture: Rect.fromLTRB(
          S.dividerLeft,
          S.divider1Top + 17,
          S.dividerRight,
          math.max(refBase - 92, S.divider1Top + 131),
        ),
        PagePart.reference: Rect.fromLTRB(
          S.dividerLeft,
          refBase - 86,
          S.dividerRight,
          refBase + 26,
        ),
      },
      PagePart.message: Rect.fromLTRB(
        S.dividerLeft,
        layout.divider2Top + 36,
        S.dividerRight,
        S.bodyMaxLastBaseline + 42,
      ),
      PagePart.furtherStudy: Rect.fromLTRB(
        S.dividerLeft,
        S.furtherStudyHeadingBaseline - 75,
        S.dividerRight,
        S.height - 8,
      ),
    };
  }

  /// The part of the page shown while [part] is being edited.
  static Rect zoomRect(PagePart part, TemplateLayout layout) => switch (part) {
    PagePart.title => const Rect.fromLTWH(470, 60, 1960, 470),
    PagePart.scripture => const Rect.fromLTWH(100, 670, 2304, 600),
    PagePart.reference => Rect.fromLTWH(
      100,
      referenceBaseline(layout) - 260,
      2304,
      340,
    ),
    PagePart.message => Rect.fromLTWH(100, layout.divider2Top + 24, 2304, 1800),
    _ => const Rect.fromLTWH(100, 3270, 2304, 238),
  };

  /// The page without the text of [part], which its editor shows instead.
  static TemplateLayout without(TemplateLayout layout, PagePart part) {
    bool hidden(PlacedText t) => switch (part) {
      PagePart.title => t.style == S.titleStyle,
      PagePart.scripture => t.style == S.scriptureStyle,
      PagePart.reference => t.style == S.referenceStyle,
      PagePart.message => t.style == S.bodyStyle || t.style == S.dropCapStyle,
      PagePart.furtherStudy => t.style == S.furtherStudyStyle,
      _ => false,
    };
    return TemplateLayout(
      texts: [
        for (final t in layout.texts)
          if (!hidden(t)) t,
      ],
      divider2Top: layout.divider2Top,
      titleLines: layout.titleLines,
      titleFits: layout.titleFits,
      authorFits: layout.authorFits,
      scriptureLines: layout.scriptureLines,
      bodyLines: layout.bodyLines,
      bodyFits: layout.bodyFits,
      paragraphGap: layout.paragraphGap,
      pageUsage: layout.pageUsage,
      furtherStudyFits: layout.furtherStudyFits,
      bodyLineTexts: layout.bodyLineTexts,
      scriptureLineTexts: layout.scriptureLineTexts,
    );
  }
}

/// A text field drawn over the page in the template's own lettering.
///
/// [style], [pitch] and [width] are template pixels; the field is drawn at
/// screen size ([scale] screen pixels per template pixel) on top of the
/// zoomed page, not inside it, so its cursor, selection handles and the
/// Cut / Copy / Paste menu stay normal size.
class PageInput extends StatefulWidget {
  const PageInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.pitch,
    required this.width,
    required this.scale,
    this.textAlign = TextAlign.center,
    this.multiline = false,
    this.minLines,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.sentences,
    this.textInputAction,
    this.onSubmitted,
    this.hintText,
    this.capitals = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;

  /// Distance between baselines, as on the template.
  final double pitch;
  final double width;
  final double scale;
  final TextAlign textAlign;

  /// Multi-line text; otherwise long text still wraps but Enter is refused.
  final bool multiline;
  final int? minLines;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;

  /// Shows the text in capitals, as the page prints it, while the author's
  /// text is kept exactly as typed.
  final bool capitals;

  /// Space between the text and the outline, in screen pixels.
  static const double padding = 4;

  /// The template [style] at screen size, one line every [pitch].
  static TextStyle lineStyle(TextStyle style, double pitch, double scale) =>
      style.copyWith(
        fontSize: style.fontSize! * scale,
        // Explicit, so the app's own text style adds no spacing.
        letterSpacing: (style.letterSpacing ?? 0) * scale,
        wordSpacing: 0,
        height: pitch / style.fontSize!,
      );

  static StrutStyle strut(TextStyle style, double pitch, double scale) =>
      StrutStyle(
        fontFamily: style.fontFamily,
        fontSize: style.fontSize! * scale,
        fontWeight: style.fontWeight,
        height: pitch / style.fontSize!,
        forceStrutHeight: true,
      );

  /// Screen position of a field whose text starts at template [x].
  static double leftFor(double x, double scale) => x * scale - padding;

  /// Screen position of a field whose first line has its baseline at
  /// template [baseline].
  static double topFor(
    TextStyle style,
    double pitch,
    double baseline,
    double scale,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: 'Hg', style: lineStyle(style, pitch, scale)),
      strutStyle: strut(style, pitch, scale),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final offset = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    painter.dispose();
    return baseline * scale - offset - padding;
  }

  /// Width (template pixels) of a field showing [text] on one line, cursor
  /// included. Measured at screen size, where small text can come out a
  /// little wider than the template measure.
  static double fieldWidth(
    TextStyle style,
    double pitch,
    String text,
    double scale,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: lineStyle(style, pitch, scale)),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return (width + 12) / scale;
  }

  @override
  State<PageInput> createState() => _PageInputState();
}

class _PageInputState extends State<PageInput> {
  /// Web app (Safari, Chrome): the browser's own Cut / Copy / Paste menu
  /// doesn't work on the page fields, so they show the app's menu instead,
  /// as in the Android app.
  static bool get _appMenu => kIsWeb;

  /// Page fields on screen; the browser's menu is back once there are none.
  static int _open = 0;

  /// The field's own copy of the text when it shows capitals.
  _CapitalsController? _shown;

  TextEditingController get _controller => _shown ?? widget.controller;

  @override
  void initState() {
    super.initState();
    if (_appMenu && _open++ == 0) {
      BrowserContextMenu.disableContextMenu();
      // Every touch goes to the app, so its menu shows every time.
      browserTextBoxTouches(enabled: false);
    }
    if (widget.capitals) {
      _shown = _CapitalsController()..value = widget.controller.value;
      _shown!.addListener(_toSource);
      widget.controller.addListener(_fromSource);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_fromSource);
    _shown?.dispose();
    if (_appMenu && --_open == 0) {
      BrowserContextMenu.enableContextMenu();
      browserTextBoxTouches(enabled: true);
    }
    super.dispose();
  }

  void _toSource() {
    if (widget.controller.text != _shown!.text) {
      widget.controller.value = _shown!.value;
    }
  }

  void _fromSource() {
    if (_shown!.text != widget.controller.text) {
      _shown!.value = widget.controller.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final line = PageInput.lineStyle(widget.style, widget.pitch, scale);
    return Container(
      padding: const EdgeInsets.all(PageInput.padding),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        border: Border.all(color: SectionStyle.accent, width: 2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: SizedBox(
        width: widget.width * scale,
        child: TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          style: line,
          strutStyle: PageInput.strut(widget.style, widget.pitch, scale),
          textAlign: widget.textAlign,
          maxLines: null,
          minLines: widget.minLines,
          keyboardType: widget.multiline
              ? TextInputType.multiline
              : TextInputType.text,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          inputFormatters: [
            if (!widget.multiline)
              FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
            ...?widget.inputFormatters,
          ],
          cursorColor: SectionStyle.accent,
          cursorWidth: 2.5,
          // Keep the caret clear of the screen edges while typing.
          scrollPadding: const EdgeInsets.symmetric(vertical: 60),
          // Only the text: none of the app's field border, fill or padding,
          // so it lines up with the page.
          decoration: InputDecoration(
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            hintText: widget.hintText,
            // A long example must not make the field taller than its text.
            hintMaxLines: 1,
            hintStyle: line.copyWith(
              color: Colors.black.withValues(alpha: 0.24),
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays its text in capitals without changing it. Where capitals would
/// change the length (e.g. "ß"), the text is shown as typed.
class _CapitalsController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final upper = text.toUpperCase();
    if (upper.length != text.length) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(style: style, text: upper);
  }
}

/// The LIVE PREVIEW while editing on the page: the whole page with every
/// part outlined while choosing, or zoomed to one part while typing into it.
class PageEditorView extends StatefulWidget {
  const PageEditorView({
    super.key,
    required this.layout,
    required this.photo,
    required this.crop,
    required this.part,
    required this.onTap,
    required this.editors,
  });

  final TemplateLayout layout;
  final ui.Image? photo;
  final PhotoCrop crop;

  /// The part being typed into; null while choosing.
  final PagePart? part;
  final ValueChanged<PagePart> onTap;

  /// The fields for [part], positioned in screen pixels over the page, which
  /// is drawn at [scale] screen pixels per template pixel.
  final List<Widget> Function(double scale) editors;

  @override
  State<PageEditorView> createState() => _PageEditorViewState();
}

class _PageEditorViewState extends State<PageEditorView> {
  final _scroll = ScrollController();
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _scrollToPart(animate: false);
  }

  @override
  void didUpdateWidget(PageEditorView old) {
    super.didUpdateWidget(old);
    if (old.part != widget.part) _scrollToPart(animate: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the part being edited to the top, once the zoom is laid out.
  void _scrollToPart({required bool animate}) {
    final part = widget.part;
    if (part == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final rect = PageGeometry.zoomRect(part, widget.layout);
      final target = (rect.top * _scale - 8).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      if (animate) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Widget _page(double scale) {
    final part = widget.part;
    final shown = part == null
        ? widget.layout
        : PageGeometry.without(widget.layout, part);
    return SizedBox(
      width: S.width,
      height: S.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x33000000),
                    blurRadius: 12 / scale,
                    offset: Offset(0, 4 / scale),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: TemplatePreviewPainter(
                  shown,
                  photo: widget.photo,
                  crop: widget.crop,
                ),
              ),
            ),
          ),
          for (final MapEntry(key: p, value: rect) in PageGeometry.regions(
            widget.layout,
          ).entries)
            if (p != part)
              Positioned.fromRect(
                rect: rect,
                child: _Region(
                  part: p,
                  scale: scale,
                  quiet: part != null,
                  onTap: () => widget.onTap(p),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final part = widget.part;
      if (part == null) {
        // Choosing: the whole page, as in the normal preview.
        final scale = math.min(
          (c.maxWidth - 32) / S.width,
          (c.maxHeight - 32) / S.height,
        );
        _scale = scale;
        return Stack(
          children: [
            Positioned(
              left: (c.maxWidth - S.width * scale) / 2,
              top: (c.maxHeight - S.height * scale) / 2,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: _page(scale),
              ),
            ),
          ],
        );
      }
      // Typing: the part fills the width; the page scrolls under it.
      final rect = PageGeometry.zoomRect(part, widget.layout);
      final scale = (c.maxWidth - 12) / rect.width;
      _scale = scale;
      return SingleChildScrollView(
        controller: _scroll,
        child: SizedBox(
          width: c.maxWidth,
          height: S.height * scale + c.maxHeight * 0.6,
          child: Stack(
            children: [
              Positioned(
                left: 6 - rect.left * scale,
                top: 0,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: _page(scale),
                ),
              ),
              // The fields, at screen size over the page (see PageInput).
              Positioned(
                left: 6 - rect.left * scale,
                top: 0,
                width: S.width * scale,
                height: S.height * scale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: widget.editors(scale),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One tappable part of the page, outlined, with its name.
class _Region extends StatelessWidget {
  const _Region({
    required this.part,
    required this.scale,
    required this.quiet,
    required this.onTap,
  });

  final PagePart part;
  final double scale;

  /// While another part is being edited: faint, without its name.
  final bool quiet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = part.locked ? const Color(0xFF8E8C87) : SectionStyle.accent;
    return Semantics(
      button: true,
      label: part.locked
          ? '${part == PagePart.photo ? 'Photo' : 'Author name'}: set in your profile'
          : 'Edit ${part.label.toLowerCase()}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: quiet ? 0.4 : 1,
          child: CustomPaint(
            painter: _DashedOutline(
              color: color,
              scale: scale,
              fill: quiet ? null : color.withValues(alpha: 0.07),
            ),
            child: quiet
                ? const SizedBox.expand()
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const SizedBox.expand(),
                      // Inside the outline, so tapping the name works too.
                      Positioned(
                        left: 4 / scale,
                        top: 3 / scale,
                        child: _Tag(part: part, scale: scale, color: color),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.part, required this.scale, required this.color});

  final PagePart part;
  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 6 / scale, vertical: 2 / scale),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4 / scale),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (part.locked) ...[
          Icon(Icons.lock_outline, size: 10 / scale, color: Colors.white),
          SizedBox(width: 3 / scale),
        ],
        // The photo's tag is only the lock: there is no room for a word.
        if (part != PagePart.photo)
          Text(
            part.label,
            style: TextStyle(
              fontFamily: Brand.condensed,
              fontWeight: FontWeight.w700,
              fontSize: 10.5 / scale,
              letterSpacing: 0.6 / scale,
              color: Colors.white,
              height: 1.2,
            ),
          ),
      ],
    ),
  );
}

class _DashedOutline extends CustomPainter {
  _DashedOutline({required this.color, required this.scale, this.fill});

  final Color color;
  final double scale;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(5 / scale),
    );
    if (fill != null) canvas.drawRRect(rrect, Paint()..color = fill!);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 / scale;
    final dash = 5 / scale, gap = 4 / scale;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) =>
      old.color != color || old.scale != scale || old.fill != fill;
}
