import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../template/photo_crop.dart';
import '../../template/template_spec.dart';
import '../theme.dart';

/// Shows a photo cropped exactly as it appears in the template's photo slot.
class CroppedPhoto extends StatelessWidget {
  const CroppedPhoto({super.key, required this.image, required this.crop});

  final ui.Image? image;
  final PhotoCrop crop;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: TemplateSpec.photo.width / TemplateSpec.photo.height,
    child: CustomPaint(painter: _CropPainter(image, crop)),
  );
}

/// Positions the author's photo in the template's photo slot: drag it,
/// pinch or slide to zoom, or use the arrows to move it up, down, left and
/// right. Scaling is always uniform, so the face is never distorted.
class PhotoFramer extends StatefulWidget {
  const PhotoFramer({
    super.key,
    required this.image,
    required this.crop,
    required this.onChanged,
  });

  final ui.Image image;
  final PhotoCrop crop;
  final ValueChanged<PhotoCrop> onChanged;

  @override
  State<PhotoFramer> createState() => _PhotoFramerState();
}

class _PhotoFramerState extends State<PhotoFramer> {
  double _startZoom = 1;
  Timer? _repeat;

  /// One arrow press moves the photo by this many slot pixels.
  static const double _step = 10;

  Size get _imageSize =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());
  Size get _slot => TemplateSpec.photo.size;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  /// Moves the photo one step in [direction] (e.g. up = (0, -1)).
  ///
  /// When the photo already fills the frame edge-to-edge in that direction
  /// it is zoomed in slightly first, so the arrow always has an effect and
  /// no empty space can appear in the frame.
  void _nudge(Offset direction) {
    final delta = direction * _step;
    final current = widget.crop;
    var next = current.panBy(delta, _imageSize, _slot);
    if (_same(next, current) && current.zoom < PhotoCrop.maxZoom) {
      next = current
          .withZoom(current.zoom * 1.04)
          .panBy(delta, _imageSize, _slot);
    }
    if (!_same(next, current)) widget.onChanged(next);
  }

  static bool _same(PhotoCrop a, PhotoCrop b) =>
      (a.cx - b.cx).abs() < 1e-6 &&
      (a.cy - b.cy).abs() < 1e-6 &&
      (a.zoom - b.zoom).abs() < 1e-6;

  void _startRepeat(Offset direction) {
    HapticFeedback.selectionClick();
    _nudge(direction);
    _repeat?.cancel();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 70),
      (_) => _nudge(direction),
    );
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  void _reset() {
    HapticFeedback.selectionClick();
    widget.onChanged(PhotoCrop.auto(_imageSize, _slot));
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Center(
        child: SizedBox(
          width: 210,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                onScaleStart: (_) => _startZoom = widget.crop.zoom,
                onScaleUpdate: (d) {
                  final toSlot = _slot.width / width;
                  var crop = widget.crop;
                  if (d.pointerCount > 1) {
                    crop = crop.withZoom(_startZoom * d.scale);
                  }
                  crop = crop.panBy(
                    d.focalPointDelta * toSlot,
                    _imageSize,
                    _slot,
                  );
                  widget.onChanged(crop);
                },
                child: Stack(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFBDBBB7)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 8,
                            offset: Offset(3, 4),
                          ),
                        ],
                      ),
                      child: CroppedPhoto(
                        image: widget.image,
                        crop: widget.crop,
                      ),
                    ),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0x993D3D39),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.open_with,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          const Icon(Icons.zoom_out, size: 20, color: Brand.muted),
          Expanded(
            child: Slider(
              value: widget.crop.zoom.clamp(1.0, PhotoCrop.maxZoom),
              min: 1,
              max: PhotoCrop.maxZoom,
              label: 'Zoom',
              onChanged: (z) => widget.onChanged(
                widget.crop.withZoom(z).panBy(Offset.zero, _imageSize, _slot),
              ),
            ),
          ),
          const Icon(Icons.zoom_in, size: 20, color: Brand.muted),
        ],
      ),
      const SizedBox(height: 4),
      _MovePad(onStart: _startRepeat, onEnd: _stopRepeat, onReset: _reset),
    ],
  );
}

/// Up / down / left / right buttons around a reset button. Holding an
/// arrow keeps moving the photo.
class _MovePad extends StatelessWidget {
  const _MovePad({
    required this.onStart,
    required this.onEnd,
    required this.onReset,
  });

  final void Function(Offset direction) onStart;
  final VoidCallback onEnd;
  final VoidCallback onReset;

  Widget _arrow(IconData icon, Offset direction, String label) => Semantics(
    button: true,
    label: label,
    child: Listener(
      onPointerDown: (_) => onStart(direction),
      onPointerUp: (_) => onEnd(),
      onPointerCancel: (_) => onEnd(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEBE8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Brand.charcoal),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _arrow(Icons.keyboard_arrow_up, const Offset(0, -1), 'Move photo up'),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _arrow(
            Icons.keyboard_arrow_left,
            const Offset(-1, 0),
            'Move photo left',
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: 'Reset position',
              onPressed: onReset,
              icon: const Icon(
                Icons.center_focus_strong_outlined,
                color: Brand.muted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _arrow(
            Icons.keyboard_arrow_right,
            const Offset(1, 0),
            'Move photo right',
          ),
        ],
      ),
      const SizedBox(height: 6),
      _arrow(Icons.keyboard_arrow_down, const Offset(0, 1), 'Move photo down'),
    ],
  );
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.crop);

  final ui.Image? image;
  final PhotoCrop crop;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    final img = image;
    if (img == null) {
      canvas.drawRect(dst, Paint()..color = const Color(0xFFE4E2DF));
      return;
    }
    final src = crop.sourceRect(
      Size(img.width.toDouble(), img.height.toDouble()),
      TemplateSpec.photo.size,
    );
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.crop != crop;
}
