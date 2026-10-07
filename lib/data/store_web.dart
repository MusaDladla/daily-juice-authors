import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import 'store.dart';

const _db = 'daily_juice';
const _files = 'files';

Future<Store> openStore() async {
  final store = IndexedDbStore();
  await store._database(); // Fail at start-up, not at the first save.
  return store;
}

/// The site's IndexedDB database (web version). Each entry holds the bytes
/// and when they were written; entries stay until the site's data is
/// cleared.
///
/// Safari closes the connection when the page goes to the background, for
/// example while the photo picker or another app is open. Every operation
/// therefore reopens the database once if the connection has been closed.
class IndexedDbStore implements Store {
  Future<Database>? _opening;

  @override
  String get root => 'daily_juice';

  Future<Database> _database() => _opening ??= idbFactoryBrowser
      .open(
        _db,
        version: 1,
        onUpgradeNeeded: (e) => e.database.createObjectStore(_files),
      )
      .then((db) {
        db.onVersionChange.listen((_) => _forget(db));
        return db;
      }, onError: (Object e) {
        _opening = null;
        throw e;
      });

  void _forget(Database db) {
    _opening = null;
    try {
      db.close();
    } catch (_) {
      // Already closed.
    }
  }

  /// Runs [op], reopening the database once if Safari closed the connection.
  /// Every operation here is safe to repeat.
  Future<T> _run<T>(Future<T> Function(Database db) op) async {
    final db = await _database();
    try {
      return await op(db);
    } catch (_) {
      if (identical(await _opening, db)) _forget(db);
      return op(await _database());
    }
  }

  @override
  Future<Uint8List?> read(String key) => _run((db) async {
    final entry = await db
        .transaction(_files, idbModeReadOnly)
        .objectStore(_files)
        .getObject(key);
    if (entry is! Map) return null;
    final bytes = entry['bytes'];
    return bytes is Uint8List
        ? bytes
        : Uint8List.fromList(List<int>.from(bytes as List));
  });

  @override
  Future<void> write(String key, List<int> bytes) => _run((db) async {
    final txn = db.transaction(_files, idbModeReadWrite);
    await txn.objectStore(_files).put({
      'bytes': bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      'modified': DateTime.now().millisecondsSinceEpoch,
    }, key);
    await txn.completed;
  });

  @override
  Future<void> delete(String key) => _run((db) async {
    final txn = db.transaction(_files, idbModeReadWrite);
    await txn.objectStore(_files).delete(key);
    await txn.completed;
  });

  @override
  Future<List<String>> list(String folder) => _run((db) async {
    final prefix = '$folder/';
    final keys = await db
        .transaction(_files, idbModeReadOnly)
        .objectStore(_files)
        .getAllKeys();
    return [
      for (final k in keys.cast<String>())
        if (k.startsWith(prefix) && !k.substring(prefix.length).contains('/'))
          k,
    ];
  });

  @override
  Future<DateTime?> modified(String key) => _run((db) async {
    final entry = await db
        .transaction(_files, idbModeReadOnly)
        .objectStore(_files)
        .getObject(key);
    if (entry is! Map) return null;
    return DateTime.fromMillisecondsSinceEpoch(entry['modified'] as int);
  });
}
