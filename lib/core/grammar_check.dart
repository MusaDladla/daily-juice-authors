import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One possible correction found by the grammar checker.
class GrammarSuggestion {
  const GrammarSuggestion({
    required this.offset,
    required this.length,
    required this.original,
    required this.replacements,
    required this.message,
    required this.issueType,
  });

  /// Position in the checked text (UTF-16, like Dart strings).
  final int offset;
  final int length;

  /// The text the suggestion is about, e.g. "recieve".
  final String original;

  /// Proposed corrections, best first, e.g. ["receive", "relieve"].
  final List<String> replacements;

  /// Why, e.g. "Spelling mistake".
  final String message;

  /// "misspelling", "grammar", "typographical", "style", …
  final String issueType;

  int get end => offset + length;
}

class GrammarCheckException implements Exception {
  const GrammarCheckException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Spelling and grammar suggestions from LanguageTool (languagetool.org).
///
/// The author's text is never changed here: this only returns suggestions.
/// The author chooses which to accept, and [apply] makes exactly those
/// changes.
class GrammarChecker {
  GrammarChecker({
    this.endpoint = 'https://api.languagetool.org/v2/check',
    this.language = 'en-ZA',
  });

  /// Replaced in tests.
  static GrammarChecker instance = GrammarChecker();

  final String endpoint;

  /// South African English.
  final String language;

  static const _timeout = Duration(seconds: 20);

  Future<List<GrammarSuggestion>> check(String text) async {
    if (text.trim().isEmpty) return const [];
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(endpoint),
            headers: {'Accept': 'application/json'},
            // Sent form-encoded as UTF-8.
            body: {'text': text, 'language': language},
          )
          .timeout(_timeout);
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode == 429) {
        throw const GrammarCheckException(
          'Too many grammar checks in a short time. Please wait a minute '
          'and try again.',
        );
      }
      if (response.statusCode != 200) {
        throw GrammarCheckException(
          'The grammar check is not available right now '
          '(error ${response.statusCode}). Please try again later.',
        );
      }
      return parse(body, text);
    } on GrammarCheckException {
      rethrow;
    } on TimeoutException {
      throw const GrammarCheckException(
        'The grammar check took too long. Please check your connection and '
        'try again.',
      );
    } on FormatException {
      throw const GrammarCheckException(
        'The grammar check returned an unexpected answer. Please try again.',
      );
    } on Exception {
      // No connection, failed secure connection, or blocked by the browser.
      throw const GrammarCheckException(
        'Grammar check needs an internet connection.',
      );
    } finally {
      client.close();
    }
  }

  /// Reads a LanguageTool response. Only suggestions that offer a
  /// correction are kept, since only those can be accepted.
  static List<GrammarSuggestion> parse(String body, String text) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final matches = (json['matches'] as List?) ?? const [];
    final out = <GrammarSuggestion>[];
    for (final m in matches.cast<Map<String, dynamic>>()) {
      final offset = m['offset'] as int;
      final length = m['length'] as int;
      if (offset < 0 || length < 0 || offset + length > text.length) continue;
      final replacements = ((m['replacements'] as List?) ?? const [])
          .map((r) => (r as Map<String, dynamic>)['value'] as String)
          .where((r) => r != text.substring(offset, offset + length))
          .take(4)
          .toList();
      if (replacements.isEmpty) continue;
      final rule = m['rule'] as Map<String, dynamic>? ?? const {};
      out.add(
        GrammarSuggestion(
          offset: offset,
          length: length,
          original: text.substring(offset, offset + length),
          replacements: replacements,
          message: (m['shortMessage'] as String?)?.trim().isNotEmpty == true
              ? m['shortMessage'] as String
              : (m['message'] as String? ?? 'Possible mistake'),
          issueType: rule['issueType'] as String? ?? 'other',
        ),
      );
    }
    // Overlapping suggestions cannot both be applied; keep the first.
    out.sort((a, b) => a.offset.compareTo(b.offset));
    final kept = <GrammarSuggestion>[];
    for (final s in out) {
      if (kept.isEmpty || s.offset >= kept.last.end) kept.add(s);
    }
    return kept;
  }

  /// Applies only the accepted corrections ([chosen]: suggestion → the
  /// replacement the author picked). Everything else stays exactly as written.
  static String apply(String text, Map<GrammarSuggestion, String> chosen) {
    final ordered = chosen.keys.toList()
      ..sort((a, b) => b.offset.compareTo(a.offset)); // last first
    var result = text;
    for (final s in ordered) {
      result = result.replaceRange(s.offset, s.end, chosen[s]!);
    }
    return result;
  }
}
