import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../template/photo_crop.dart';
import '../../template/template_layout.dart';
import '../../template/template_painter.dart';
import '../../template/template_spec.dart';
import '../theme.dart';

/// Which part of the page the author is currently working on.
enum PreviewFocus { header, scripture, message, furtherStudy }

/// A live strip of the real template, scrolled to the part being edited, so
/// the author sees their words land on the page while the keyboard is open.
class FocusPreview extends StatelessWidget {
  const FocusPreview({
    super.key,
    required this.layout,
    required this.photo,
    required this.crop,
    required this.focus,
    this.onOpenFullPreview,
    this.onHide,
    this.height = 156,
  });

  final TemplateLayout layout;
  final ui.Image? photo;
  final PhotoCrop crop;
  final PreviewFocus focus;
  final VoidCallback? onOpenFullPreview;
  final VoidCallback? onHide;
  final double height;

  /// Top of the visible window, in template pixels.
  double _top(double visible) {
    final maxTop = TemplateSpec.height - visible;
    switch (focus) {
      case PreviewFocus.header:
        return 0;
      case PreviewFocus.scripture:
        return math.min(TemplateSpec.divider1Top - 30, maxTop);
      case PreviewFocus.message:
        // Follow the last line written.
        final body = layout.texts.where(
          (t) =>
              t.style == TemplateSpec.bodyStyle ||
              t.style == TemplateSpec.dropCapStyle,
        );
        final start = layout.divider2Top - 20;
        if (body.isEmpty) return math.min(start, maxTop);
        final last = body.map((t) => t.baseline).reduce(math.max);
        return (last + 60 - visible).clamp(start, maxTop);
      case PreviewFocus.furtherStudy:
        return maxTop;
    }
  }

  /// The editor's strip is framed and labelled so it stands out from the
  /// form; elsewhere (profile) it is a plain window onto the page.
  bool get _framed => onOpenFullPreview != null && onHide != null;

  SectionStyle get _areaStyle => switch (focus) {
    PreviewFocus.header => SectionStyle.title,
    PreviewFocus.scripture => SectionStyle.scripture,
    PreviewFocus.message => SectionStyle.message,
    PreviewFocus.furtherStudy => SectionStyle.furtherStudy,
  };

  String get _areaLabel => switch (focus) {
    PreviewFocus.header => 'TITLE',
    PreviewFocus.scripture => 'THEME SCRIPTURE',
    PreviewFocus.message => 'MAIN MESSAGE',
    PreviewFocus.furtherStudy => 'FURTHER STUDY',
  };

  Widget _window() => LayoutBuilder(
    builder: (context, c) {
      final scale = c.maxWidth / TemplateSpec.width;
      final visible = c.maxHeight / scale;
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onOpenFullPreview,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _top(visible)),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                builder: (_, top, _) => ClipRect(
                  child: CustomPaint(
                    painter: _WindowPainter(layout, photo, crop, top, scale),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    if (!_framed) {
      return Material(
        color: const Color(0xFFE2E0DC),
        child: SizedBox(height: height, child: _window()),
      );
    }
    // A titled panel: label and controls on top, then a bordered "sheet of
    // paper", with a dark rule underneath separating it from the form.
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: Color(0xFFE2E0DC),
        border: Border(bottom: BorderSide(color: _areaStyle.color, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _LiveLabel(_areaLabel, _areaStyle.color),
                  ),
                ),
                const SizedBox(width: 6),
                _Pill(
                  icon: Icons.open_in_full,
                  label: 'Full page',
                  onTap: onOpenFullPreview!,
                ),
                const SizedBox(width: 6),
                _Pill(icon: Icons.expand_less, onTap: onHide!),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _areaStyle.color, width: 1.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.5),
                child: _window(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "● LIVE · MAIN MESSAGE": which part of the page is shown.
class _LiveLabel extends StatelessWidget {
  const _LiveLabel(this.area, this.color);

  final String area;

  /// The colour of the section being edited.
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'LIVE · $area',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: Brand.condensed,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.8,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.onTap, this.label});

  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xCC3D3D39),
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _WindowPainter extends CustomPainter {
  _WindowPainter(this.layout, this.photo, this.crop, this.top, this.scale);

  final TemplateLayout layout;
  final ui.Image? photo;
  final PhotoCrop crop;
  final double top;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    canvas.translate(0, -top);
    TemplatePainter.paint(canvas, layout, photo: photo, crop: crop);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WindowPainter old) =>
      !identical(old.layout, layout) ||
      old.top != top ||
      old.scale != scale ||
      old.photo != photo ||
      old.crop != crop;
}
