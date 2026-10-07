import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the bundled template fonts into the test engine so layout tests
/// measure real glyphs (tests otherwise use a placeholder font).
Future<void> loadTemplateFonts() async {
  Future<ByteData> bytes(String file) async => ByteData.sublistView(
    Uint8List.fromList(await File('assets/fonts/$file').readAsBytes()),
  );

  final condensed = FontLoader('BarlowCondensed')
    ..addFont(bytes('BarlowCondensed-Light.ttf'))
    ..addFont(bytes('BarlowCondensed-SemiBold.ttf'))
    ..addFont(bytes('BarlowCondensed-Bold.ttf'));
  final sans = FontLoader('Arimo')
    ..addFont(bytes('Arimo-Regular.ttf'))
    ..addFont(bytes('Arimo-Bold.ttf'));
  await Future.wait([condensed.load(), sans.load()]);
}
