import 'package:flutter/material.dart';

import '../theme.dart';

/// A titled card grouping one part of the Daily Juice form.
///
/// With a [section] style, the card carries that part's colour: an accent
/// stripe, a tinted header with an icon badge, and its fields, cursor and
/// buttons in the same colour. Without one it stays neutral (profile).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
    this.complete = false,
    this.section,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final SectionStyle? section;

  /// Shows a check mark once this part of the Daily Juice is ready.
  final bool complete;

  Widget _check() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    child: complete
        ? const Padding(
            key: ValueKey(true),
            padding: EdgeInsets.only(right: 6),
            child: Icon(
              Icons.check_circle,
              size: 20,
              color: Brand.ok,
              semanticLabel: 'Complete',
            ),
          )
        : const SizedBox(key: ValueKey(false)),
  );

  @override
  Widget build(BuildContext context) {
    final s = section;
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (s != null) ...[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: s.color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(s.icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
        ],
        _check(),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Brand.heading(19, color: s?.color ?? Brand.ink),
          ),
        ),
        ?trailing,
      ],
    );
    final subtitleText = subtitle == null
        ? null
        : Text(
            subtitle!,
            style: const TextStyle(color: Brand.muted, fontSize: 13),
          );

    if (s == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (subtitleText != null) ...[
                const SizedBox(height: 2),
                subtitleText,
              ],
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: s.color, width: 5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: s.color.withValues(alpha: 0.07),
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  if (subtitleText != null) ...[
                    const SizedBox(height: 6),
                    subtitleText,
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
              child: _SectionTheme(color: s.color, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fields, cursor, selection and buttons inside a section take its colour.
class _SectionTheme extends StatelessWidget {
  const _SectionTheme({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final focused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: 2),
    );
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(primary: color),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          focusedBorder: focused,
          floatingLabelStyle: TextStyle(color: color),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: color,
          selectionColor: color.withValues(alpha: 0.25),
          selectionHandleColor: color,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: base.outlinedButtonTheme.style?.copyWith(
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? Brand.muted.withValues(alpha: 0.6)
                  : color,
            ),
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? const Color(0xFFD6D4D0)
                    : color,
                width: 1.4,
              ),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: color),
        ),
      ),
      child: child,
    );
  }
}

/// "12 / 171 words" — in the section's colour; amber near the limit.
class LimitCounter extends StatelessWidget {
  const LimitCounter({
    super.key,
    required this.count,
    required this.limit,
    required this.unit,
    this.color,
  });

  final int count;
  final int limit;
  final String unit;

  /// The section colour for the normal state.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final atLimit = count >= limit;
    final near = count >= limit * 0.9;
    final normal = color ?? Brand.muted;
    final textColor = near ? Brand.warning : normal;
    return Semantics(
      label: '$count of $limit $unit used',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: atLimit
              ? const Color(0xFFFDF0E6)
              : (color == null
                    ? const Color(0xFFF1F0EE)
                    : color!.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          count > limit
              ? '$count / $limit $unit (+${count - limit})'
              : '$count / $limit $unit',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Inline message under a field (limit reached, or a validation error).
class FieldMessage extends StatelessWidget {
  const FieldMessage(this.message, {super.key, this.isError = true});

  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      child: m == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.info_outline,
                    size: 18,
                    color: isError ? Brand.error : Brand.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m,
                      style: TextStyle(
                        color: isError ? Brand.error : Brand.warning,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
