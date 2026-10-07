import 'dart:typed_data';

import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart'
    as platform;

/// Web version only: hands [bytes] to the browser as a downloaded file.
void downloadFile(Uint8List bytes, String fileName, String mimeType) =>
    platform.downloadFile(bytes, fileName, mimeType);
