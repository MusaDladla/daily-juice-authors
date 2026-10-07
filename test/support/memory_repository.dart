import 'dart:typed_data';

import 'package:daily_juice/data/juice_repository.dart';
import 'package:daily_juice/data/store.dart';
import 'package:daily_juice/models/daily_juice.dart';
import 'package:daily_juice/models/profile.dart';

/// A [Store] held in memory, with the same rules as the real ones.
class MemoryStore implements Store {
  final _bytes = <String, Uint8List>{};
  final _modified = <String, DateTime>{};

  @override
  String get root => 'daily_juice';

  @override
  Future<Uint8List?> read(String key) async => _bytes[key];

  @override
  Future<void> write(String key, List<int> bytes) async {
    _bytes[key] = Uint8List.fromList(bytes);
    _modified[key] = DateTime.now();
  }

  @override
  Future<void> delete(String key) async {
    _bytes.remove(key);
    _modified.remove(key);
  }

  @override
  Future<List<String>> list(String folder) async => [
    for (final k in _bytes.keys)
      if (k.startsWith('$folder/') &&
          !k.substring(folder.length + 1).contains('/'))
        k,
  ];

  @override
  Future<DateTime?> modified(String key) async => _modified[key];
}

/// Keeps everything in memory so widget tests never touch the disk.
class MemoryRepository extends JuiceRepository {
  MemoryRepository([Iterable<DailyJuice> juices = const []])
    : super(MemoryStore()) {
    for (final j in juices) {
      saved[j.id] = j;
    }
  }

  final saved = <String, DailyJuice>{};
  Profile? savedProfile;

  @override
  Future<void> saveProfile(Profile profile) async => savedProfile = profile;

  @override
  Future<Profile?> loadProfile() async => savedProfile;

  @override
  Future<void> deleteUnusedPhotos() async {}

  @override
  Future<void> saveJuice(DailyJuice juice) async => saved[juice.id] = juice;

  @override
  Future<List<DailyJuice>> listJuices() async => saved.values.toList();
}
