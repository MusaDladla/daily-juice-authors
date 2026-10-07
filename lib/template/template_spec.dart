import 'package:flutter/painting.dart';

/// The Daily Juice publication template.
///
/// Every value below was measured from the official reference artwork
/// (2480 × 3508 px — A4 at 300 dpi). All coordinates are in those pixels.
/// The template is FIXED: content must fit it, it never adapts to content.
class TemplateSpec {
  TemplateSpec._();

  // ---------------------------------------------------------------- page --
  static const double width = 2480;
  static const double height = 3508;
  static const Size size = Size(width, height);

  // -------------------------------------------------------------- colours --
  static const Color paper = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF000000);
  static const Color stripeGray = Color(0xFFE7E5E6);
  static const Color barGray = Color(0xFFE1DFE0);
  static const Color dateBox = Color(0xFF3D3D39);
  static const Color divider = Color(0xFFADADAD);
  static const Color dateInk = Color(0xFFFFFFFF);

  // ------------------------------------------------------------- families --
  static const String condensed = 'BarlowCondensed';
  static const String sans = 'Arimo';

  // ------------------------------------------------- left decorative strip --
  static const double stripWidth = 98;

  /// Slanted white bands cut into the grey strip. Top edge y at x = 0.
  static const List<double> stripWhiteBandTops = [
    134.8, 365.8, 585.8, 838.8, 1075.8, 1296.8, 1523.8, 1770.8, //
    2005.8, 2222.8, 2454.8, 2693.8, 2934.8, 3168.8, 3412.8,
  ];
  static const double stripWhiteBandHeight = 104;
  static const double stripSlope = -0.413; // dy per dx

  // -------------------------------------------- diagonal stripe pattern --
  // White stripes on grey, used by the title box and the top-edge band.
  // Left edge of a white stripe: x = stripeOriginX + stripeSlope*y + k*period
  static const double stripePeriod = 150;
  static const double stripeWhiteWidth = 47;
  static const double stripeOriginX = 655;
  static const double stripeSlope = -0.76;

  static const Rect topBand = Rect.fromLTRB(504, 0, width, 2);

  // ---------------------------------------------------------------- photo --
  static const Rect photo = Rect.fromLTWH(153, 78, 342, 419);
  static const Offset photoShadowOffset = Offset(5, 7);
  static const double photoShadowSigma = 6;
  static const Color photoShadow = Color(0x80000000);

  // ------------------------------------------------------------ title box --
  static const Rect titleBox = Rect.fromLTRB(517, 83, 2383, 500);
  static const TextStyle titleStyle = TextStyle(
    fontFamily: condensed,
    fontWeight: FontWeight.w700,
    fontSize: 138.6,
    letterSpacing: 4.4,
    color: ink,
  );
  static const double titleSidePadding = 70;
  static double get titleMaxWidth => titleBox.width - 2 * titleSidePadding;

  /// Widest a title may be on one line: "THE LORD OUR MAKER" (1139 px) plus
  /// room for one more letter. A wider title moves to two balanced lines
  /// instead of stretching across the whole box.
  static const double titleSingleLineMax = 1210;

  /// When a title needs two lines they are centred in the same box at the
  /// same size — never shrunk.
  /// Measured from an official two-line title ("JESUS CHRIST IS THE /
  /// PATHWAY TO LIFE"): baselines 126 px apart, a 27 px gap between lines.
  static const double titleLinePitch = 126;
  static const double titleCapHeight = 97;

  // ---------------------------------------------------------- author bar --
  static const Rect authorBar = Rect.fromLTRB(118, 556, 2385, 650);
  static const TextStyle authorStyle = TextStyle(
    fontFamily: condensed,
    fontWeight: FontWeight.w700,
    fontSize: 74.3,
    letterSpacing: 0.75,
    color: ink,
  );
  static const double authorX = 152;
  static const double headerBaseline = 629;

  /// The author line must end before the longest weekday ("WEDNESDAY").
  static const double authorMaxRight = 1790;

  static const TextStyle weekdayStyle = TextStyle(
    fontFamily: condensed,
    fontWeight: FontWeight.w700,
    fontSize: 74.3,
    letterSpacing: 1.9,
    color: ink,
  );
  static const double weekdayInkRight = 2184;

  static const Rect dateBoxRect = Rect.fromLTRB(2197, 556, 2385, 650);
  static const TextStyle dateNumberStyle = TextStyle(
    fontFamily: condensed,
    fontWeight: FontWeight.w700,
    fontSize: 74.3,
    letterSpacing: 0.9,
    color: dateInk,
  );
  static const double dateNumberX = 2211;
  static const double dateNumberBaseline = 628;
  static const TextStyle dateSuffixStyle = TextStyle(
    fontFamily: condensed,
    fontWeight: FontWeight.w700,
    fontSize: 41,
    color: dateInk,
  );
  static const double dateSuffixBaseline = 604;
  static const double dateSuffixGap = 0;

  // ------------------------------------------------------------ dividers --
  static const double dividerLeft = 118;
  static const double dividerRight = 2386;

  /// Triple rule: (offset from top, thickness).
  static const List<(double, double)> dividerLines = [(0, 4), (7, 8), (18, 4)];
  static const double divider1Top = 673;

  // ------------------------------------------------------ theme scripture --
  static const TextStyle scriptureStyle = TextStyle(
    fontFamily: condensed,
    fontWeight: FontWeight.w700,
    fontSize: 99.8,
    color: ink,
  );
  static const double scriptureLinePitch = 114;

  /// Baseline of line 1 when the scripture fills the template's 4 lines.
  static const double scriptureFirstBaseline = 783;
  static const int scriptureSlots = 4;
  static const double scriptureMaxWidth = 2184;
  static const double centerX = 1240;

  static const TextStyle referenceStyle = TextStyle(
    fontFamily: condensed,
    fontWeight: FontWeight.w300,
    fontSize: 92,
    color: ink,
  );
  static const double referenceBaselineGap = 102;
  static const double divider2GapBelowReference = 27;

  // -------------------------------------------------------- main message --
  static const TextStyle bodyStyle = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w400,
    fontSize: 77.7,
    color: ink,
  );
  static const double bodyLeft = 154;
  static const double bodyRight = 2338;
  static const double bodyLinePitch = 84.0;
  static const double bodyFirstBaselineBelowDivider2 = 106.6;

  /// Baseline of the last line the page can hold (the reference artwork's
  /// 23rd line slot). Anything lower would collide with Further Study.
  static const double bodyMaxLastBaseline = 3208.6;

  /// Paragraphs are separated by one blank line, exactly like the
  /// reference. If (and only if) the content would otherwise not fit, the
  /// blank line may tighten — uniformly — down to this fraction.
  static const double paragraphGapMin = 0.5;

  static const TextStyle dropCapStyle = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w400,
    fontSize: 214.5,
    color: ink,
  );
  static const double dropCapX = 281;
  static const int dropCapLines = 2;
  static const double dropCapGap = 0;

  // ---------------------------------------------------------------- footer --
  static const TextStyle furtherStudyHeadingStyle = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w700,
    fontSize: 85.5,
    letterSpacing: -1.3,
    color: ink,
  );
  static const String furtherStudyHeading = 'FURTHER STUDY';
  static const double furtherStudyHeadingBaseline = 3371;
  static const Rect footerRule = Rect.fromLTRB(153, 3390, 2339, 3395);

  static const TextStyle furtherStudyStyle = TextStyle(
    fontFamily: condensed,
    fontWeight: FontWeight.w600,
    fontSize: 75,
    color: ink,
  );
  static const double furtherStudyBaseline = 3472.5;
  static const double furtherStudyMaxWidth =
      1950; // centred, clear of "next page"
  static const String furtherStudySeparator = '; ';

  static const TextStyle nextPageStyle = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w400,
    fontSize: 37,
    color: ink,
  );
  static const String nextPageText = 'next page';
  static const double nextPageX = 2245;
  static const double nextPageBaseline = 3457;
  static const Rect nextPageTriangle = Rect.fromLTWH(2420, 3433, 16, 32);
}
