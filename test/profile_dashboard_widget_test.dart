import 'dart:ui' as ui;

import 'package:daily_juice/app_state.dart';
import 'package:daily_juice/models/daily_juice.dart';
import 'package:daily_juice/models/profile.dart';
import 'package:daily_juice/template/photo_crop.dart';
import 'package:daily_juice/ui/home_screen.dart';
import 'package:daily_juice/ui/profile_screen.dart';
import 'package:daily_juice/ui/theme.dart';
import 'package:daily_juice/ui/widgets/brand.dart';
import 'package:daily_juice/ui/widgets/photo_framer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_repository.dart';
import 'support/template_fonts.dart';

final _profile = Profile(
  id: 'u1',
  name: 'Musa',
  surname: 'Dladla',
  branch: '',
  photoPath: '',
  photoCrop: const PhotoCrop(),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.8;
  addTearDown(tester.view.reset);
}

Future<ui.Image> _squareImage(WidgetTester tester) async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 600, 600), Paint()..color = Colors.teal);
  return (await tester.runAsync(
    () => recorder.endRecording().toImage(600, 600),
  ))!;
}

Future<void> _press(WidgetTester tester, String label) async {
  final g = await tester.startGesture(
    tester.getCenter(find.bySemanticsLabel(label)),
  );
  await tester.pump(const Duration(milliseconds: 30));
  await g.up();
  await tester.pump();
}

/// Serves one in-memory photo so tests never touch the disk.
class _PhotoState extends AppState {
  _PhotoState(this.photo) : super(MemoryRepository());
  final ui.Image photo;
  @override
  ui.Image? peekImage(String path) => photo;
  @override
  Future<ui.Image?> image(String path) async => photo;
}

