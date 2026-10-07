import 'dart:io';
import 'dart:typed_data';

import 'package:daily_juice/data/juice_repository.dart';
import 'package:daily_juice/data/store.dart';
import 'package:daily_juice/data/store_io.dart';
import 'package:daily_juice/models/daily_juice.dart';
import 'package:daily_juice/models/profile.dart';
import 'package:daily_juice/template/photo_crop.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_repository.dart';

Profile _profile(String photoPath) => Profile(
  id: 'u1',
  name: 'Musa',
  surname: 'Dladla',
  branch: '',
  photoPath: photoPath,
  photoCrop: const PhotoCrop(),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// The same storage rules, run against the phones' file store and the
/// in-memory store (which behaves like the web version's database).
void main() {
  final stores = <String, Future<Store> Function()>{
    'files (Android/iOS)': () async {
      final dir = await Directory.systemTemp.createTemp('dj_repo_');
      addTearDown(() => dir.delete(recursive: true));
      return FileStore('${dir.path}/daily_juice');
    },
    'memory': () async => MemoryStore(),
  };

  for (final MapEntry(key: name, value: open) in stores.entries) {
    group(name, () {
      late JuiceRepository repo;
      setUp(() async => repo = JuiceRepository(await open()));

      test('empty store has no profile and no Daily Juices', () async {
        expect(await repo.loadProfile(), isNull);
        expect(await repo.listJuices(), isEmpty);
      });

      test('profile, photo and Daily Juices round-trip', () async {
        final photo = await repo.storePhoto(Uint8List.fromList([1, 2, 3]));
        await repo.saveProfile(_profile(photo));
        expect((await repo.loadProfile())!.photoPath, photo);
        expect(await repo.readImage(photo), [1, 2, 3]);

        final a = DailyJuice.create(
          id: 'a',
          profile: _profile(photo),
          date: DateTime(2026, 10, 8),
        );
        final b = DailyJuice.create(
          id: 'b',
          profile: _profile(photo),
          date: DateTime(2026, 10, 9),
        );
        await repo.saveJuice(a);
        await repo.saveJuice(b);
        // Newest date first.
        expect([for (final j in await repo.listJuices()) j.id], ['b', 'a']);
      });

      test('a generated image is reused only for the same version', () async {
        final juice = DailyJuice.create(
          id: 'j',
          profile: _profile(''),
          date: DateTime(2026, 10, 8),
        ).copyWith(updatedAt: DateTime(2000));
        final path = await repo.saveExport(juice, Uint8List.fromList([9]));
        expect(JuiceRepository.isCurrentExport(path), isTrue);
        final saved = juice.copyWith(exportPath: path);
        expect(await repo.readCurrentExport(saved), [9]);
        // Edited after the image was made: draw it again.
        final edited = saved.copyWith(
          updatedAt: DateTime.now().add(const Duration(minutes: 1)),
        );
        expect(await repo.readCurrentExport(edited), isNull);
      });

      test('deleting a Daily Juice removes its image and unused photos',
          () async {
        final kept = await repo.storePhoto(Uint8List.fromList([1]));
        final old = await repo.storePhoto(Uint8List.fromList([2]));
        await repo.saveProfile(_profile(kept));
        final juice = DailyJuice.create(
          id: 'j',
          profile: _profile(old),
          date: DateTime(2026, 10, 8),
        );
        await repo.saveJuice(juice);
        final export = await repo.saveExport(juice, Uint8List.fromList([9]));

        await repo.deleteJuice(juice);
        expect(await repo.listJuices(), isEmpty);
        expect(await repo.store.read(export), isNull);
        expect(await repo.readImage(old), isNull);
        expect(await repo.readImage(kept), [1]);
      });

      test('a damaged document is skipped', () async {
        await repo.saveJuice(
          DailyJuice.create(
            id: 'ok',
            profile: _profile(''),
            date: DateTime(2026, 10, 8),
          ),
        );
        await repo.store.write('${repo.root}/juices/bad.json', [123, 34]);
        expect([for (final j in await repo.listJuices()) j.id], ['ok']);
      });
    });
  }
}
