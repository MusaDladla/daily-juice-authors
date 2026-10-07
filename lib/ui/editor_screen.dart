import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/bible_reference.dart';
import '../core/grammar_check.dart';
import '../core/juice_date.dart';
import '../core/limit_formatter.dart';
import '../core/limits.dart';
import '../core/validation.dart';
import '../core/word_count.dart';
import '../models/daily_juice.dart';
import '../template/photo_crop.dart';
import '../template/template_layout.dart';
import '../template/template_spec.dart';
import 'result_screen.dart';
import 'theme.dart';
import 'widgets/focus_preview.dart';
import 'widgets/form_parts.dart';
import 'widgets/juice_preview.dart';
import 'widgets/page_editor.dart';
import 'widgets/grammar_sheet.dart';
import 'widgets/shorten_sheet.dart';

/// Write a Daily Juice, with the live template preview.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.initial, this.isNew = false});

  final DailyJuice initial;
  final bool isNew;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AppState _state;
  late DailyJuice _juice;
  late TemplateLayout _layout;
  ui.Image? _photo;
  bool _photoLoaded = false;

  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _scroll = ScrollController();

  final _title = TextEditingController();
  final _scripture = TextEditingController();
  final _reference = TextEditingController();
  final _message = TextEditingController();
  final List<TextEditingController> _refs = [];

  final _titleFocus = FocusNode();
  final _scriptureFocus = FocusNode();
  final _referenceFocus = FocusNode();
  final _messageFocus = FocusNode();
  final List<FocusNode> _refFocus = [];

  /// Transient "limit reached" notices, keyed by field.
  final Map<String, String> _notice = {};

  /// Issues shown after the author first tries to generate.
  bool _attempted = false;
  List<Issue> _issues = const [];

  /// Always-current issues, used for the section check marks.
  List<Issue> _liveIssues = const [];

  final Map<JuiceField, GlobalKey> _keys = {
    for (final f in JuiceField.values) f: GlobalKey(),
  };

  bool _showFocusPreview = true;
  bool _sheetOpen = false;

  /// The Main Message grammar check is running.
  bool _grammarBusy = false;

  /// Editing on the page in the LIVE PREVIEW, and the part being typed into
  /// (null while the author chooses one).
  bool _onPage = false;
  PagePart? _pagePart;

  // The page has its own fields (a focus node belongs to one field). They
  // share the form's controllers, so both always show the same text and
  // the same limits apply.
  final _pageTitleFocus = FocusNode();
  final _pageScriptureFocus = FocusNode();
  final _pageReferenceFocus = FocusNode();
  final _pageMessageFocus = FocusNode();
  final Map<TextEditingController, FocusNode> _pageRefFocus = {};

  Timer? _saveTimer;
  bool _savedOnce = false;
  bool _dirty = false;
  bool _deleted = false;
  String _saveStatus = '';

  @override
  void initState() {
    super.initState();
    _savedOnce = !widget.isNew;
    WidgetsBinding.instance.addObserver(this);
    _state = AppScope.read(context);
    final profile = _state.profile;
    _juice = profile == null
        ? widget.initial
        : widget.initial.withAuthor(profile);
    _layout = TemplateLayoutEngine.compute(_juice.toContent());

    _title.text = _juice.title;
    _scripture.text = _juice.themeScripture;
    _reference.text = _juice.scriptureReference;
    _message.text = _juice.mainMessage;
    final refs = _juice.furtherStudy.isEmpty ? [''] : _juice.furtherStudy;
    for (final r in refs.take(Limits.furtherStudyRefs)) {
      _addRefRow(r);
    }

    _title.addListener(
      () => _onText(
        'title',
        _title.text != _juice.title,
        () => _juice.copyWith(title: _title.text),
      ),
    );
    _scripture.addListener(
      () => _onText(
        'scripture',
        _scripture.text != _juice.themeScripture,
        () => _juice.copyWith(themeScripture: _scripture.text),
      ),
    );
    _reference.addListener(
      () => _onText(
        'reference',
        _reference.text != _juice.scriptureReference,
        () => _juice.copyWith(scriptureReference: _reference.text),
      ),
    );
    _message.addListener(
      () => _onText(
        'message',
        _message.text != _juice.mainMessage,
        () => _juice.copyWith(mainMessage: _message.text),
      ),
    );

    for (final f in [
      _titleFocus,
      _scriptureFocus,
      _referenceFocus,
      _messageFocus,
    ]) {
      f.addListener(_onFocusChange);
    }
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {
        // Back on WRITE, editing on the page ends.
        if (_tabs.index == 0) {
          _onPage = false;
          _pagePart = null;
        }
      });
    });

    _liveIssues = _validate();
    _state.image(_juice.profileImagePath).then((img) {
      if (!mounted) return;
      setState(() {
        _photo = img;
        _photoLoaded = true;
        _liveIssues = _validate();
      });
    });
  }

  /// Write-and-come-back-later: save the moment the app is left.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _saveNow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    if (!_deleted) _saveNow();
    _tabs.dispose();
    _scroll.dispose();
    for (final c in [_title, _scripture, _reference, _message, ..._refs]) {
      c.dispose();
    }
    for (final f in [
      _titleFocus,
      _scriptureFocus,
      _referenceFocus,
      _messageFocus,
      ..._refFocus,
      _pageTitleFocus,
      _pageScriptureFocus,
      _pageReferenceFocus,
      _pageMessageFocus,
      ..._pageRefFocus.values,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------- updates --

  List<String> get _refTexts => [for (final c in _refs) c.text];

  void _onText(String key, bool changed, DailyJuice Function() next) {
    if (!changed) return; // selection-only change
    _notice.remove(key);
    _apply(next());
  }

  void _apply(DailyJuice next) {
    setState(() {
      _juice = next.copyWith(
        status: JuiceStatus.draft,
        updatedAt: DateTime.now(),
      );
      _layout = TemplateLayoutEngine.compute(_juice.toContent());
      _liveIssues = _validate();
      if (_attempted) _issues = _liveIssues;
      _saveStatus = '';
    });
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _saveNow);
  }

  void _syncRefs() => _apply(_juice.copyWith(furtherStudy: _refTexts));

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    if (_deleted || !_dirty || (!_savedOnce && !_juice.hasContent)) return;
    _dirty = false;
    _savedOnce = true;
    final juice = _juice;
    await _state.saveJuice(juice);
    if (mounted && identical(juice, _juice)) {
      setState(() => _saveStatus = 'Draft saved');
    }
  }

  List<Issue> _validate() => Validation.forGeneration(
    juice: _juice,
    layout: _layout,
    hasPhoto: _photo != null || !_photoLoaded,
  );

  bool _complete(List<JuiceField> fields) =>
      !_liveIssues.any((i) => fields.contains(i.field));

  // ---------------------------------------------------------- limit rules --

  void _reject(String key, String message, bool pasted, String attempted) {
    HapticFeedback.mediumImpact();
    scheduleMicrotask(() async {
      if (!mounted) return;
      final controller = switch (key) {
        'title' => _title,
        'scripture' => _scripture,
        'message' => _message,
        _ => null,
      };
      if (!pasted || controller == null || _sheetOpen) {
        setState(
          () => _notice[key] = pasted
              ? '$message The pasted text was not added.'
              : message,
        );
        return;
      }
      // Pasted text that is too long: let the author shorten it themselves.
      _sheetOpen = true;
      final result = await showShortenSheet(
        context,
        fieldName: switch (key) {
          'title' => 'title',
          'scripture' => 'Theme Scripture',
          _ => 'message',
        },
        text: attempted,
        limit: switch (key) {
          'title' => Limits.titleWords,
          'scripture' => Limits.scriptureWords,
          _ => Limits.messageWords,
        },
        count: countWords,
        check: switch (key) {
          'title' => _checkTitle,
          'scripture' => _checkScripture,
          _ => _checkMessage,
        },
        multiline: key != 'title',
      );
      _sheetOpen = false;
      if (!mounted) return;
      if (result != null) {
        controller.value = TextEditingValue(
          text: result,
          selection: TextSelection.collapsed(offset: result.length),
        );
      } else {
        setState(
          () => _notice[key] = '$message The pasted text was not added.',
        );
      }
    });
  }

  LimitFormatter _guard(String key, String? Function(String) check) =>
      LimitFormatter(
        check: check,
        onRejected: (m, pasted, attempted) =>
            _reject(key, m, pasted, attempted),
      );

  TemplateLayout _layoutWith(DailyJuice j) =>
      TemplateLayoutEngine.compute(j.toContent());

  String? _checkTitle(String text) {
    if (countWords(text) > Limits.titleWords) return Msg.titleWords;
    if (text.length > Limits.titleChars) return Msg.titleChars;
    if (!TemplateLayoutEngine.titleFits(text)) return Msg.titleWidth;
    return null;
  }

  String? _checkScripture(String text) {
    if (countWords(text) > Limits.scriptureWords) return Msg.scriptureWords;
    final layout = _layoutWith(_juice.copyWith(themeScripture: text));
    if (Validation.messageFit(countWords(_juice.mainMessage), layout) != null) {
      return Msg.pageFullScripture;
    }
    return null;
  }

  String? _checkReference(String text) =>
      text.length > Limits.scriptureReferenceChars
      ? Msg.scriptureReferenceChars
      : null;

  String? _checkMessage(String text) => Validation.messageFit(
    countWords(text),
    _layoutWith(_juice.copyWith(mainMessage: text)),
  );

  String? _checkRef(int index, String text) {
    if (text.length > Limits.furtherStudyRefChars) return Msg.furtherStudyChars;
    if (countWords(text) > Limits.furtherStudyRefWords) {
      return Msg.furtherStudyRefOnly;
    }
    final refs = _refTexts..[index] = text;
    if (!TemplateLayoutEngine.furtherStudyFits(refs)) {
      return Msg.furtherStudyWidth;
    }
    return null;
  }

  // ------------------------------------------------------- further study --

  void _addRefRow(String text) {
    final controller = TextEditingController(text: text);
    final focus = FocusNode();
    controller.addListener(() {
      final i = _refs.indexOf(controller);
      if (i < 0 ||
          i >= _juice.furtherStudy.length ||
          _juice.furtherStudy[i] != controller.text) {
        _notice.remove('refs');
        _syncRefs();
      }
    });
    focus.addListener(_onFocusChange);
    _refs.add(controller);
    _refFocus.add(focus);
  }

  void _onAddReference({bool onPage = false}) {
    if (_refs.length >= Limits.furtherStudyRefs) {
      HapticFeedback.mediumImpact();
      setState(() => _notice['refs'] = Msg.furtherStudyMax);
      return;
    }
    setState(() => _addRefRow(''));
    _syncRefs();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => (onPage ? _pageRefFocusOf(_refs.last) : _refFocus.last)
          .requestFocus(),
    );
  }

  void _removeReference(int i) {
    if (_refs.length == 1) {
      _refs.first.clear();
      return;
    }
    final pageFocus = _pageRefFocus.remove(_refs[i]);
    if (pageFocus != null) {
      // Its field stays on screen until the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => pageFocus.dispose());
    }
    setState(() {
      _notice.remove('refs');
      _refs.removeAt(i).dispose();
      _refFocus.removeAt(i).dispose();
    });
    _syncRefs();
  }

  // ---------------------------------------------------------------- date --

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _juice.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'DATE OF THIS DAILY JUICE',
    );
    if (picked != null) _apply(_juice.copyWith(date: dateOnly(picked)));
  }

  // -------------------------------------------------------------- delete --

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this Daily Juice?'),
        content: const Text('It will be permanently deleted from this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Brand.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _deleted = true;
    _saveTimer?.cancel();
    if (_savedOnce) await _state.deleteJuice(_juice);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Daily Juice deleted.')));
  }

  // ------------------------------------------------------------ generate --

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    final issues = _validate();
    setState(() {
      _attempted = true;
      _issues = issues;
      _liveIssues = issues;
    });
    if (issues.isNotEmpty) {
      _tabs.animateTo(0);
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            issues.length == 1
                ? 'Please correct 1 item before generating.'
                : 'Please correct ${issues.length} items before generating.',
          ),
        ),
      );
      return;
    }
    _saveTimer?.cancel();
    final now = DateTime.now();
    final done = _juice.copyWith(
      status: JuiceStatus.generated,
      generatedAt: now,
      updatedAt: now,
    );
    _juice = done;
    _dirty = false;
    _savedOnce = true;
    await _state.saveJuice(done);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultScreen(juiceId: done.id)),
    );
  }

  String? _issueFor(JuiceField f, {bool Function(String)? where}) {
    final list = _issues
        .where((i) => i.field == f && (where == null || where(i.message)))
        .map((i) => i.message);
    return list.isEmpty ? null : list.join('\n');
  }

  void _goTo(JuiceField f) {
    final ctx = _keys[f]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
  }

  // ------------------------------------------------------- live preview --

  PreviewFocus? get _focusArea {
    if (_titleFocus.hasFocus) return PreviewFocus.header;
    if (_scriptureFocus.hasFocus || _referenceFocus.hasFocus) {
      return PreviewFocus.scripture;
    }
    if (_messageFocus.hasFocus) return PreviewFocus.message;
    if (_refFocus.any((f) => f.hasFocus)) return PreviewFocus.furtherStudy;
    return null;
  }

  // -------------------------------------------------------- grammar --

  /// Grammar check for the Main Message only: LanguageTool suggests, the
  /// author chooses what to accept. The Title and Theme Scripture are never
  /// checked (Scripture must stay exactly as typed).
  Future<void> _checkGrammar() async {
    final text = _message.text;
    final messenger = ScaffoldMessenger.of(context);
    if (text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Write your message first.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _grammarBusy = true);
    List<GrammarSuggestion> suggestions;
    try {
      suggestions = await GrammarChecker.instance.check(text);
    } on GrammarCheckException catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    } finally {
      if (mounted) setState(() => _grammarBusy = false);
    }
    if (!mounted) return;
    if (_message.text != text) return; // changed while checking
    if (suggestions.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No spelling or grammar suggestions.')),
      );
      return;
    }
    final result = await showGrammarSheet(
      context,
      fieldName: 'Main Message',
      text: text,
      suggestions: suggestions,
      check: _checkMessage,
    );
    if (!mounted || result == null || result == text) return;
    _message.value = TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Corrections applied.')),
    );
  }

  Widget _grammarButton() => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      onPressed: _grammarBusy ? null : _checkGrammar,
      icon: _grammarBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.spellcheck, size: 20),
      label: Text(
        _grammarBusy ? 'CHECKING…' : 'CHECK GRAMMAR',
        style: Brand.heading(15, color: SectionStyle.message.color),
      ),
    ),
  );

  void _openFullPreview() {
    FocusScope.of(context).unfocus();
    _tabs.animateTo(1);
  }

  // -------------------------------------------------- edit on the page --

  void _startPageEditing() => setState(() {
    _onPage = true;
    _pagePart = null;
  });

  void _stopPageEditing() {
    FocusScope.of(context).unfocus();
    setState(() {
      _onPage = false;
      _pagePart = null;
    });
  }

  void _onPageTap(PagePart part) {
    switch (part) {
      case PagePart.photo:
      case PagePart.author:
        final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              part == PagePart.photo
                  ? 'Your photo comes from your profile. Change it there.'
                  : 'Your name comes from your profile. Change it there.',
            ),
          ),
        );
      case PagePart.date:
        _pickDate();
      default:
        _editOnPage(part);
    }
  }

  void _editOnPage(PagePart part) {
    setState(() => _pagePart = part);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pagePart == part) _pageFocusOf(part).requestFocus();
    });
  }

  FocusNode _pageRefFocusOf(TextEditingController c) =>
      _pageRefFocus.putIfAbsent(c, FocusNode.new);

  FocusNode _pageFocusOf(PagePart part) => switch (part) {
    PagePart.title => _pageTitleFocus,
    PagePart.scripture => _pageScriptureFocus,
    PagePart.reference => _pageReferenceFocus,
    PagePart.message => _pageMessageFocus,
    _ => _pageRefFocusOf(
      _refs.firstWhere((c) => c.text.trim().isEmpty, orElse: () => _refs.last),
    ),
  };

  /// Moves to the previous or next part, in page order.
  void _pageStep(int by) {
    final i = PagePart.editable.indexOf(_pagePart!) + by;
    if (i < 0 || i >= PagePart.editable.length) return _pageDone();
    _editOnPage(PagePart.editable[i]);
  }

  void _pageDone() {
    FocusScope.of(context).unfocus();
    setState(() => _pagePart = null);
  }

  Widget _pagePane() => ColoredBox(
    color: const Color(0xFFE2E0DC),
    child: Column(
      children: [
        if (_pagePart == null) _pageHint() else _pageBar(),
        Expanded(
          child: ClipRect(
            // Template lettering keeps its size whatever the phone's text size.
            child: MediaQuery.withNoTextScaling(
              child: PageEditorView(
                layout: _layout,
                photo: _photo,
                crop: _juice.profileImageCrop,
                part: _pagePart,
                onTap: _onPageTap,
                editors: _pageEditors,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _pageHint() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    child: Material(
      color: Brand.charcoal,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Tap the part of the page you want to change.',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _stopPageEditing,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Brand.charcoal,
              ),
              child: const Text('DONE EDITING'),
            ),
          ],
        ),
      ),
    ),
  );

  /// Name of the part, its limit, ‹ › and DONE, and any limit message.
  Widget _pageBar() {
    final part = _pagePart!;
    final i = PagePart.editable.indexOf(part);
    final (count, limit, unit, notice) = switch (part) {
      PagePart.title => (
        countWords(_title.text),
        Limits.titleWords,
        'words',
        'title',
      ),
      PagePart.scripture => (
        countWords(_scripture.text),
        Limits.scriptureWords,
        'words',
        'scripture',
      ),
      PagePart.reference => (
        _reference.text.length,
        Limits.scriptureReferenceChars,
        'characters',
        'reference',
      ),
      PagePart.message => (
        countWords(_message.text),
        Limits.messageWords,
        'words',
        'message',
      ),
      _ => (
        _refTexts.where((r) => r.trim().isNotEmpty).length,
        Limits.furtherStudyRefs,
        'references',
        'refs',
      ),
    };
    return Material(
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: SectionStyle.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        part.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Brand.heading(15, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Previous part',
                  onPressed: i > 0 ? () => _pageStep(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next part',
                  onPressed: i < PagePart.editable.length - 1
                      ? () => _pageStep(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 4),
                FilledButton(onPressed: _pageDone, child: const Text('DONE')),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: LimitCounter(
                count: count,
                limit: limit,
                unit: unit,
                color: SectionStyle.accent,
              ),
            ),
            FieldMessage(_notice[notice], isError: false),
            if (part == PagePart.scripture || part == PagePart.message) ...[
              const SizedBox(height: 10),
              _PageSpaceMeter(layout: _layout),
            ],
          ],
        ),
      ),
    );
  }

  /// The fields of the part being edited, placed where its text is printed.
  List<Widget> _pageEditors(double scale) {
    final part = _pagePart;
    if (part == null) return const [];
    final pad = PageInput.padding(scale);
    switch (part) {
      case PagePart.title:
        return [
          Positioned.fromRect(
            rect: TemplateSpec.titleBox,
            child: Center(
              child: PageInput(
                controller: _title,
                focusNode: _pageTitleFocus,
                style: TemplateSpec.titleStyle,
                pitch: TemplateSpec.titleLinePitch,
                // Wraps where the page moves a title to two lines.
                width:
                    TemplateSpec.titleSingleLineMax +
                    TemplateSpec.titleStyle.letterSpacing! +
                    4,
                scale: scale,
                capitals: true,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _pageStep(1),
                inputFormatters: [_guard('title', _checkTitle)],
                hintText: 'e.g. LET GO AND LET GOD',
              ),
            ),
          ),
        ];
      case PagePart.scripture:
        return [
          Positioned(
            left:
                TemplateSpec.centerX -
                TemplateSpec.scriptureMaxWidth / 2 -
                2 -
                pad,
            top: PageInput.topFor(
              TemplateSpec.scriptureStyle,
              TemplateSpec.scriptureLinePitch,
              TemplateSpec.scriptureFirstBaseline,
              scale,
            ),
            child: PageInput(
              controller: _scripture,
              focusNode: _pageScriptureFocus,
              style: TemplateSpec.scriptureStyle,
              pitch: TemplateSpec.scriptureLinePitch,
              width: TemplateSpec.scriptureMaxWidth + 4,
              scale: scale,
              multiline: true,
              minLines: 2,
              inputFormatters: [_guard('scripture', _checkScripture)],
              hintText: '“So David went to Baal Perazim…”',
            ),
          ),
        ];
      case PagePart.reference:
        const pitch = 112.0;
        return [
          Positioned(
            left:
                TemplateSpec.centerX -
                TemplateSpec.scriptureMaxWidth / 2 -
                2 -
                pad,
            top: PageInput.topFor(
              TemplateSpec.referenceStyle,
              pitch,
              PageGeometry.referenceBaseline(_layout),
              scale,
            ),
            child: PageInput(
              controller: _reference,
              focusNode: _pageReferenceFocus,
              style: TemplateSpec.referenceStyle,
              pitch: pitch,
              width: TemplateSpec.scriptureMaxWidth + 4,
              scale: scale,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _pageStep(1),
              inputFormatters: [_guard('reference', _checkReference)],
              hintText: 'e.g. 2 Samuel 5:20',
            ),
          ),
        ];
      case PagePart.message:
        return [
          Positioned(
            left: TemplateSpec.bodyLeft - 1 - pad,
            top: PageInput.topFor(
              TemplateSpec.bodyStyle,
              TemplateSpec.bodyLinePitch,
              PageGeometry.messageBaseline(_layout),
              scale,
            ),
            child: PageInput(
              controller: _message,
              focusNode: _pageMessageFocus,
              style: TemplateSpec.bodyStyle,
              pitch: TemplateSpec.bodyLinePitch,
              width: TemplateSpec.bodyRight - TemplateSpec.bodyLeft + 2,
              scale: scale,
              textAlign: TextAlign.justify,
              multiline: true,
              minLines: 4,
              inputFormatters: [_guard('message', _checkMessage)],
              hintText: 'Write your Daily Juice…',
            ),
          ),
        ];
      default:
        return [_pageFurtherStudy(scale)];
    }
  }

  Widget _pageFurtherStudy(double scale) {
    const style = TemplateSpec.furtherStudyStyle;
    const pitch = 96.0;
    final full = _refs.length >= Limits.furtherStudyRefs;
    Widget round(Widget child, VoidCallback onTap, {double? width}) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            height: 22 / scale,
            margin: EdgeInsets.symmetric(horizontal: 5 / scale),
            padding: width == null
                ? EdgeInsets.symmetric(horizontal: 9 / scale)
                : EdgeInsets.zero,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: full && width == null
                  ? const Color(0xFFA9A7A2)
                  : Brand.charcoal,
              borderRadius: BorderRadius.circular(11 / scale),
            ),
            child: child,
          ),
        );
    return Positioned(
      left: TemplateSpec.dividerLeft,
      width: TemplateSpec.dividerRight - TemplateSpec.dividerLeft,
      top: PageInput.topFor(
        style,
        pitch,
        TemplateSpec.furtherStudyBaseline,
        scale,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _refs.length; i++) ...[
              if (i > 0) const Text(';', style: style),
              PageInput(
                controller: _refs[i],
                focusNode: _pageRefFocusOf(_refs[i]),
                style: style,
                pitch: pitch,
                width: math.max(
                  PageInput.fieldWidth(
                    style,
                    _refs[i].text.isEmpty
                        ? 'e.g. Isaiah 28:21'
                        : _refs[i].text.toUpperCase(),
                    scale,
                  ),
                  240,
                ),
                scale: scale,
                capitals: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onSubmitted: (v) {
                  final last = i == _refs.length - 1;
                  if (last && !full && v.trim().isNotEmpty) {
                    _onAddReference(onPage: true);
                  } else if (!last) {
                    _pageRefFocusOf(_refs[i + 1]).requestFocus();
                  } else {
                    _pageDone();
                  }
                },
                inputFormatters: [_guard('refs', (t) => _checkRef(i, t))],
                hintText: i == 0
                    ? 'e.g. 1 Chronicles 14:11'
                    : 'e.g. Isaiah 28:21',
              ),
              Semantics(
                button: true,
                label: 'Remove reference ${i + 1}',
                child: round(
                  Icon(Icons.close, size: 14 / scale, color: Colors.white),
                  () => _removeReference(i),
                  width: 22 / scale,
                ),
              ),
            ],
            Semantics(
              button: true,
              label: 'Add reference',
              child: round(
                Text(
                  '+ ADD',
                  style: Brand.heading(12 / scale, color: Colors.white),
                ),
                () => _onAddReference(onPage: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ UI --

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final preview = _onPage
        ? _pagePane()
        : _PreviewPane(
            layout: _layout,
            photo: _photo,
            crop: _juice.profileImageCrop,
            loading: !_photoLoaded,
            onEditHere: _startPageEditing,
          );
    final onPreviewTab = !wide && _tabs.index == 1;

    return PopScope(
      canPop: !onPreviewTab && !_onPage,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Back steps out of editing on the page first.
          if (_pagePart != null) return _pageDone();
          if (_onPage) return _stopPageEditing();
          _tabs.animateTo(0); // Back from the preview returns to writing.
          return;
        }
        _saveNow();
        if (_savedOnce && !_deleted && _juice.status == JuiceStatus.draft) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Saved in My Daily Juices as a draft.'),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? 'NEW DAILY JUICE' : 'EDIT DAILY JUICE'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'preview') _openFullPreview();
                if (v == 'delete') _delete();
              },
              itemBuilder: (_) => [
                if (!wide)
                  const PopupMenuItem(
                    value: 'preview',
                    child: Text('Full-page preview'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete this Daily Juice'),
                ),
              ],
            ),
          ],
          bottom: wide
              ? null
              : TabBar(
                  controller: _tabs,
                  labelStyle: Brand.heading(17),
                  indicatorColor: Brand.charcoal,
                  labelColor: Brand.ink,
                  tabs: const [
                    Tab(text: 'WRITE'),
                    Tab(text: 'LIVE PREVIEW'),
                  ],
                ),
        ),
        body: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _form()),
                  Expanded(flex: 4, child: preview),
                ],
              )
            : TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [_writeTab(keyboardOpen), preview],
              ),
        // While typing, the keyboard needs the room; generate afterwards.
        bottomNavigationBar: keyboardOpen ? null : _generateBar(),
      ),
    );
  }

  Widget _writeTab(bool keyboardOpen) {
    final area = _focusArea;
    final showArea = keyboardOpen && area != null;
    return Column(
      children: [
        if (showArea && _showFocusPreview)
          FocusPreview(
            layout: _layout,
            photo: _photo,
            crop: _juice.profileImageCrop,
            focus: area,
            onOpenFullPreview: _openFullPreview,
            onHide: () => setState(() => _showFocusPreview = false),
          )
        else if (showArea)
          Material(
            color: const Color(0xFFE2E0DC),
            child: InkWell(
              onTap: () => setState(() => _showFocusPreview = true),
              child: const SizedBox(
                height: 30,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.expand_more, size: 18, color: Brand.muted),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Show live preview while typing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Brand.muted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: _form()),
      ],
    );
  }

  Widget _generateBar() {
    final total = Validation.sections.length;
    final done = Validation.sectionsComplete(_liveIssues);
    final profileOk = _complete([
      JuiceField.profileImage,
      JuiceField.name,
      JuiceField.surname,
      JuiceField.branch,
    ]);
    final ready = done == total && profileOk;
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    _ProgressDots(
                      complete: [
                        for (final fields in Validation.sections)
                          _complete(fields),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ready
                            ? 'Ready to generate'
                            : '$done of $total sections complete',
                        style: TextStyle(
                          color: ready ? Brand.ok : Brand.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_saveStatus.isNotEmpty)
                      Text(
                        _saveStatus,
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('GENERATE DAILY JUICE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() => ListView(
    controller: _scroll,
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      if (_issues.isNotEmpty) ...[_issueSummary(), const SizedBox(height: 14)],
      _authorCard(),
      const SizedBox(height: 14),
      _titleSection(),
      const SizedBox(height: 14),
      _dateSection(),
      const SizedBox(height: 14),
      _scriptureSection(),
      const SizedBox(height: 14),
      _messageSection(),
      const SizedBox(height: 14),
      _furtherStudySection(),
    ],
  );

  Widget _issueSummary() => Card(
    color: const Color(0xFFFEF3F2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFFDA29B)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLEASE CORRECT BEFORE GENERATING',
            style: Brand.heading(18, color: Brand.error),
          ),
          const SizedBox(height: 6),
          for (final issue in _issues)
            InkWell(
              onTap: () => _goTo(issue.field),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(color: Brand.error)),
                    Expanded(
                      child: Text(
                        issue.message,
                        style: const TextStyle(
                          color: Brand.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _authorCard() {
    final photoIssue = _issueFor(JuiceField.profileImage);
    final profileIssue = [
      _issueFor(JuiceField.name),
      _issueFor(JuiceField.surname),
      _issueFor(JuiceField.branch),
    ].whereType<String>().join('\n');
    return Container(
      key: _keys[JuiceField.profileImage],
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Brand.stripe,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TemplateLayoutEngine.authorLine(_juice.authorFullName),
            style: Brand.heading(19),
          ),
          FieldMessage(photoIssue),
          FieldMessage(profileIssue.isEmpty ? null : profileIssue),
        ],
      ),
    );
  }

  Widget _titleSection() => SectionCard(
    key: _keys[JuiceField.title],
    title: 'Title',
    section: SectionStyle.title,
    complete: _complete([JuiceField.title]),
    trailing: LimitCounter(
      count: countWords(_title.text),
      limit: Limits.titleWords,
      color: SectionStyle.title.color,
      unit: 'words',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          focusNode: _titleFocus,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          style: Brand.heading(22),
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
            _guard('title', _checkTitle),
          ],
          decoration: InputDecoration(
            hintText: 'e.g. LET GO AND LET GOD',
            // Faint, so the example never looks like real content.
            hintStyle: Brand.heading(
              22,
              color: Brand.ink.withValues(alpha: 0.22),
            ),
          ),
        ),
        FieldMessage(_notice['title'], isError: false),
        FieldMessage(_issueFor(JuiceField.title)),
      ],
    ),
  );

  Widget _dateSection() {
    final sameDay = _state.juices
        .where((j) => j.id != _juice.id && j.date == _juice.date)
        .toList();
    return SectionCard(
      key: _keys[JuiceField.date],
      title: 'Date',
      section: SectionStyle.date,
      complete: _complete([JuiceField.date]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              child: Text(
                friendlyDate(_juice.date),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          FieldMessage(
            sameDay.isEmpty
                ? null
                : 'You already have a Daily Juice for this date'
                      '${sameDay.first.title.trim().isEmpty ? '' : ': “${sameDay.first.title.trim().toUpperCase()}”'}.',
            isError: false,
          ),
          FieldMessage(_issueFor(JuiceField.date)),
        ],
      ),
    );
  }

  String? _referenceError() {
    final issue = _issueFor(JuiceField.scriptureReference);
    if (issue != null) return issue;
    final text = _reference.text.trim();
    if (_referenceFocus.hasFocus || text.isEmpty) return null;
    final bare = text.replaceAll(RegExp(r'^\(|\)$'), '');
    return isBibleReference(bare) ? null : Msg.scriptureReferenceInvalid;
  }

  Widget _scriptureSection() => SectionCard(
    key: _keys[JuiceField.scripture],
    title: 'Theme Scripture',
    section: SectionStyle.scripture,
    complete: _complete([JuiceField.scripture, JuiceField.scriptureReference]),
    trailing: LimitCounter(
      count: countWords(_scripture.text),
      limit: Limits.scriptureWords,
      color: SectionStyle.scripture.color,
      unit: 'words',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _scripture,
          focusNode: _scriptureFocus,
          minLines: 3,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [_guard('scripture', _checkScripture)],
          decoration: const InputDecoration(
            hintText:
                '“So David went to Baal Perazim, and David defeated '
                'them there…”',
          ),
        ),
        FieldMessage(_notice['scripture'], isError: false),
        FieldMessage(_issueFor(JuiceField.scripture)),
        const SizedBox(height: 12),
        TextField(
          key: _keys[JuiceField.scriptureReference],
          controller: _reference,
          focusNode: _referenceFocus,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
            _guard('reference', _checkReference),
          ],
          decoration: InputDecoration(
            labelText: 'Bible reference',
            hintText: 'e.g. 2 Samuel 5:20',
            errorText: _referenceError(),
            errorMaxLines: 3,
          ),
        ),
        FieldMessage(_notice['reference'], isError: false),
      ],
    ),
  );

  Widget _messageSection() => SectionCard(
    key: _keys[JuiceField.message],
    title: 'Main Message',
    section: SectionStyle.message,
    complete: _complete([JuiceField.message]),
    trailing: LimitCounter(
      count: countWords(_message.text),
      limit: Limits.messageWords,
      color: SectionStyle.message.color,
      unit: 'words',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _message,
          focusNode: _messageFocus,
          minLines: 8,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [_guard('message', _checkMessage)],
          decoration: const InputDecoration(
            hintText: 'Write your Daily Juice…',
          ),
        ),
        _grammarButton(),
        FieldMessage(_notice['message'], isError: false),
        FieldMessage(_issueFor(JuiceField.message)),
        const SizedBox(height: 12),
        _PageSpaceMeter(layout: _layout),
      ],
    ),
  );

  Widget _furtherStudySection() {
    final filled = _refTexts.where((r) => r.trim().isNotEmpty).length;
    final full = _refs.length >= Limits.furtherStudyRefs;
    return SectionCard(
      key: _keys[JuiceField.furtherStudy],
      title: 'Further Study',
      section: SectionStyle.furtherStudy,
      complete: _complete([JuiceField.furtherStudy]),
      trailing: LimitCounter(
        count: filled,
        limit: Limits.furtherStudyRefs,
        color: SectionStyle.furtherStudy.color,
        unit: 'references',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _refs.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _refs[i],
                    focusNode: _refFocus[i],
                    textCapitalization: TextCapitalization.words,
                    textInputAction: i == _refs.length - 1 && full
                        ? TextInputAction.done
                        : TextInputAction.next,
                    // Enter on the last reference starts the next one.
                    onSubmitted: i == _refs.length - 1 && !full
                        ? (v) {
                            if (v.trim().isNotEmpty) _onAddReference();
                          }
                        : null,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
                      _guard('refs', (t) => _checkRef(i, t)),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Reference ${i + 1}',
                      hintText: i == 0
                          ? 'e.g. 1 Chronicles 14:11'
                          : 'e.g. Isaiah 28:21',
                      errorText: _refFocus[i].hasFocus && !_attempted
                          ? null
                          : Validation.furtherStudyEntry(_refs[i].text),
                      errorMaxLines: 3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove reference',
                  padding: const EdgeInsets.only(top: 8),
                  onPressed: () => _removeReference(i),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // A disabled button ignores taps, so the wrapper explains why.
          GestureDetector(
            onTap: full ? _onAddReference : null,
            child: OutlinedButton.icon(
              onPressed: full ? null : _onAddReference,
              icon: const Icon(Icons.add),
              label: const Text('ADD REFERENCE'),
            ),
          ),
          FieldMessage(_notice['refs'], isError: false),
          // Per-entry problems are shown on the entry itself.
          FieldMessage(
            _issueFor(
              JuiceField.furtherStudy,
              where: (m) => !m.startsWith('“'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One dot per section, in its colour, filled once the section is done.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.complete});

  final List<bool> complete;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < SectionStyle.all.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: complete[i] ? SectionStyle.all[i].color : Colors.white,
              border: Border.all(
                color: SectionStyle.all[i].color.withValues(
                  alpha: complete[i] ? 1 : 0.45,
                ),
                width: 1.6,
              ),
            ),
            child: complete[i]
                ? const Icon(Icons.check, size: 11, color: Colors.white)
                : null,
          ),
        ),
    ],
  );
}

