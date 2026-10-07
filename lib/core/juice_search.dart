import '../models/daily_juice.dart';
import 'juice_date.dart';

const _shortMonths = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// Everything a Daily Juice can be found by: its title and its date written
/// the ways people type dates ("8 October 2026", "8 oct", "08/10/2026",
/// "2026-10-08", "Thursday").
String searchableText(DailyJuice j) {
  final d = j.date;
  return [
    j.title,
    friendlyDate(d),
    '${d.day} ${_shortMonths[d.month - 1]} ${d.year}',
    toIsoDate(d),
    '${d.day}/${d.month}/${d.year}',
    '${_two(d.day)}/${_two(d.month)}/${d.year}',
    '${_two(d.day)}-${_two(d.month)}-${d.year}',
  ].join(' | ').toLowerCase().replaceAll(',', '');
}

/// True when every word of [query] appears in the title or the date.
bool matchesQuery(DailyJuice j, String query) {
  final q = query.trim().toLowerCase().replaceAll(',', '');
  if (q.isEmpty) return true;
  final haystack = searchableText(j);
  if (haystack.contains(q)) return true;
  return q.split(RegExp(r'\s+')).every(haystack.contains);
}

/// "just now", "5 minutes ago", "yesterday", "3 days ago", "12 Sep 2026".
String timeAgo(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) {
    return diff.inMinutes == 1
        ? '1 minute ago'
        : '${diff.inMinutes} minutes ago';
  }
  if (diff.inHours < 24) {
    return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
  }
  final days = dateOnly(current).difference(dateOnly(time)).inDays;
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  final m = _shortMonths[time.month - 1];
  return '${time.day} ${m[0].toUpperCase()}${m.substring(1)} ${time.year}';
}
