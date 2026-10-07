import 'dart:convert';

import 'package:daily_juice/app_state.dart';
import 'package:daily_juice/core/grammar_check.dart';
import 'package:daily_juice/models/daily_juice.dart';
import 'package:daily_juice/models/profile.dart';
import 'package:daily_juice/template/photo_crop.dart';
import 'package:daily_juice/ui/editor_screen.dart';
import 'package:daily_juice/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_repository.dart';
import 'support/template_fonts.dart';

const _text = 'He recieve the blessing and they was happy. Their is hope.';

/// A LanguageTool response in its real format (trimmed).
String _response(String text) => jsonEncode({
  'language': {'name': 'English (South African)', 'code': 'en-ZA'},
  'matches': [
    {
      'message': 'Possible spelling mistake found.',
      'shortMessage': 'Spelling mistake',
      'offset': text.indexOf('recieve'),
      'length': 7,
      'replacements': [
        {'value': 'receive'},
        {'value': 'relieve'},
      ],
      'rule': {'id': 'MORFOLOGIK_RULE_EN_ZA', 'issueType': 'misspelling'},
    },
    {
      'message': 'Possible agreement error.',
      'shortMessage': 'Possible agreement error',
      'offset': text.indexOf('was'),
      'length': 3,
      'replacements': [
        {'value': 'were'},
      ],
      'rule': {'id': 'PERS_PRONOUN_AGREEMENT', 'issueType': 'grammar'},
    },
    {
      'message': 'Did you mean "There"?',
      'shortMessage': '',
      'offset': text.indexOf('Their'),
      'length': 5,
      'replacements': [
        {'value': 'There'},
      ],
      'rule': {'id': 'THEIR_IS', 'issueType': 'misspelling'},
    },
    {
      // No correction offered: cannot be accepted, so it is dropped.
      'message': 'Style note.',
      'offset': 0,
      'length': 2,
      'replacements': [],
      'rule': {'id': 'X', 'issueType': 'style'},
    },
  ],
});

class _FakeChecker extends GrammarChecker {
  _FakeChecker({this.error});
  final GrammarCheckException? error;
  int calls = 0;

  @override
  Future<List<GrammarSuggestion>> check(String text) async {
    calls++;
    if (error != null) throw error!;
    return GrammarChecker.parse(_response(text), text);
  }
}

final _profile = Profile(
  id: 'u1',
  name: 'Christian',
  surname: 'Mapitle',
  branch: '',
  photoPath: '',
  photoCrop: const PhotoCrop(),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('LanguageTool suggestions', () {
    final suggestions = GrammarChecker.parse(_response(_text), _text);

    test('parses corrections and drops ones with nothing to apply', () {
      expect(suggestions.map((s) => s.original), ['recieve', 'was', 'Their']);
      expect(suggestions.first.replacements, ['receive', 'relieve']);
      expect(suggestions.first.message, 'Spelling mistake');
      expect(suggestions[2].message, 'Did you mean "There"?');
    });

    test('applies only what the author accepted, nothing else', () {
      final result = GrammarChecker.apply(_text, {
        suggestions[0]: 'receive',
        suggestions[2]: 'There',
      });
      expect(
        result,
        'He receive the blessing and they was happy. There is hope.',
      );
      expect(GrammarChecker.apply(_text, {}), _text);
    });

    test('overlapping suggestions keep only the first', () {
      final body = jsonEncode({
        'matches': [
          {
            'offset': 3,
            'length': 7,
            'replacements': [
              {'value': 'receive'},
            ],
            'rule': {'issueType': 'misspelling'},
          },
          {
            'offset': 5,
            'length': 10,
            'replacements': [
              {'value': 'x'},
            ],
            'rule': {'issueType': 'grammar'},
          },
        ],
      });
      expect(GrammarChecker.parse(body, _text).length, 1);
    });
  });

  group('editor', () {
    setUpAll(loadTemplateFonts);
    tearDown(() => GrammarChecker.instance = GrammarChecker());

    Future<void> pumpEditor(WidgetTester tester, String message) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.8;
      addTearDown(tester.view.reset);
      final state = AppState(MemoryRepository())..profile = _profile;
      final juice = DailyJuice.create(
        id: 'j1',
        profile: _profile,
        date: DateTime(2026, 9, 30),
      ).copyWith(mainMessage: message);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: Brand.theme(),
            home: EditorScreen(initial: juice),
          ),
        ),
      );
      await tester.pump();
    }

    Finder messageField() => find.byWidgetPredicate(
      (w) =>
          w is TextField && w.decoration?.hintText == 'Write your Daily Juice…',
    );

    Future<void> tapMessageCheck(WidgetTester tester) async {
      final button = find.text('CHECK GRAMMAR');
      await tester.scrollUntilVisible(
        button,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(button); // built is not on screen
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('only the Main Message has a grammar check', (tester) async {
      await pumpEditor(tester, _text);
      final scroll = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      // Title and Theme Scripture (top of the form): no check button.
      expect(find.text('CHECK GRAMMAR'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('CHECK GRAMMAR'),
        300,
        scrollable: scroll,
      );
      // It sits inside the Main Message section.
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('MAIN MESSAGE'),
            matching: find.byType(Card),
          ),
          matching: find.text('CHECK GRAMMAR'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('nothing changes until the author chooses, then only that', (
      tester,
    ) async {
      final checker = _FakeChecker();
      GrammarChecker.instance = checker;
      await pumpEditor(tester, _text);
      await tapMessageCheck(tester);

      expect(checker.calls, 1);
      expect(find.text('GRAMMAR CHECK · MAIN MESSAGE'), findsOneWidget);
      final apply = find.widgetWithText(FilledButton, 'APPLY');
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);

      await tester.tap(find.widgetWithText(ChoiceChip, 'receive'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'APPLY 1 CHANGE'));
      await tester.pumpAndSettle();

      final text = tester.widget<TextField>(messageField()).controller!.text;
      expect(
        text,
        'He receive the blessing and they was happy. Their is hope.',
      );
    });

    testWidgets('accept all applies every suggestion', (tester) async {
      GrammarChecker.instance = _FakeChecker();
      await pumpEditor(tester, _text);
      await tapMessageCheck(tester);
      await tester.tap(find.text('Accept all'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'APPLY 3 CHANGES'));
      await tester.pumpAndSettle();
      final text = tester.widget<TextField>(messageField()).controller!.text;
      expect(
        text,
        'He receive the blessing and they were happy. There is hope.',
      );
    });

    testWidgets('offline: explains, changes nothing', (tester) async {
      GrammarChecker.instance = _FakeChecker(
        error: const GrammarCheckException(
          'Grammar check needs an internet connection.',
        ),
      );
      await pumpEditor(tester, _text);
      await tapMessageCheck(tester);
      expect(
        find.text('Grammar check needs an internet connection.'),
        findsOneWidget,
      );
      final text = tester.widget<TextField>(messageField()).controller!.text;
      expect(text, _text);
    });
  });
}
