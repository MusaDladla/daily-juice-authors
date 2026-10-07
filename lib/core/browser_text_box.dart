import 'browser_text_box_stub.dart'
    if (dart.library.js_interop) 'browser_text_box_web.dart'
    as platform;

/// Web version only: whether touches reach the browser's own (invisible) text
/// box under the field being typed in. While they do, the browser handles
/// them itself and the app's Cut / Copy / Paste menu only shows sometimes.
void browserTextBoxTouches({required bool enabled}) =>
    platform.browserTextBoxTouches(enabled: enabled);