void main() {
  setUpAll(loadTemplateFonts);

  testWidgets('profile photo moves left, right, up and down with the arrows', (
    tester,
  ) async {
    _phone(tester);
    final image = await _squareImage(tester);
    var crop = const PhotoCrop();
    await tester.pumpWidget(
      MaterialApp(
        theme: Brand.theme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PhotoFramer(
              image: image,
              crop: crop,
              onChanged: (c) => setState(() => crop = c),
            ),
          ),
        ),
      ),
    );

    // A square photo in the portrait slot has room to move sideways.
    await _press(tester, 'Move photo left');
    expect(crop.cx, greaterThan(0.5), reason: 'photo moved left');
    final afterLeft = crop.cx;
    await _press(tester, 'Move photo right');
    expect(crop.cx, lessThan(afterLeft), reason: 'photo moved right');

    // It fills the frame top-to-bottom, so "up" zooms in slightly to make
    // room instead of doing nothing (and never leaves an empty edge).
    expect(crop.zoom, 1.0);
    await _press(tester, 'Move photo up');
    expect(crop.zoom, greaterThan(1.0));
    expect(crop.cy, greaterThan(0.5), reason: 'photo moved up');
    final afterUp = crop.cy;
    await _press(tester, 'Move photo down');
    expect(crop.cy, lessThan(afterUp), reason: 'photo moved down');
  });

  group('dashboard', () {
    final october = DailyJuice.create(
      id: 'a',
      profile: _profile,
      date: DateTime(2026, 10, 8),
    ).copyWith(title: 'The Life of God', status: JuiceStatus.generated);
    final september = DailyJuice.create(
      id: 'b',
      profile: _profile,
      date: DateTime(2026, 9, 30),
    ).copyWith(title: 'Baal Perazim', status: JuiceStatus.generated);
    final draft = DailyJuice.create(
      id: 'c',
      profile: _profile,
      date: DateTime(2026, 10, 9),
    ).copyWith(title: 'Unfinished Grace');

    Future<void> pumpDashboard(WidgetTester tester) async {
      _phone(tester);
      // No disk access: real file I/O never completes in widget tests.
      final state = AppState(MemoryRepository())
        ..profile = _profile
        ..juices = [draft, october, september]; // newest date first
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(theme: Brand.theme(), home: const HomeScreen()),
        ),
      );
      await tester.pump();
    }

    Finder tile(String title) => find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.text(title),
    );

    testWidgets('shows the ministry statements, drafts and footer', (
      tester,
    ) async {
      await pumpDashboard(tester);
      expect(find.text(Ministry.tagline), findsOneWidget);
      expect(find.text(Ministry.reach), findsOneWidget);
      expect(find.text('Welcome back, Musa'), findsOneWidget);

      // Minimal: no separate stats or "continue writing" row; each Daily
      // Juice (draft or generated) appears exactly once, in the list.
      expect(find.text('CONTINUE WRITING'), findsNothing);
      expect(find.text('Total'), findsNothing);
      await tester.scrollUntilVisible(
        tile('UNFINISHED GRACE'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tile('UNFINISHED GRACE'), findsOneWidget);
      expect(find.text('DRAFT'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(Ministry.createdBy.toUpperCase()),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(Ministry.createdBy.toUpperCase()), findsOneWidget);
    });

    testWidgets('search by title and by date', (tester) async {
      await pumpDashboard(tester);
      final search = find.widgetWithText(TextField, 'Search by title or date');
      await tester.scrollUntilVisible(
        search,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.enterText(search, 'baal');
      await tester.pump();
      expect(tile('BAAL PERAZIM'), findsOneWidget);
      expect(tile('THE LIFE OF GOD'), findsNothing);

      await tester.enterText(search, 'october');
      await tester.pump();
      expect(tile('BAAL PERAZIM'), findsNothing);
      expect(tile('THE LIFE OF GOD'), findsOneWidget);

      await tester.enterText(search, '30/09/2026');
      await tester.pump();
      expect(tile('BAAL PERAZIM'), findsOneWidget);
      expect(tile('THE LIFE OF GOD'), findsNothing);

      await tester.enterText(search, 'nothing like this');
      await tester.pump();
      expect(find.text('No Daily Juice matches your search.'), findsOneWidget);
    });
  });

  group('profile: unsaved changes', () {
    late ui.Image image;
    late _PhotoState state;

    Future<void> openProfile(WidgetTester tester) async {
      _phone(tester);
      image = await _squareImage(tester);
      state = _PhotoState(image)..profile = _profile.copyWith(photoPath: 'p');
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: Brand.theme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                    child: const Text('open profile'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open profile'));
      await tester.pumpAndSettle();
      expect(find.text('YOUR PROFILE'), findsOneWidget);
    }

    Finder nameField() => find.widgetWithText(TextField, 'Name *');

    Future<void> editName(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
        nameField(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(nameField(), text);
      await tester.pump();
    }

    testWidgets('no changes: leaves straight away', (tester) async {
      await openProfile(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Save your changes?'), findsNothing);
      expect(find.text('open profile'), findsOneWidget);
    });

    testWidgets('changes + back: asks, and discard keeps the old profile', (
      tester,
    ) async {
      await openProfile(tester);
      await editName(tester, 'Sicelo');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Save your changes?'), findsOneWidget);
      expect(find.text('Discard and exit'), findsOneWidget);
      expect(find.text('SAVE AND EXIT'), findsOneWidget);

      await tester.tap(find.text('Discard and exit'));
      await tester.pumpAndSettle();
      expect(find.text('open profile'), findsOneWidget);
      expect(state.profile!.name, 'Musa');
    });

    testWidgets('changes + back: save and exit saves them', (tester) async {
      await openProfile(tester);
      await editName(tester, 'Sicelo');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE AND EXIT'));
      await tester.pumpAndSettle();
      expect(find.text('open profile'), findsOneWidget);
      expect(state.profile!.name, 'Sicelo');
    });

    testWidgets('dismissing the question keeps editing', (tester) async {
      await openProfile(tester);
      await editName(tester, 'Sicelo');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // outside the dialog
      await tester.pumpAndSettle();
      expect(find.text('YOUR PROFILE'), findsOneWidget);
      expect(find.text('Sicelo'), findsOneWidget);
    });

    testWidgets('SAVE PROFILE saves without asking', (tester) async {
      await openProfile(tester);
      await editName(tester, 'Sicelo');
      final save = find.text('SAVE PROFILE');
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Save your changes?'), findsNothing);
      expect(find.text('open profile'), findsOneWidget);
      expect(state.profile!.name, 'Sicelo');
    });
  });
}
