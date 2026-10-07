import 'package:web/web.dart' as web;

const _styleId = 'dj-no-browser-text-touches';

void browserTextBoxTouches({required bool enabled}) {
  final existing = web.document.getElementById(_styleId);
  if (enabled) {
    existing?.remove();
    return;
  }
  if (existing != null) return;
  final style = web.HTMLStyleElement()
    ..id = _styleId
    ..textContent =
        'flt-text-editing-host, flt-text-editing-host * '
        '{ pointer-events: none !important; }';
  web.document.head!.append(style);
}
