import 'package:flutter/services.dart';

/// Enforces a content limit at the moment of input.
///
/// When an edit (typing, pasting, dictation) would break the limit, the
/// edit is refused — the field keeps its previous text, nothing the author
/// already wrote is removed or shortened — and [onRejected] explains why.
class LimitFormatter extends TextInputFormatter {
  LimitFormatter({required this.check, required this.onRejected});

  /// Returns an error message when [text] breaks the limit, else null.
  final String? Function(String text) check;

  /// Called with the message, whether the refused edit was a paste, and
  /// the full text the edit would have produced (so the author can be
  /// offered a chance to shorten it themselves).
  final void Function(String message, bool pasted, String attempted) onRejected;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text == oldValue.text) return newValue;
    final error = check(newValue.text);
    if (error == null) return newValue;

    // Text loaded from an older draft may already be over a limit; still let
    // the author shorten it.
    if (newValue.text.length < oldValue.text.length &&
        check(oldValue.text) != null) {
      return newValue;
    }
    // Keyboards insert whole predicted words; only a larger insertion is
    // treated as a paste.
    final pasted = newValue.text.length - oldValue.text.length > 15;
    onRejected(error, pasted, newValue.text);
    return oldValue;
  }
}
