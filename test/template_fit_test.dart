import 'package:daily_juice/core/limits.dart';
import 'package:daily_juice/core/validation.dart';
import 'package:daily_juice/core/word_count.dart';
import 'package:daily_juice/models/daily_juice.dart';
import 'package:daily_juice/models/profile.dart';
import 'package:daily_juice/template/photo_crop.dart';
import 'package:daily_juice/template/template_layout.dart';
import 'package:daily_juice/template/template_spec.dart';
import 'package:daily_juice/template/text_measure.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reference_juice.dart';
import 'support/template_fonts.dart';

String words(int n, {String word = 'faith'}) => List.filled(n, word).join(' ');

/// Every body/scripture run must sit fully inside its column, and nothing
/// may be drawn below the message area.
void expectInsideTemplate(TemplateLayout layout) {
  for (final t in layout.texts) {
    final w = TextMeasure.advance(t.style, t.text);
    expect(
      t.x,
      greaterThanOrEqualTo(TemplateSpec.stripWidth),
      reason: '"${t.text}" starts in the left strip',
    );
    expect(
      t.x + w,
      lessThanOrEqualTo(TemplateSpec.width - 40),
      reason: '"${t.text}" runs off the page',
    );
    if (t.style == TemplateSpec.bodyStyle) {
      expect(
        t.x + w,
        lessThanOrEqualTo(TemplateSpec.bodyRight + 0.5),
        reason: '"${t.text}" overflows the message column',
      );
      expect(
        t.baseline,
        lessThanOrEqualTo(TemplateSpec.bodyMaxLastBaseline + 0.5),
        reason: '"${t.text}" overlaps Further Study',
      );
    }
    if (t.style == TemplateSpec.scriptureStyle) {
      expect(w, lessThanOrEqualTo(TemplateSpec.scriptureMaxWidth + 0.5));
    }
  }
}

