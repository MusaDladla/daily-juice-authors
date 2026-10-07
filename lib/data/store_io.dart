import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'store.dart';

Future<Store> openStore() async {
  final docs = await getApplicationDocumentsDirectory();
  return FileStore('${docs.path}/daily_juice');
}

/// Files in the app's private documents folder (Android and iOS).
class FileStore implements Store {
  FileStore(this.root);

  @override
  final String root;

  @override
  Future<Uint8List?> read(String key) async {
    final file = File(key);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Writes via a temporary file so a crash never leaves a half-written file.
  @override
  Future<void> write(String key, List<int> bytes) async {
    final file = File(key);
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.${_tmpId()}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<void> delete(String key) async {
    final file = File(key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<String>> list(String folder) async {
    final dir = Directory(folder);
    if (!await dir.exists()) return const [];
    // Built like the stored keys, so they compare equal on every platform.
    return [
      await for (final entity in dir.list())
        if (entity is File) '$folder/${Store.name(entity.path)}',
    ];
  }

  @override
  Future<DateTime?> modified(String key) async {
    final file = File(key);
    return await file.exists() ? file.lastModified() : null;
  }

  static String _tmpId() =>
      Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
}
