import 'dart:io';
import 'dart:ui' as ui;

import 'package:daily_juice/template/photo_crop.dart';
import 'package:daily_juice/template/template_layout.dart';
import 'package:daily_juice/template/template_painter.dart';
import 'package:daily_juice/template/template_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reference_juice.dart';
import 'support/template_fonts.dart';

void main() {
  setUpAll(loadTemplateFonts);

  test('reference Daily Juice reproduces the artwork line for line', () {
    final layout = TemplateLayoutEngine.compute(referenceJuice);
    expect(layout.scriptureLineTexts, referenceScriptureLines);
    expect(layout.bodyLineTexts, referenceBodyLines);
    expect(layout.titleLines, 1);
    expect(layout.fits, isTrue);
    expect(layout.paragraphGap, 1.0, reason: 'standard blank-line spacing');
  });

  test('reference fills the page exactly like the artwork', () {
    final layout = TemplateLayoutEngine.compute(referenceJuice);
    // 20 lines + 3 blank lines = the 23 line slots of the message area.
    expect(layout.pageUsage, closeTo(1.0, 0.001));
    expect(layout.divider2Top, 1254);
  });

  // Renders the reference to PNG for pixel comparison with the artwork.
  // Set DJ_RENDER_OUT (and optionally DJ_REF_PHOTO) to enable.
  test('render reference to PNG', () async {
    final out = Platform.environment['DJ_RENDER_OUT'];
    if (out == null) return;
    ui.Image? photo;
    final photoPath = Platform.environment['DJ_REF_PHOTO'];
    if (photoPath != null) {
      final codec = await ui.instantiateImageCodec(
        await File(photoPath).readAsBytes(),
      );
      photo = (await codec.getNextFrame()).image;
    }
    final layout = TemplateLayoutEngine.compute(referenceJuice);
    final png = await TemplatePainter.renderPng(
      layout,
      photo: photo,
      crop: photo == null
          ? const PhotoCrop()
          : PhotoCrop.auto(
              ui.Size(photo.width.toDouble(), photo.height.toDouble()),
              TemplateSpec.photo.size,
            ),
    );
    await File(out).writeAsBytes(png);
  });
}
