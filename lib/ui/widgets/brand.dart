import 'package:flutter/material.dart';

import '../theme.dart';

/// Ministry statements shown in the app.
class Ministry {
  Ministry._();

  static const tagline = 'A Discipleship tool of Youth For Christ';
  static const reach = 'Reaching about 3.6 million souls a month';
  static const createdBy = 'Created by Youth For Christ';
}

/// "DAILY JUICE [AUTHORS]": the app's name, for dark headers.
class AppNameMark extends StatelessWidget {
  const AppNameMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 4,
    children: [
      Text(
        'DAILY JUICE',
        style: Brand.heading(
          size,
          color: Colors.white,
        ).copyWith(letterSpacing: 1),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 7, 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'AUTHORS',
          style: Brand.heading(
            size * 0.45,
            color: Brand.charcoal,
          ).copyWith(letterSpacing: 1.6),
        ),
      ),
    ],
  );
}

/// The diagonal stripe motif of the Daily Juice template, for app headers.
class StripePainter extends CustomPainter {
  const StripePainter({required this.color, this.period = 46, this.width = 16});

  final Color color;
  final double period;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final rise = size.height * 0.76; // same slant as the template
    for (var x = -rise; x < size.width + rise; x += period) {
      canvas.drawPath(
        Path()
          ..moveTo(x + rise, 0)
          ..lineTo(x + rise + width, 0)
          ..lineTo(x + width, size.height)
          ..lineTo(x, size.height)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StripePainter old) =>
      old.color != color || old.period != period || old.width != width;
}

/// "Created by Youth For Christ" — the app footer.
class YfcFooter extends StatelessWidget {
  const YfcFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
    child: Column(
      children: [
        Container(width: 40, height: 3, color: Brand.stripe),
        const SizedBox(height: 12),
        Text(
          Ministry.createdBy.toUpperCase(),
          textAlign: TextAlign.center,
          style: Brand.heading(
            15,
            color: Brand.muted,
          ).copyWith(letterSpacing: 1.6),
        ),
      ],
    ),
  );
}

/// "Reaching about 3.6 million souls a month", on a dark background.
class ReachPill extends StatelessWidget {
  const ReachPill({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0x26FFFFFF),
      borderRadius: BorderRadius.circular(30),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.public, size: 18, color: Colors.white),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            Ministry.reach,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    ),
  );
}
