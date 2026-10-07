import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../template/photo_crop.dart';
import '../../template/template_layout.dart';
import '../../template/template_painter.dart';
import '../../template/template_spec.dart';

/// The live Daily Juice page, drawn by the same painter as the export.
class JuicePreview extends StatelessWidget {
  const JuicePreview({
    super.key,
    required this.layout,
    required this.photo,
    required this.crop,
  });

  final TemplateLayout layout;
  final ui.Image? photo;
  final PhotoCrop crop;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: TemplateSpec.width / TemplateSpec.height,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: TemplatePreviewPainter(layout, photo: photo, crop: crop),
        ),
      ),
    ),
  );
}

/// Full-screen zoomable page, for checking details on a phone.
class ZoomablePreview extends StatelessWidget {
  const ZoomablePreview({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    minScale: 1,
    maxScale: 6,
    boundaryMargin: const EdgeInsets.all(40),
    child: Center(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}
