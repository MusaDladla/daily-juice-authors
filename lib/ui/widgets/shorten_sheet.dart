import 'package:flutter/material.dart';

import '../theme.dart';
import 'form_parts.dart';

/// Shown when pasted text is over a limit. Nothing is cut automatically:
/// the author edits the text here, and it is only inserted once it fits.
Future<String?> showShortenSheet(
  BuildContext context, {
  required String fieldName,
  required String text,
  required int limit,
  required int Function(String) count,
  required String? Function(String) check,
  bool multiline = true,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _ShortenSheet(
    fieldName: fieldName,
    text: text,
    limit: limit,
    count: count,
    check: check,
    multiline: multiline,
  ),
);

class _ShortenSheet extends StatefulWidget {
  const _ShortenSheet({
    required this.fieldName,
    required this.text,
    required this.limit,
    required this.count,
    required this.check,
    required this.multiline,
  });

  final String fieldName;
  final String text;
  final int limit;
  final int Function(String) count;
  final String? Function(String) check;
  final bool multiline;

  @override
  State<_ShortenSheet> createState() => _ShortenSheetState();
}

class _ShortenSheetState extends State<_ShortenSheet> {
  late final _controller = TextEditingController(text: widget.text);
  late final int _initialCount = widget.count(widget.text);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.count(_controller.text);
    final error = widget.check(_controller.text);
    final over = _initialCount - widget.limit;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SHORTEN ${widget.fieldName.toUpperCase()}',
                  style: Brand.heading(21),
                ),
              ),
              LimitCounter(count: words, limit: widget.limit, unit: 'words'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            over > 0
                ? 'The pasted text makes $_initialCount words — $over over the '
                      'limit of ${widget.limit}. Edit it here; nothing is '
                      'removed for you, and it is only added once it fits.'
                : 'The pasted text does not fit the Daily Juice page. Edit it '
                      'here; nothing is removed for you, and it is only added '
                      'once it fits.',
            style: const TextStyle(color: Brand.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: TextField(
              controller: _controller,
              autofocus: true,
              minLines: widget.multiline ? 6 : 1,
              maxLines: widget.multiline ? 14 : 1,
              keyboardType: widget.multiline
                  ? TextInputType.multiline
                  : TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          FieldMessage(error, isError: false),
          const SizedBox(height: 12),
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
                  onPressed: error == null
                      ? () => Navigator.pop(context, _controller.text)
                      : null,
                  child: const Text('USE THIS TEXT'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
