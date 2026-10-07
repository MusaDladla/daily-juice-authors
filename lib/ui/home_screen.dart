import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../core/app_update.dart';
import '../core/juice_date.dart';
import '../core/juice_search.dart';
import '../data/juice_repository.dart';
import '../models/daily_juice.dart';
import '../models/profile.dart';
import 'editor_screen.dart';
import 'profile_screen.dart';
import 'result_screen.dart';
import 'theme.dart';
import 'widgets/brand.dart';
import 'widgets/photo_framer.dart';
import 'widgets/stored_image.dart';

enum _Filter { all, drafts, generated }

const _monthNames = [
  'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', //
  'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
];

/// The author's dashboard: start a new Daily Juice, and find any Daily
/// Juice (drafts to continue, or generated ones) by title or date.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.checkForUpdate = AppUpdate.checkOnAndroid});

  /// Looks for a newer version of the app (Android only).
  final Future<AppUpdate?> Function() checkForUpdate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  DateTime? _dateFilter;

  /// A newer version to offer, until the author taps LATER.
  AppUpdate? _update;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    widget.checkForUpdate().then((update) {
      if (mounted && update != null) setState(() => _update = update);
    });
  }

  Future<void> _downloadUpdate(AppUpdate update) async {
    final opened = await launchUrl(
      update.downloadUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The download could not be opened. Try again later.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _create() {
    final state = AppScope.read(context);
    final juice = DailyJuice.create(
      id: JuiceRepository.newId(),
      profile: state.profile!,
      date: DateTime.now(),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(initial: juice, isNew: true),
      ),
    );
  }

  void _openProfile() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));

  Future<void> _pickDateFilter(List<DailyJuice> juices) async {
    final days = juices.map((j) => j.date).toSet();
    final initial = _dateFilter ?? juices.first.date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'SHOW DAILY JUICES FOR',
      // Only days that have a Daily Juice can be chosen.
      selectableDayPredicate: (d) => days.contains(dateOnly(d)),
    );
    if (picked != null) setState(() => _dateFilter = dateOnly(picked));
  }

  void _clearSearch() {
    _search.clear();
    setState(() {
      _dateFilter = null;
      _filter = _Filter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile!;
    final juices = state.juices;
    final results = juices.where((j) {
      if (_filter == _Filter.generated && j.status != JuiceStatus.generated) {
        return false;
      }
      if (_filter == _Filter.drafts && j.status != JuiceStatus.draft) {
        return false;
      }
      if (_dateFilter != null && j.date != _dateFilter) return false;
      return matchesQuery(j, _search.text);
    }).toList();
    final searching =
        _search.text.trim().isNotEmpty ||
        _dateFilter != null ||
        _filter != _Filter.all;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(profile: profile, onProfile: _openProfile),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                sliver: SliverList.list(
                  children: [
                    if (_update case final update?) ...[
                      _UpdateCard(
                        update: update,
                        onDownload: () => _downloadUpdate(update),
                        onLater: () => setState(() => _update = null),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      '${juices.isEmpty ? 'Welcome' : 'Welcome back'}, '
                      '${profile.name.trim()}',
                      style: Brand.heading(26),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.edit_note, size: 28),
                      label: const Text('CREATE DAILY JUICE'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 62),
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                sliver: SliverList.list(
                  children: [
                    Text('MY DAILY JUICES', style: Brand.heading(20)),
                    if (juices.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _search,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Search by title or date',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        icon: const Icon(Icons.close),
                                        onPressed: _search.clear,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Find by date',
                            iconSize: 26,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(52, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: juices.isEmpty
                                ? null
                                : () => _pickDateFilter(juices),
                            icon: const Icon(Icons.calendar_month_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in _Filter.values)
                            ChoiceChip(
                              label: Text(switch (f) {
                                _Filter.all => 'All',
                                _Filter.drafts => 'Drafts',
                                _Filter.generated => 'Generated',
                              }),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          if (_dateFilter != null)
                            InputChip(
                              avatar: const Icon(Icons.event, size: 18),
                              label: Text(friendlyDate(_dateFilter!)),
                              onDeleted: () =>
                                  setState(() => _dateFilter = null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
              if (results.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyResults(
                    hasAny: juices.isNotEmpty,
                    searching: searching,
                    onClear: _clearSearch,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.list(children: _groupedTiles(results)),
                ),
              const SliverToBoxAdapter(
                child: SafeArea(top: false, child: YfcFooter()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Results grouped under month headings ("OCTOBER 2026").
  List<Widget> _groupedTiles(List<DailyJuice> results) {
    final out = <Widget>[];
    String? month;
    for (final j in results) {
      final m = '${_monthNames[j.date.month - 1]} ${j.date.year}';
      if (m != month) {
        month = m;
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(m, style: Brand.heading(15, color: Brand.muted)),
          ),
        );
      } else {
        out.add(const SizedBox(height: 10));
      }
      out.add(_JuiceTile(juice: j));
    }
    return out;
  }
}

/// "New version available", with what changed and how to install it.
class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.update,
    required this.onDownload,
    required this.onLater,
  });

  final AppUpdate update;
  final VoidCallback onDownload;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: SectionStyle.accent, width: 1.5),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update, color: SectionStyle.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NEW VERSION AVAILABLE (${update.version})',
                  style: Brand.heading(18, color: SectionStyle.accent),
                ),
              ),
            ],
          ),
          if (update.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              update.notes,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Tap DOWNLOAD, then open the downloaded file and tap Update. '
            'Your Daily Juices and profile stay on your phone.',
            style: TextStyle(color: Brand.muted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onLater, child: const Text('LATER')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download),
                label: const Text('DOWNLOAD'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.profile, required this.onProfile});

  final Profile profile;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    // Straight-edged, with the author's photo on the left of the name,
    // the way the photo sits beside the title on a Daily Juice page.
    return Container(
      color: Brand.charcoal,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: StripePainter(color: Color(0x12FFFFFF)),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 18, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ProfilePhoto(profile: profile, onTap: onProfile),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppNameMark(),
                          SizedBox(height: 4),
                          Text(
                            Ministry.tagline,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const ReachPill(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The author's photo (opens the profile), with a small edit badge.
class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.profile, required this.onTap});

  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Edit profile',
    child: GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 6,
                  offset: Offset(2, 3),
                ),
              ],
            ),
            child: StoredImage(
              path: profile.photoPath,
              builder: (_, image) =>
                  CroppedPhoto(image: image, crop: profile.photoCrop),
            ),
          ),
          Positioned(
            right: -6,
            bottom: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Brand.charcoal, width: 1.5),
              ),
              child: const Icon(Icons.edit, size: 12, color: Brand.charcoal),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({
    required this.hasAny,
    required this.searching,
    required this.onClear,
  });

  final bool hasAny;
  final bool searching;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
    child: Column(
      children: [
        Icon(
          hasAny ? Icons.search_off : Icons.auto_stories_outlined,
          size: 40,
          color: Brand.muted,
        ),
        const SizedBox(height: 8),
        Text(
          !hasAny
              ? 'You have not written a Daily Juice yet. Tap “Create '
                    'Daily Juice” to start.'
              : 'No Daily Juice matches your search.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.muted, fontSize: 15),
        ),
        if (hasAny && searching)
          TextButton(onPressed: onClear, child: const Text('Show all')),
      ],
    ),
  );
}

