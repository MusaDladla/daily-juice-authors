import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../models/daily_juice.dart';
import '../models/profile.dart';
import '../template/template_layout.dart';
import 'store.dart';

/// On-device storage: JSON documents plus images, in the app's private
/// documents folder (phones) or the site's database (web).
///
/// `daily_juice/profile.json`, `daily_juice/juices/{id}.json`,
/// `daily_juice/images/photo_{id}.jpg`, `daily_juice/exports/{id}_r{layout revision}.png`.
class JuiceRepository {
  JuiceRepository(this.store);

  final Store store;

  static Future<JuiceRepository> open() async =>
      JuiceRepository(await Store.open());

  String get root => store.root;
  String get _juices => '$root/juices';
  String get _images => '$root/images';
  String get _exports => '$root/exports';
  String get _profileFile => '$root/profile.json';

  static String newId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<Map<String, dynamic>?> _readJson(String key) async {
    final bytes = await store.read(key);
    if (bytes == null) return null;
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  // -------------------------------------------------------------- profile --

  Future<Profile?> loadProfile() async {
    final json = await _readJson(_profileFile);
    return json == null ? null : Profile.fromJson(json);
  }

  Future<void> saveProfile(Profile profile) =>
      store.write(_profileFile, utf8.encode(jsonEncode(profile.toJson())));

  /// Stores a new photo. Photos are never overwritten, because saved
  /// Daily Juices keep pointing at the photo they were written with.
  Future<String> storePhoto(Uint8List bytes) async {
    final key = '$_images/photo_${newId()}.jpg';
    await store.write(key, bytes);
    return key;
  }

  /// The bytes of a stored photo or image, or null if it is gone.
  Future<Uint8List?> readImage(String path) => store.read(path);

  // --------------------------------------------------------------- juices --

  Future<List<DailyJuice>> listJuices() async {
    final out = <DailyJuice>[];
    for (final key in await store.list(_juices)) {
      if (!key.endsWith('.json')) continue;
      // A damaged file is skipped rather than failing the whole list.
      final json = await _readJson(key);
      if (json != null) out.add(DailyJuice.fromJson(json));
    }
    out.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.updatedAt.compareTo(a.updatedAt);
    });
    return out;
  }

  Future<void> saveJuice(DailyJuice juice) => store.write(
    '$_juices/${juice.id}.json',
    utf8.encode(jsonEncode(juice.toJson())),
  );

  Future<void> deleteJuice(DailyJuice juice) async {
    await store.delete('$_juices/${juice.id}.json');
    await _deleteExports(juice.id);
    await deleteUnusedPhotos();
  }

  Future<void> _deleteExports(String id) async {
    for (final key in await store.list(_exports)) {
      final name = Store.name(key);
      if (name == '$id.png' || name.startsWith('${id}_r')) {
        await store.delete(key);
      }
    }
  }

  /// Saves the exported PNG, tagged with the layout revision that drew it.
  Future<String> saveExport(DailyJuice juice, Uint8List png) async {
    await _deleteExports(juice.id);
    final key = '$_exports/${juice.id}_r${TemplateLayoutEngine.revision}.png';
    await store.write(key, png);
    return key;
  }

  /// Whether an exported image was drawn by the current layout revision.
  static bool isCurrentExport(String path) =>
      path.endsWith('_r${TemplateLayoutEngine.revision}.png');

  /// The image already generated for this exact version of [juice], if any.
  Future<Uint8List?> readCurrentExport(DailyJuice juice) async {
    final path = juice.exportPath;
    if (path == null || !isCurrentExport(path)) return null;
    final modified = await store.modified(path);
    if (modified == null || !modified.isAfter(juice.updatedAt)) return null;
    return store.read(path);
  }

  /// Removes photos no longer used by the profile or any Daily Juice.
  Future<void> deleteUnusedPhotos() async {
    final used = <String>{};
    final profile = await loadProfile();
    if (profile != null) used.add(profile.photoPath);
    for (final j in await listJuices()) {
      used.add(j.profileImagePath);
    }
    for (final key in await store.list(_images)) {
      if (!used.contains(key) && !key.endsWith('.tmp')) {
        await store.delete(key);
      }
    }
  }
}
