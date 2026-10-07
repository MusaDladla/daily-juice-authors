import 'dart:math' as math;
import 'dart:ui';

/// How the author's photo is framed inside the template's photo slot.
///
/// The image is always scaled uniformly ("cover"), so the face is never
/// stretched or squashed; only the visible window moves or zooms.
class PhotoCrop {
  const PhotoCrop({this.cx = 0.5, this.cy = 0.5, this.zoom = 1.0});

  /// Centre of the visible window, as a fraction of the image (0..1).
  final double cx;
  final double cy;

  /// 1.0 = the whole slot is just covered; up to [maxZoom].
  final double zoom;

  static const double maxZoom = 4.0;

  /// Automatic framing: centred, biased upward on tall photos so the head
  /// is kept (portraits usually have the face in the upper half).
  factory PhotoCrop.auto(Size image, Size slot) {
    final tallerThanSlot =
        image.height / image.width > slot.height / slot.width + 0.01;
    return PhotoCrop(cx: 0.5, cy: tallerThanSlot ? 0.42 : 0.5);
  }

  /// The part of the image that fills [slot].
  Rect sourceRect(Size image, Size slot) {
    final z = zoom.clamp(1.0, maxZoom);
    final scale =
        math.max(slot.width / image.width, slot.height / image.height) * z;
    final sw = slot.width / scale;
    final sh = slot.height / scale;
    final sx = (cx * image.width - sw / 2).clamp(0.0, image.width - sw);
    final sy = (cy * image.height - sh / 2).clamp(0.0, image.height - sh);
    return Rect.fromLTWH(sx, sy, sw, sh);
  }

  /// Moves the window by a drag of [delta] slot pixels.
  PhotoCrop panBy(Offset delta, Size image, Size slot) {
    final src = sourceRect(image, slot);
    final pxPerSlot = src.width / slot.width;
    final halfW = src.width / 2 / image.width;
    final halfH = src.height / 2 / image.height;
    final current = src.center;
    final ncx = ((current.dx - delta.dx * pxPerSlot) / image.width).clamp(
      halfW,
      1 - halfW,
    );
    final ncy = ((current.dy - delta.dy * pxPerSlot) / image.height).clamp(
      halfH,
      1 - halfH,
    );
    return PhotoCrop(cx: ncx, cy: ncy, zoom: zoom);
  }

  PhotoCrop withZoom(double z) =>
      PhotoCrop(cx: cx, cy: cy, zoom: z.clamp(1.0, maxZoom));

  Map<String, dynamic> toJson() => {'cx': cx, 'cy': cy, 'zoom': zoom};

  factory PhotoCrop.fromJson(Map<String, dynamic>? json) => json == null
      ? const PhotoCrop()
      : PhotoCrop(
          cx: (json['cx'] as num?)?.toDouble() ?? 0.5,
          cy: (json['cy'] as num?)?.toDouble() ?? 0.5,
          zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
        );

  @override
  bool operator ==(Object other) =>
      other is PhotoCrop &&
      other.cx == cx &&
      other.cy == cy &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(cx, cy, zoom);
}
