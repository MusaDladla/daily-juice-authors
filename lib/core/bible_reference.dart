/// Recognises the shape of a Bible reference so Further Study entries stay
/// "references only". The author's text is never rewritten — this only
/// decides whether an entry is acceptable.
///
/// Accepts e.g. `1 CHRONICLES 14:11`, `Isaiah 28:21`, `Psalm 23`,
/// `Song of Solomon 2:4`, `John 3:16-18`, `Matthew 5:3, 5, 7`,
/// `Genesis 1:1–2:3`, `1Cor 13:4`, `Romans 8:28 NKJV`, and book names in
/// other languages (`1 Dikronike 14:11`).
/// Rejects verse text such as `Then David came to Baal Perazim...`.
library;

final RegExp _bibleReference = RegExp(
  r'^(?:[1-4]|I{1,3}|IV)?\s*'
  r"\p{L}[\p{L}.'’]*(?:\s+\p{L}[\p{L}.'’]*){0,3}\s*"
  r'\d{1,3}(?:\s*[:.]\s*\d{1,3}[a-c]?)?'
  r'(?:\s*[-–—]\s*\d{1,3}(?:\s*[:.]\s*\d{1,3}[a-c]?)?)?'
  r'(?:\s*[,;]\s*\d{1,3}(?:\s*[:.]\s*\d{1,3})?(?:\s*[-–—]\s*\d{1,3})?)*'
  r'(?:\s+\(?\p{Lu}{2,6}\)?)?$',
  unicode: true,
);

bool isBibleReference(String value) =>
    _bibleReference.hasMatch(value.trim().replaceAll(RegExp(r'\s+'), ' '));