class _JuiceTile extends StatelessWidget {
  const _JuiceTile({required this.juice});

  final DailyJuice juice;

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this Daily Juice?'),
        content: Text(
          '“${juice.title.isEmpty ? 'Untitled' : juice.title}” will be '
          'permanently deleted from this phone.',
        ),
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
    if (ok == true && context.mounted) {
      await AppScope.read(context).deleteJuice(juice);
    }
  }

  void _edit(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => EditorScreen(initial: juice)));

  void _view(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => ResultScreen(juiceId: juice.id)));

  @override
  Widget build(BuildContext context) {
    final generated = juice.status == JuiceStatus.generated;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => generated ? _view(context) : _edit(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              JuiceThumbnail(juice: juice),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      juice.title.trim().isEmpty
                          ? 'UNTITLED'
                          : juice.title.trim().toUpperCase(),
                      style: Brand.heading(21),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      friendlyDate(juice.date),
                      style: const TextStyle(color: Brand.muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatusChip(generated: generated),
                        if (!generated) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Edited ${timeAgo(juice.updatedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Brand.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _edit(context);
                  if (v == 'view') _view(context);
                  if (v == 'delete') _delete(context);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(generated ? 'Edit' : 'Continue writing'),
                  ),
                  if (generated)
                    const PopupMenuItem(
                      value: 'view',
                      child: Text('View, save or share'),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.generated});

  final bool generated;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: generated ? const Color(0xFFE6F2E7) : const Color(0xFFF1F0EE),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      generated ? 'GENERATED' : 'DRAFT',
      style: TextStyle(
        fontFamily: Brand.condensed,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.6,
        color: generated ? Brand.ok : Brand.muted,
      ),
    ),
  );
}
