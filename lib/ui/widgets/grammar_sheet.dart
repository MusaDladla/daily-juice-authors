import 'package:flutter/material.dart';

import '../../core/grammar_check.dart';
import '../theme.dart';
import 'form_parts.dart';

/// Lets the author review grammar suggestions one by one. Nothing changes
/// unless the author picks a correction; returns the corrected text, or
/// null when cancelled.
Future<String?> showGrammarSheet(
  BuildContext context, {
  required String fieldName,
  required String text,
  required List<GrammarSuggestion> suggestions,
  required String? Function(String) check,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _GrammarSheet(
    fieldName: fieldName,
    text: text,
    suggestions: suggestions,
    check: check,
  ),
);

class _GrammarSheet extends StatefulWidget {
  const _GrammarSheet({
    required this.fieldName,
    required this.text,
    required this.suggestions,
    required this.check,
  });

  final String fieldName;
  final String text;
  final List<GrammarSuggestion> suggestions;
  final String? Function(String) check;

  @override
  State<_GrammarSheet> createState() => _GrammarSheetState();
}

class _GrammarSheetState extends State<_GrammarSheet> {
  /// The correction chosen for each suggestion; absent = keep as written.
  final Map<GrammarSuggestion, String> _chosen = {};

  String get _result => GrammarChecker.apply(widget.text, _chosen);

  void _acceptAll() => setState(() {
    for (final s in widget.suggestions) {
      _chosen[s] = s.replacements.first;
    }
  });

  @override
  Widget build(BuildContext context) {
    final count = _chosen.length;
    final error = count == 0 ? null : widget.check(_result);
    final n = widget.suggestions.length;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'GRAMMAR CHECK · ${widget.fieldName.toUpperCase()}',
                        style: Brand.heading(20),
                      ),
                    ),
                    TextButton(
                      onPressed: _chosen.length == n ? null : _acceptAll,
                      child: const Text('Accept all'),
                    ),
                  ],
                ),
                Text(
                  n == 1
                      ? '1 suggestion. Nothing changes unless you choose a '
                            'correction.'
                      : '$n suggestions. Nothing changes unless you choose a '
                            'correction.',
                  style: const TextStyle(color: Brand.muted, height: 1.35),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: n,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = widget.suggestions[i];
                return _SuggestionCard(
                  text: widget.text,
                  suggestion: s,
                  chosen: _chosen[s],
                  onChoose: (value) => setState(() {
                    if (value == null) {
                      _chosen.remove(s);
                    } else {
                      _chosen[s] = value;
                    }
                  }),
                );
              },
            ),
          ),
          Material(
            elevation: 8,
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldMessage(error),
                    if (error != null) const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCEL'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: count == 0 || error != null
                                ? null
                                : () => Navigator.pop(context, _result),
                            child: Text(
                              count == 0
                                  ? 'APPLY'
                                  : count == 1
                                  ? 'APPLY 1 CHANGE'
                                  : 'APPLY $count CHANGES',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Suggestions by LanguageTool. Your text is sent to '
                      'languagetool.org to be checked.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Brand.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.text,
    required this.suggestion,
    required this.chosen,
    required this.onChoose,
  });

  final String text;
  final GrammarSuggestion suggestion;
  final String? chosen;
  final ValueChanged<String?> onChoose;

  static String _label(String issueType) => switch (issueType) {
    'misspelling' => 'SPELLING',
    'grammar' => 'GRAMMAR',
    'typographical' => 'PUNCTUATION',
    'whitespace' => 'SPACING',
    _ => 'STYLE',
  };

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    // A little of the surrounding text, so the author sees where it is.
    final start = (s.offset - 32).clamp(0, text.length);
    final end = (s.end + 32).clamp(0, text.length);
    final before = '${start > 0 ? '…' : ''}${text.substring(start, s.offset)}';
    final after =
        '${text.substring(s.end, end)}${end < text.length ? '…' : ''}';
    final shown = chosen ?? s.replacements.first;
    final accepted = chosen != null;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accepted ? Brand.ok : const Color(0xFFE4E2DF),
          width: accepted ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F0EE),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _label(s.issueType),
                    style: Brand.heading(12.5, color: Brand.muted),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.message,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 15, height: 1.4),
                children: [
                  TextSpan(text: before),
                  TextSpan(
                    text: s.original,
                    style: const TextStyle(
                      color: Brand.error,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: shown,
                    style: TextStyle(
                      color: accepted ? Brand.ok : const Color(0xFF6E8F72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: after),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final r in s.replacements)
                  ChoiceChip(
                    label: Text(r.isEmpty ? '(remove)' : r),
                    selected: chosen == r,
                    onSelected: (on) => onChoose(on ? r : null),
                  ),
                ChoiceChip(
                  label: const Text('Keep as is'),
                  selected: chosen == null,
                  onSelected: (_) => onChoose(null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
