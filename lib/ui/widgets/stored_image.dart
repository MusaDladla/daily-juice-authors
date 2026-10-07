import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models/daily_juice.dart';
import '../../template/template_layout.dart';
import '../../template/template_painter.dart';
import '../../template/template_spec.dart';

/// Loads a stored photo once and keeps showing it across rebuilds (no
/// flicker while the decoded image is fetched from the cache).
class StoredImage extends StatefulWidget {
  const StoredImage({super.key, required this.path, required this.builder});

  final String path;
  final Widget Function(BuildContext context, ui.Image? image) builder;

  @override
  State<StoredImage> createState() => _StoredImageState();
}

class _StoredImageState extends State<StoredImage> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StoredImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _load();
  }

  void _load() {
    final state = AppScope.read(context);
    _image = state.peekImage(widget.path);
    if (_image != null) return;
    final path = widget.path;
    state.image(path).then((img) {
      if (mounted && widget.path == path) setState(() => _image = img);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _image);
}

/// A small live rendering of a Daily Juice page, for lists.
class JuiceThumbnail extends StatelessWidget {
  const JuiceThumbnail({super.key, required this.juice, this.width = 66});

  final DailyJuice juice;
  final double width;

  static final Map<String, TemplateLayout> _layouts = {};

  /// The (cached) page layout of [juice].
  static TemplateLayout layoutFor(DailyJuice juice) {
    final key = '${juice.id}@${juice.updatedAt.toIso8601String()}';
    final cached = _layouts[key];
    if (cached != null) return cached;
    if (_layouts.length > 200) _layouts.clear();
    return _layouts[key] = TemplateLayoutEngine.compute(juice.toContent());
  }

  TemplateLayout get _layout => layoutFor(juice);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: AspectRatio(
      aspectRatio: TemplateSpec.width / TemplateSpec.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDDBD7)),
        ),
        child: StoredImage(
          path: juice.profileImagePath,
          builder: (_, image) => CustomPaint(
            painter: TemplatePreviewPainter(
              _layout,
              photo: image,
              crop: juice.profileImageCrop,
            ),
          ),
        ),
      ),
    ),
  );
}
