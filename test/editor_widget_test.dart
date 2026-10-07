import 'package:daily_juice/app_state.dart';
import 'package:daily_juice/core/limits.dart';
import 'package:daily_juice/core/word_count.dart';
import 'package:daily_juice/models/daily_juice.dart';
import 'package:daily_juice/models/profile.dart';
import 'package:daily_juice/template/photo_crop.dart';
import 'package:daily_juice/ui/editor_screen.dart';
import 'package:daily_juice/ui/theme.dart';
import 'package:daily_juice/ui/widgets/focus_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_repository.dart';
import 'support/template_fonts.dart';

final _profile = Profile(
  id: 'u1',
  name: 'Christian',
  surname: 'Mapitle',
  branch: 'Soweto',
  photoPath: '',
  photoCrop: const PhotoCrop(),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pumpEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.8;
  addTearDown(tester.view.reset);
  final state = AppState(MemoryRepository())..profile = _profile;
  final juice = DailyJuice.create(
    id: 'j1',
    profile: _profile,
    date: DateTime(2026, 9, 30),
  );
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        theme: Brand.theme(),
        home: EditorScreen(initial: juice, isNew: true),
      ),
    ),
  );
  await tester.pump();
}

TextField _field(WidgetTester tester, Finder f) => tester.widget<TextField>(f);

Finder _fieldWithHint(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

Finder _fieldWithLabel(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  setUpAll(loadTemplateFonts);

  testWidgets('title: live counter and an 8th word is refused', (tester) async {
    await _pumpEditor(tester);
    final title = _fieldWithHint('e.g. LET GO AND LET GOD');

    await tester.enterText(title, 'JESUS CHRIST IS THE PATHWAY TO LIFE');
    await tester.pump();
    expect(find.text('7 / 7 words'), findsOneWidget);

    await tester.enterText(title, 'JESUS CHRIST IS THE PATHWAY TO NEW LIFE');
    await tester.pump();
    expect(find.text(Msg.titleWords), findsOneWidget);
    expect(
      _field(tester, title).controller!.text,
      'JESUS CHRIST IS THE PATHWAY TO LIFE',
      reason: 'existing text must be kept, not cut',
    );
  });

  testWidgets('Further Study: a 4th reference is refused', (tester) async {
    await _pumpEditor(tester);
    final add = find.text('ADD REFERENCE');

    for (var i = 0; i < 2; i++) {
      await _scrollTo(tester, add);
      await tester.tap(add);
      await tester.pump();
    }
    expect(_fieldWithLabel('Reference 3'), findsOneWidget);

    await _scrollTo(tester, add);
    await tester.tap(add, warnIfMissed: false);
    await tester.pump();
    expect(find.text(Msg.furtherStudyMax), findsOneWidget);
    expect(_fieldWithLabel('Reference 4'), findsNothing);

    await tester.enterText(_fieldWithLabel('Reference 1'), 'Isaiah 28:21');
    await tester.pump();
    expect(find.text('1 / 3 references'), findsOneWidget);
  });

  testWidgets('an over-long paste opens the shorten sheet; nothing is lost', (
    tester,
  ) async {
    await _pumpEditor(tester);
    final message = _fieldWithHint('Write your Daily Juice…');
    // Far more than the page can hold, even with free space.
    final pasted = List.filled(400, 'grace').join(' ');

    await _scrollTo(tester, message);
    await tester.enterText(message, pasted);
    await tester.pumpAndSettle();

    expect(find.text('SHORTEN MESSAGE'), findsOneWidget);
    expect(
      _field(tester, message).controller!.text,
      isEmpty,
      reason: 'nothing is inserted until it fits',
    );

    final sheetField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    expect(
      _field(tester, sheetField).controller!.text,
      pasted,
      reason: 'the author gets their full text to edit',
    );

    final useButton = find.widgetWithText(FilledButton, 'USE THIS TEXT');
    expect(tester.widget<FilledButton>(useButton).onPressed, isNull);

    final shortened = List.filled(150, 'grace').join(' ');
    await tester.enterText(sheetField, shortened);
    await tester.pump();
    expect(tester.widget<FilledButton>(useButton).onPressed, isNotNull);

    await tester.tap(useButton);
    await tester.pumpAndSettle();
    expect(countWords(_field(tester, message).controller!.text), 150);
    expect(find.text('150 / 171 words'), findsOneWidget);
  });

  testWidgets(
    'while typing, a live strip of the page replaces the generate bar',
    (tester) async {
      await _pumpEditor(tester);
      expect(find.text('GENERATE DAILY JUICE'), findsOneWidget);
      expect(find.byType(FocusPreview), findsNothing);

      await tester.tap(_fieldWithHint('e.g. LET GO AND LET GOD'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pumpAndSettle();
      expect(find.byType(FocusPreview), findsOneWidget);
      expect(find.text('GENERATE DAILY JUICE'), findsNothing);

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pump();
      expect(find.byType(FocusPreview), findsNothing);
      expect(find.text('Show live preview while typing'), findsOneWidget);
    },
  );
}
