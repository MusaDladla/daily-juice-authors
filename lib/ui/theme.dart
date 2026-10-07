import 'package:flutter/material.dart';

import '../template/template_spec.dart';

/// The colour and icon of each part of a Daily Juice, used everywhere that
/// part appears (form section, focus preview, progress). One calm accent
/// for all parts; the icons tell them apart. Green, amber and red are left
/// for meaning (done / near the limit / problem).
class SectionStyle {
  const SectionStyle(this.color, this.icon);

  final Color color;
  final IconData icon;

  /// Slate grey-blue: the single editing accent.
  static const accent = Color(0xFF5D6B7E);

  static const title = SectionStyle(accent, Icons.title);
  static const date = SectionStyle(accent, Icons.event_outlined);
  static const scripture = SectionStyle(accent, Icons.menu_book_outlined);
  static const message = SectionStyle(accent, Icons.notes);
  static const furtherStudy = SectionStyle(accent, Icons.bookmarks_outlined);

  /// In form order.
  static const all = [title, date, scripture, message, furtherStudy];
}

/// App colours drawn from the Daily Juice template itself.
class Brand {
  Brand._();

  static const charcoal = Color(0xFF3D3D39);
  static const ink = Color(0xFF1C1C1A);
  static const background = Color(0xFFF3F2F0);
  static const stripe = Color(0xFFE1DFE0);
  static const muted = Color(0xFF6B6A66);
  static const warning = Color(0xFFB54708);
  static const error = Color(0xFFB42318);
  static const ok = Color(0xFF2E7D32);

  static const condensed = TemplateSpec.condensed;

  static TextStyle heading(double size, {Color color = ink}) => TextStyle(
    fontFamily: condensed,
    fontWeight: FontWeight.w700,
    fontSize: size,
    letterSpacing: 0.5,
    color: color,
    height: 1.1,
  );

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: charcoal,
      primary: charcoal,
      onPrimary: Colors.white,
      // Neutral greys from the template instead of generated tints.
      secondaryContainer: const Color(0xFFE4E2DE),
      onSecondaryContainer: ink,
      surface: Colors.white,
      error: error,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: heading(24),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE4E2DF)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFAF9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6D4D0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: charcoal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: charcoal,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: heading(
            20,
            color: Colors.white,
          ).copyWith(letterSpacing: 1.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: charcoal,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: charcoal, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: heading(17).copyWith(letterSpacing: 0.8),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
