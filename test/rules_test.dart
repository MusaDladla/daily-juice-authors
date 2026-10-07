import 'package:daily_juice/core/bible_reference.dart';
import 'package:daily_juice/core/juice_date.dart';
import 'package:daily_juice/core/juice_search.dart';
import 'package:daily_juice/models/daily_juice.dart';
import 'package:daily_juice/models/profile.dart';
import 'package:daily_juice/template/photo_crop.dart';
import 'package:daily_juice/core/limit_formatter.dart';
import 'package:daily_juice/core/word_count.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('word count', () {
    test('punctuation never creates words', () {
      expect(countWords('God is good.'), 3);
      expect(countWords('  God   is\n\ngood .  '), 3);
      expect(countWords('— … ! ” “'), 0);
      expect(countWords("didn't panic; he sought God"), 5);
      expect(countWords('(Luke 1:37).'), 2);
      expect(countWords(''), 0);
    });

    test('reference Theme Scripture is exactly 38 words', () {
      expect(
        countWords(
          '“So David went to Baal Perazim, and David defeated them '
          'there; and he said, ‘The LORD has broken through my enemies '
          'before me, like a breakthrough of water.’ Therefore he called '
          'the name of that place Baal Perazim.”',
        ),
        38,
      );
    });
  });

  group('template date', () {
    test('formats like the template', () {
      expect(
        TemplateDate.of(DateTime(2026, 9, 30)).toString(),
        'WEDNESDAY 30TH',
      );
      expect(TemplateDate.of(DateTime(2026, 10, 1)).toString(), 'THURSDAY 1ST');
      expect(TemplateDate.of(DateTime(2026, 10, 2)).toString(), 'FRIDAY 2ND');
      expect(TemplateDate.of(DateTime(2026, 10, 3)).toString(), 'SATURDAY 3RD');
      expect(TemplateDate.of(DateTime(2026, 10, 11)).toString(), 'SUNDAY 11TH');
      expect(TemplateDate.of(DateTime(2026, 10, 12)).suffix, 'TH');
      expect(TemplateDate.of(DateTime(2026, 10, 13)).suffix, 'TH');
      expect(TemplateDate.of(DateTime(2026, 10, 21)).suffix, 'ST');
      expect(TemplateDate.of(DateTime(2026, 10, 22)).suffix, 'ND');
      expect(TemplateDate.of(DateTime(2026, 10, 23)).suffix, 'RD');
    });

    test('ISO round trip', () {
      expect(
        parseIsoDate(toIsoDate(DateTime(2026, 2, 28))),
        DateTime(2026, 2, 28),
      );
      expect(parseIsoDate('2026-02-30'), isNull);
      expect(parseIsoDate('nonsense'), isNull);
    });
  });

  group('Bible references', () {
    for (final ok in [
      '1 CHRONICLES 14:11',
      'ISAIAH 28:21',
      'Psalm 18:29',
      'Psalm 23',
      '2 Samuel 5:20',
      'Song of Solomon 2:4',
      'John 3:16-18',
      'Matthew 5:3, 5, 7',
      'Genesis 1:1–2:3',
      '1Cor 13:4',
      'Romans 8:28 NKJV',
      '1 Dikronike 14:11',
      'Ps. 91:1',
    ]) {
      test('accepts "$ok"', () => expect(isBibleReference(ok), isTrue));
    }
    for (final bad in [
      'Then David came to Baal Perazim and the Lord broke through his enemies',
      'nothing will be impossible with God',
      'Isaiah',
      '',
    ]) {
      test('rejects "$bad"', () => expect(isBibleReference(bad), isFalse));
    }
  });

  group('limit formatter', () {
    String? rejected;
    final formatter = LimitFormatter(
      check: (t) => countWords(t) > 4 ? 'Title cannot exceed 4 words.' : null,
      onRejected: (m, _, _) => rejected = m,
    );
    TextEditingValue v(String t) => TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );

    test('accepts input within the limit', () {
      rejected = null;
      final out = formatter.formatEditUpdate(v('A B C'), v('A B C D'));
      expect(out.text, 'A B C D');
      expect(rejected, isNull);
    });

    test('a trailing space after the 4th word is fine', () {
      final out = formatter.formatEditUpdate(v('A B C D'), v('A B C D '));
      expect(out.text, 'A B C D ');
    });

    test('blocks the 5th word and keeps the existing text untouched', () {
      rejected = null;
      final out = formatter.formatEditUpdate(v('A B C D '), v('A B C D E'));
      expect(out.text, 'A B C D ');
      expect(rejected, 'Title cannot exceed 4 words.');
    });

    test('refuses an over-limit paste entirely (nothing is cut)', () {
      final out = formatter.formatEditUpdate(
        v('A'),
        v('A one two three four five six'),
      );
      expect(out.text, 'A');
    });

    test('lets over-limit legacy text be shortened', () {
      final out = formatter.formatEditUpdate(v('A B C D E F'), v('A B C D E'));
      expect(out.text, 'A B C D E');
    });
  });

  group('dashboard search', () {
    final profile = Profile(
      id: 'u',
      name: 'A',
      surname: 'B',
      branch: '',
      photoPath: '',
      photoCrop: const PhotoCrop(),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final juice = DailyJuice.create(
      id: 'j',
      profile: profile,
      date: DateTime(2026, 10, 8),
    ).copyWith(title: 'The Life of God');

    for (final q in [
      '',
      'life',
      'LIFE OF GOD',
      'god life',
      'october',
      '8 October 2026',
      'Thursday',
      '8 oct',
      '2026-10-08',
      '08/10/2026',
      '8/10/2026',
      'thursday, 8 october',
    ]) {
      test('finds by "$q"', () => expect(matchesQuery(juice, q), isTrue));
    }
    for (final q in ['november', 'baal', '9 october 2026', '2025']) {
      test(
        'does not match "$q"',
        () => expect(matchesQuery(juice, q), isFalse),
      );
    }
  });

  test('time ago labels', () {
    final now = DateTime(2026, 10, 8, 12);
    expect(
      timeAgo(now.subtract(const Duration(seconds: 20)), now: now),
      'just now',
    );
    expect(
      timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      '5 minutes ago',
    );
    expect(
      timeAgo(now.subtract(const Duration(hours: 1)), now: now),
      '1 hour ago',
    );
    expect(timeAgo(DateTime(2026, 10, 7, 9), now: now), 'yesterday');
    expect(timeAgo(DateTime(2026, 10, 5, 9), now: now), '3 days ago');
    expect(timeAgo(DateTime(2026, 9, 12, 9), now: now), '12 Sep 2026');
  });
}