class _PageSpaceMeter extends StatelessWidget {
  const _PageSpaceMeter({required this.layout});

  final TemplateLayout layout;

  @override
  Widget build(BuildContext context) {
    final usage = layout.pageUsage;
    final percent = (math.min(usage, 1.0) * 100).round();
    final String label;
    if (!layout.bodyFits) {
      label = 'The page is full.';
    } else if (layout.spacingTightened) {
      label =
          'Page space: full — paragraph spacing is slightly reduced so '
          'everything fits.';
    } else {
      label = 'Page space used: $percent%';
    }
    final color = !layout.bodyFits
        ? Brand.error
        : (usage >= 0.9 ? Brand.warning : Brand.ok);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: math.min(usage, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: const Color(0xFFE9E7E4),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({
    required this.layout,
    required this.photo,
    required this.crop,
    required this.loading,
    required this.onEditHere,
  });

  final TemplateLayout layout;
  final ui.Image? photo;
  final PhotoCrop crop;
  final bool loading;

  /// Starts editing on the page.
  final VoidCallback onEditHere;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFE2E0DC),
    child: Stack(
      children: [
        Positioned.fill(
          child: ZoomablePreview(
            child: JuicePreview(layout: layout, photo: photo, crop: crop),
          ),
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: null,
            onPressed: onEditHere,
            backgroundColor: Brand.charcoal,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.edit_outlined),
            label: Text(
              'EDIT HERE',
              style: Brand.heading(18, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}
