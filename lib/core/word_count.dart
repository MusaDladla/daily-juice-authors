/// Reliable word counting shared by every limit in the app.
///
/// Words are whitespace-separated tokens. A token only counts when it
/// contains at least one letter or digit, so punctuation never creates extra
/// words: "God is good." is 3 words, and a stray "—" or "…" counts as 0.
library;

final RegExp _whitespace = RegExp(r'\s+');
final RegExp _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

List<String> wordTokens(String text) => text
    .split(_whitespace)
    .where((token) => _wordChar.hasMatch(token))
    .toList(growable: false);

int countWords(String text) => wordTokens(text).length;
