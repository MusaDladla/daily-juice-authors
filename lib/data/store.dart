import 'dart:typed_data';

import 'store_io.dart' if (dart.library.js_interop) 'store_web.dart' as platform;

/// Where the app keeps its documents and images.
///
/// Keys are slash-separated paths under [root]. On phones they are real file
/// paths in the app's documents folder; in a browser they name entries in the
/// site's IndexedDB database.
abstract class Store {
  /// The folder (or key prefix) holding everything the app stores.
  String get root;

  /// The bytes stored at [key], or null if there are none.
  Future<Uint8List?> read(String key);

  /// Stores [bytes] at [key]. A failed write never leaves half a document.
  Future<void> write(String key, List<int> bytes);

  /// Removes [key]; does nothing if it is not stored.
  Future<void> delete(String key);

  /// The keys stored directly in [folder].
  Future<List<String>> list(String folder);

  /// When [key] was last written, or null if it is not stored.
  Future<DateTime?> modified(String key);

  /// The file name part of [key], e.g. `photo_ab12.jpg`.
  static String name(String key) =>
      key.substring(key.lastIndexOf(RegExp(r'[/\\]')) + 1);

  /// The store for this platform.
  static Future<Store> open() => platform.openStore();
}
