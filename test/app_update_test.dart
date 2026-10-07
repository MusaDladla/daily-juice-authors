import 'package:daily_juice/app_state.dart';
import 'package:daily_juice/core/app_update.dart';
import 'package:daily_juice/models/profile.dart';
import 'package:daily_juice/template/photo_crop.dart';
import 'package:daily_juice/ui/home_screen.dart';
import 'package:daily_juice/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_repository.dart';

Map<String, dynamic> _release(String tag, {bool apk = true}) => {
  'tag_name': tag,
  'body': 'Edit on the page.',
  'assets': [
    {
      'name': apk ? 'daily-juice-authors-1.0.3.apk' : 'notes.txt',
      'browser_download_url': 'https://github.com/x/y/releases/download/a',
    },
  ],
};

void main() {
  test('versions compare part by part', () {
    expect(AppUpdate.compareVersions('1.0.10', '1.0.9'), greaterThan(0));
    expect(AppUpdate.compareVersions('1.1', '1.0.9'), greaterThan(0));
    expect(AppUpdate.compareVersions('1.0.2', '1.0.2+3'), 0);
    expect(AppUpdate.compareVersions('1.0.1', '1.0.2'), lessThan(0));
  });

  test('only a newer release with an APK is offered', () {
    final update = AppUpdate.fromRelease(_release('v1.0.3'), '1.0.2');
    expect(update?.version, '1.0.3');
    expect(update?.notes, 'Edit on the page.');
    expect(AppUpdate.fromRelease(_release('v1.0.2'), '1.0.2'), isNull);
    expect(AppUpdate.fromRelease(_release('v1.0.1'), '1.0.2'), isNull);
    expect(
      AppUpdate.fromRelease(_release('v1.0.3', apk: false), '1.0.2'),
      isNull,
    );
  });

  testWidgets('the dashboard offers a newer version until LATER', (
    tester,
  ) async {
    final profile = Profile(
      id: 'u1',
      name: 'Musa',
      surname: 'Dladla',
      branch: '',
      photoPath: '',
      photoCrop: const PhotoCrop(),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final update = AppUpdate.fromRelease(_release('v1.0.3'), '1.0.2')!;
    await tester.pumpWidget(
      AppScope(
        state: AppState(MemoryRepository())..profile = profile,
        child: MaterialApp(
          theme: Brand.theme(),
          home: HomeScreen(checkForUpdate: () async => update),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('NEW VERSION AVAILABLE (1.0.3)'), findsOneWidget);
    expect(find.text('Edit on the page.'), findsOneWidget);
    expect(find.text('DOWNLOAD'), findsOneWidget);

    await tester.tap(find.text('LATER'));
    await tester.pump();
    expect(find.text('NEW VERSION AVAILABLE (1.0.3)'), findsNothing);
  });
}
