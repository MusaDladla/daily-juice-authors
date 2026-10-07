import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import 'store.dart';

const _db = 'daily_juice';
const _files = 'files';

Future<Store> openStore() async {
  final db = await idbFactoryBrowser.open(
    _db,
    version: 1,
    onUpgradeNeeded: (e) => e.database.createObjectStore(_files),
  );
  return IndexedDbStore(db);
}

/// The site's IndexedDB database (web version). Each entry holds the bytes
/// and when they were written; entries stay until the site's data is
/// cleared.
class IndexedDbStore implements Store {
  IndexedDbStore(this._db);

  final Database _db;

  @override
  String get root => 'daily_juice';

  ObjectStore _store(String mode) =>
      _db.transaction(_files, mode).objectStore(_files);

  @override
  Future<Uint8List?> read(String key) async {
    final entry = await _store(idbModeReadOnly).getObject(key);
    if (entry is! Map) return null;
    final bytes = entry['bytes'];
    return bytes is Uint8List ? bytes : Uint8List.fromList(List<int>.from(bytes as List));
  }

  @override
  Future<void> write(String key, List<int> bytes) async {
    final txn = _db.transaction(_files, idbModeReadWrite);
    await txn.objectStore(_files).put({
      'bytes': bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      'modified': DateTime.now().millisecondsSinceEpoch,
    }, key);
    await txn.completed;
  }

  @override
  Future<void> delete(String key) async {
    final txn = _db.transaction(_files, idbModeReadWrite);
    await txn.objectStore(_files).delete(key);
    await txn.completed;
  }

  @override
  Future<List<String>> list(String folder) async {
    final prefix = '$folder/';
    final keys = await _store(idbModeReadOnly).getAllKeys();
    return [
      for (final k in keys.cast<String>())
        if (k.startsWith(prefix) && !k.substring(prefix.length).contains('/'))
          k,
    ];
  }

  @override
  Future<DateTime?> modified(String key) async {
    final entry = await _store(idbModeReadOnly).getObject(key);
    if (entry is! Map) return null;
    return DateTime.fromMillisecondsSinceEpoch(entry['modified'] as int);
  }
}
