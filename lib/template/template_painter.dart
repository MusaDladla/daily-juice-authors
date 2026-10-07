import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'photo_crop.dart';
import 'template_layout.dart';
import 'text_measure.dart';

/// Draws a [TemplateLayout] in template coordinates (2480 × 3508).
///
/// The live preview and the exported image both use this one function, so
/// the preview is exactly the final Daily Juice.
class TemplatePainter {
  TemplatePainter._();

  static void paint(
    Canvas canvas,
    TemplateLayout layout, {
    ui.Image? photo,
    PhotoCrop crop = const PhotoCrop(),
  }) {
    canvas.drawRect(Offset.zero & S.size, Paint()..color = S.paper);
    _paintLeftStrip(canvas);
    _paintStripes(canvas, S.topBand);
    _paintPhoto(canvas, photo, crop);
    _paintStripes(canvas, S.titleBox);

    canvas.drawRect(S.authorBar, Paint()..color = S.barGray);
    canvas.drawRect(S.dateBoxRect, Paint()..color = S.dateBox);

    _paintDivider(canvas, S.divider1Top);
    _paintDivider(canvas, layout.divider2Top);

    canvas.drawRect(S.footerRule, Paint()..color = S.ink);
    final t = S.nextPageTriangle;
    canvas.drawPath(
      Path()
        ..moveTo(t.left, t.top)
        ..lineTo(t.right, t.center.dy)
        ..lineTo(t.left, t.bottom)
        ..close(),
      Paint()..color = S.ink,
    );

    for (final placed in layout.texts) {
      TextMeasure.paint(
        canvas,
        placed.style,
        placed.text,
        placed.x,
        placed.baseline,
      );
    }
  }

  static void _paintLeftStrip(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, S.stripWidth, S.height),
      Paint()..color = S.barGray,
    );
    final white = Paint()..color = S.paper;
    const dy = S.stripSlope * S.stripWidth;
    for (final top in S.stripWhiteBandTops) {
      canvas.drawPath(
        Path()
          ..moveTo(0, top)
          ..lineTo(S.stripWidth, top + dy)
          ..lineTo(S.stripWidth, top + dy + S.stripWhiteBandHeight)
          ..lineTo(0, top + S.stripWhiteBandHeight)
          ..close(),
        white,
      );
    }
  }

  static void _paintStripes(Canvas canvas, Rect area) {
    canvas.save();
    canvas.clipRect(area);
    canvas.drawRect(area, Paint()..color = S.stripeGray);
    final white = Paint()..color = S.paper;
    final topShift = S.stripeSlope * area.top;
    final bottomShift = S.stripeSlope * area.bottom;
    // Cover every stripe that can intersect the area.
    final kMin =
        ((area.left - S.stripeOriginX - topShift) / S.stripePeriod).floor() - 1;
    final kMax =
        ((area.right - S.stripeOriginX - bottomShift) / S.stripePeriod).ceil() +
        1;
    for (var k = kMin; k <= kMax; k++) {
      final x0 = S.stripeOriginX + k * S.stripePeriod;
      canvas.drawPath(
        Path()
          ..moveTo(x0 + topShift, area.top)
          ..lineTo(x0 + topShift + S.stripeWhiteWidth, area.top)
          ..lineTo(x0 + bottomShift + S.stripeWhiteWidth, area.bottom)
          ..lineTo(x0 + bottomShift, area.bottom)
          ..close(),
        white,
      );
    }
    canvas.restore();
  }

  static void _paintPhoto(Canvas canvas, ui.Image? photo, PhotoCrop crop) {
    final slot = S.photo;
    canvas.drawRect(
      slot.shift(S.photoShadowOffset),
      Paint()
        ..color = S.photoShadow
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          S.photoShadowSigma,
        ),
    );
    if (photo == null) {
      canvas.drawRect(slot, Paint()..color = const Color(0xFFD9D9D9));
      return;
    }
    final image = Size(photo.width.toDouble(), photo.height.toDouble());
    canvas.drawImageRect(
      photo,
      crop.sourceRect(image, slot.size),
      slot,
      Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );
  }

  static void _paintDivider(Canvas canvas, double top) {
    final paint = Paint()..color = S.divider;
    for (final (offset, thickness) in S.dividerLines) {
      canvas.drawRect(
        Rect.fromLTRB(
          S.dividerLeft,
          top + offset,
          S.dividerRight,
          top + offset + thickness,
        ),
        paint,
      );
    }
  }

  /// Renders the finished Daily Juice at full template resolution as PNG.
  static Future<Uint8List> renderPng(
    TemplateLayout layout, {
    ui.Image? photo,
    PhotoCrop crop = const PhotoCrop(),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & S.size);
    paint(canvas, layout, photo: photo, crop: crop);
    final picture = recorder.endRecording();
    final image = await picture.toImage(S.width.toInt(), S.height.toInt());
    picture.dispose();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

/// Live preview: paints the template scaled to the widget size.
class TemplatePreviewPainter extends CustomPainter {
  TemplatePreviewPainter(
    this.layout, {
    this.photo,
    this.crop = const PhotoCrop(),
  });

  final TemplateLayout layout;
  final ui.Image? photo;
  final PhotoCrop crop;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / S.width);
    TemplatePainter.paint(canvas, layout, photo: photo, crop: crop);
    canvas.restore();
  }

  @override
  bool shouldRepaint(TemplatePreviewPainter old) =>
      !identical(old.layout, layout) || old.photo != photo || old.crop != crop;
}