void main() {
  setUpAll(loadTemplateFonts);

  test('every word of the message is placed, once, unchanged', () {
    final layout = TemplateLayoutEngine.compute(referenceJuice);
    final placed = layout.texts
        .where(
          (t) =>
              t.style == TemplateSpec.bodyStyle ||
              t.style == TemplateSpec.dropCapStyle,
        )
        .map((t) => t.text)
        .toList();
    // Drop cap + rest of first word re-join to the author's first word.
    final rebuilt = [placed[0] + placed[1], ...placed.skip(2)];
    expect(rebuilt, referenceJuice.message.split(RegExp(r'\s+')));
  });

  test('171 words of ordinary prose fit at standard spacing', () {
    const sentence = 'The Lord is my shepherd and He leads me in His ways. ';
    var text = '';
    while (countWords(text) < 171) {
      text += sentence;
    }
    text = text.split(' ').take(171).join(' ');
    final paragraphs = [
      text.split(' ').take(60).join(' '),
      text.split(' ').skip(60).take(60).join(' '),
      text.split(' ').skip(120).join(' '),
    ].join('\n\n');
    expect(countWords(paragraphs), Limits.messageWords);
    final layout = TemplateLayoutEngine.compute(
      referenceJuice.copyWith(message: paragraphs),
    );
    expect(layout.bodyFits, isTrue);
    expect(layout.paragraphGap, 1.0);
    expectInsideTemplate(layout);
  });

  test('many paragraphs tighten spacing uniformly instead of overflowing', () {
    final message = List.generate(
      9,
      (_) => words(17, word: 'grace'),
    ).join('\n');
    final layout = TemplateLayoutEngine.compute(
      referenceJuice.copyWith(message: message),
    );
    expect(layout.bodyFits, isTrue);
    expect(layout.paragraphGap, lessThan(1.0));
    expect(
      layout.paragraphGap,
      greaterThanOrEqualTo(TemplateSpec.paragraphGapMin),
    );
    expectInsideTemplate(layout);
  });

  test('content that cannot fit is detected (never clipped or shrunk)', () {
    final layout = TemplateLayoutEngine.compute(
      referenceJuice.copyWith(message: words(171, word: 'righteousness')),
    );
    expect(layout.bodyFits, isFalse);
    expect(layout.fits, isFalse);
  });

  test('a pasted over-long word is broken so it stays on the page', () {
    final layout = TemplateLayoutEngine.compute(
      referenceJuice.copyWith(
        message: 'Read https://example.org/${'a' * 150} today.',
      ),
    );
    expect(layout.bodyFits, isTrue);
    expectInsideTemplate(layout);
  });

  test('a long 4-word title uses two lines at full size', () {
    final layout = TemplateLayoutEngine.compute(
      referenceJuice.copyWith(
        title: 'Unshakeable faithfulness through tribulation',
      ),
    );
    expect(layout.titleLines, 2);
    expect(layout.titleFits, isTrue);
    final titles = layout.texts
        .where((t) => t.style == TemplateSpec.titleStyle)
        .toList();
    for (final t in titles) {
      expect(t.x, greaterThanOrEqualTo(TemplateSpec.titleBox.left));
      expect(
        t.x + TextMeasure.advance(t.style, t.text),
        lessThanOrEqualTo(TemplateSpec.titleBox.right),
      );
      expect(t.style.fontSize, TemplateSpec.titleStyle.fontSize);
    }
  });

  test('a title that cannot fit the box is reported', () {
    expect(TemplateLayoutEngine.titleFits('W' * 40), isFalse);
    expect(TemplateLayoutEngine.titleFits('Baal Perazim'), isTrue);
  });

  test('a 5-line Theme Scripture pushes the message area down', () {
    final layout = TemplateLayoutEngine.compute(
      referenceJuice.copyWith(
        scripture: words(38, word: 'everlasting'),
        message: 'Short message.',
      ),
    );
    expect(layout.scriptureLines, greaterThan(4));
    expect(layout.divider2Top, greaterThan(1254));
    expect(layout.fits, isTrue);
    expectInsideTemplate(layout);
  });

  test('a short Theme Scripture closes up: no empty space is left', () {
    final full = TemplateLayoutEngine.compute(referenceJuice);
    final short = TemplateLayoutEngine.compute(
      referenceJuice.copyWith(scripture: '“Jesus wept.”'),
    );
    expect(short.scriptureLines, 1);
    // Three lines shorter: the divider and the message move up 3 × 114 px.
    expect(short.divider2Top, closeTo(full.divider2Top - 3 * 114, 1e-6));
    double firstBody(TemplateLayout l) =>
        l.texts.firstWhere((t) => t.style == TemplateSpec.bodyStyle).baseline;
    expect(firstBody(short), closeTo(firstBody(full) - 3 * 114, 1e-6));

    // The verse starts in the same place; its reference follows directly.
    final verse = short.texts.firstWhere(
      (t) => t.style == TemplateSpec.scriptureStyle,
    );
    final reference = short.texts.firstWhere(
      (t) => t.style == TemplateSpec.referenceStyle,
    );
    expect(verse.baseline, closeTo(TemplateSpec.scriptureFirstBaseline, 1e-6));
    expect(
      reference.baseline,
      closeTo(verse.baseline + TemplateSpec.referenceBaselineGap, 1e-6),
    );
    expect(
      short.divider2Top,
      closeTo(
        reference.baseline + TemplateSpec.divider2GapBelowReference,
        1e-6,
      ),
    );
    expectInsideTemplate(short);
  });

  test('Further Study: 3 references fit, absurd length does not', () {
    expect(
      TemplateLayoutEngine.furtherStudyFits([
        '1 Chronicles 14:11',
        'Isaiah 28:21',
        'Psalm 18:29',
      ]),
      isTrue,
    );
    expect(
      TemplateLayoutEngine.furtherStudyFits([
        '2 Thessalonians 3:16-18',
        'Song of Solomon 2:4',
        'Deuteronomy 31:6-8',
      ]),
      isTrue,
    );
    expect(TemplateLayoutEngine.furtherStudyFits(['M' * 120]), isFalse);
  });

  test('author line: normal names fit, absurdly long ones are refused', () {
    expect(TemplateLayoutEngine.authorFits('Christian Mapitle'), isTrue);
    expect(
      TemplateLayoutEngine.authorFits('Nomvula-Khanyisile Mahlangu-Ndlovu'),
      isTrue,
    );
    expect(TemplateLayoutEngine.authorFits('W' * 60), isFalse);
  });

  group('final validation', () {
    final profile = Profile(
      id: 'u1',
      name: 'Christian',
      surname: 'Mapitle',
      branch: 'Soweto',
      photoPath: '/photo.jpg',
      photoCrop: const PhotoCrop(),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final complete =
        DailyJuice.create(
          id: 'j1',
          profile: profile,
          date: DateTime(2026, 9, 30),
        ).copyWith(
          title: referenceJuice.title,
          themeScripture: referenceJuice.scripture,
          scriptureReference: referenceJuice.scriptureReference,
          mainMessage: referenceJuice.message,
          furtherStudy: referenceJuice.furtherStudy,
        );

    List<Issue> check(DailyJuice j, {bool photo = true}) =>
        Validation.forGeneration(
          juice: j,
          layout: TemplateLayoutEngine.compute(j.toContent()),
          hasPhoto: photo,
        );

    test('the reference Daily Juice passes', () {
      expect(check(complete), isEmpty);
    });

    test('every missing piece is reported with the right message', () {
      final empty = DailyJuice.create(
        id: 'j2',
        profile: profile.copyWith(name: '', branch: ''),
        date: DateTime(2026, 9, 30),
      );
      final messages = check(empty, photo: false).map((i) => i.message);
      expect(
        messages,
        containsAll([
          Msg.profileImageRequired,
          Msg.nameRequired,
          Msg.titleRequired,
          Msg.scriptureRequired,
          Msg.scriptureReferenceRequired,
          Msg.messageRequired,
          Msg.furtherStudyRequired,
        ]),
      );
    });

    test('limits are re-checked before generation', () {
      final over = complete.copyWith(
        title: 'one two three four five six seven eight',
        themeScripture: words(39),
        mainMessage: words(172, word: 'righteousness'),
        furtherStudy: ['John 1:1', 'John 1:2', 'John 1:3', 'John 1:4'],
      );
      final messages = check(over).map((i) => i.message);
      expect(
        messages,
        containsAll([
          Msg.titleWords,
          Msg.scriptureWords,
          Msg.messageNoFreeSpace,
          Msg.furtherStudyMax,
        ]),
      );
    });

    test('verse text in Further Study is refused', () {
      final bad = complete.copyWith(
        furtherStudy: [
          'Then David came to Baal Perazim and the Lord broke through',
        ],
      );
      expect(check(bad).map((i) => i.field), contains(JuiceField.furtherStudy));
    });
  });

  group('beyond 171 words: only into free space', () {
    test('a short verse frees space that extra words may fill', () {
      final message = [
        words(70, word: 'faith'),
        words(70, word: 'faith'),
        words(50, word: 'faith'),
      ].join('\n\n');
      expect(countWords(message), 190);
      final full = TemplateLayoutEngine.compute(
        referenceJuice.copyWith(message: message),
      );
      final shortVerse = TemplateLayoutEngine.compute(
        referenceJuice.copyWith(scripture: '“Jesus wept.”', message: message),
      );
      expect(shortVerse.bodyFits, isTrue);
      expect(shortVerse.spacingTightened, isFalse);
      expect(Validation.messageFit(190, shortVerse), isNull);
      expectInsideTemplate(shortVerse);
      // The same words with no free space (long verse) are refused.
      expect(
        Validation.messageFit(190, full),
        full.bodyFits && !full.spacingTightened
            ? isNull
            : Msg.messageNoFreeSpace,
      );
    });

    test('extra words may never squeeze paragraph spacing', () {
      final message = [
        for (var i = 0; i < 8; i++) words(17, word: 'grace'),
        words(36, word: 'grace'),
      ].join('\n');
      expect(countWords(message), 172);
      final layout = TemplateLayoutEngine.compute(
        referenceJuice.copyWith(message: message),
      );
      expect(layout.spacingTightened || !layout.bodyFits, isTrue);
      expect(Validation.messageFit(172, layout), Msg.messageNoFreeSpace);
    });

    test('up to 171 words, slight tightening is still allowed', () {
      final message = List.generate(
        9,
        (_) => words(17, word: 'grace'),
      ).join('\n');
      final layout = TemplateLayoutEngine.compute(
        referenceJuice.copyWith(message: message),
      );
      expect(layout.spacingTightened, isTrue);
      expect(Validation.messageFit(countWords(message), layout), isNull);
    });
  });

  test('a 5-word title fits, using a second line when long', () {
    final layout = TemplateLayoutEngine.compute(
      referenceJuice.copyWith(title: 'Let go and trust God'),
    );
    expect(layout.titleFits, isTrue);
    final long = TemplateLayoutEngine.compute(
      referenceJuice.copyWith(
        title: 'Faithfulness through every unexpected tribulation',
      ),
    );
    expect(long.titleLines, 2);
    expect(long.titleFits, isTrue);
  });

  test('a long title moves to two balanced lines early', () {
    int lines(String t) => TemplateLayoutEngine.compute(
      referenceJuice.copyWith(title: t),
    ).titleLines;
    // Comfortable titles stay on one line.
    expect(lines('Baal Perazim'), 1);
    expect(lines('Grace upon grace'), 1);
    expect(lines('Let go and let God'), 1);
    expect(lines('The Lord our Maker'), 1);
    expect(lines('The Lord our Makers'), 1, reason: 'room for one more letter');
    // Longer ones wrap instead of stretching across the box.
    expect(lines('Walking in His promises'), 2);
    expect(lines('He is still on the throne'), 2);

    final layout = TemplateLayoutEngine.compute(
      referenceJuice.copyWith(title: 'Walking in His promises'),
    );
    final rows = layout.texts
        .where((t) => t.style == TemplateSpec.titleStyle)
        .map((t) => t.text)
        .toList();
    expect(rows, ['WALKING IN', 'HIS PROMISES']);
    expect(layout.titleFits, isTrue);
  });

  test('two-line title matches the official artwork spacing', () {
    // "JESUS CHRIST IS THE / PATHWAY TO LIFE" (Sicelo Malibe, Saturday 25th):
    // line 1 cap top 175 / baseline ~275, line 2 baseline ~401.
    final layout = TemplateLayoutEngine.compute(
      referenceJuice.copyWith(title: 'Jesus Christ is the pathway to life'),
    );
    final rows = layout.texts
        .where((t) => t.style == TemplateSpec.titleStyle)
        .toList();
    expect(rows.map((t) => t.text), ['JESUS CHRIST IS THE', 'PATHWAY TO LIFE']);
    expect(rows[1].baseline - rows[0].baseline, 126);
    expect(rows[0].baseline, closeTo(275, 2));
    expect(rows[1].baseline, closeTo(401, 2));
    expect(layout.titleFits, isTrue);
  });
}
