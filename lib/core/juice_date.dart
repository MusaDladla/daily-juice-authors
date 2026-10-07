/// Date helpers. Dates are stored as calendar dates (no time zone) in
/// ISO `YYYY-MM-DD` form so a Daily Juice never shifts day across zones.
library;

const _weekdays = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The header date exactly as the template shows it: `WEDNESDAY` + `30` +
/// superscript `TH`.
class TemplateDate {
  const TemplateDate(this.weekday, this.day, this.suffix);

  final String weekday;
  final String day;
  final String suffix;

  factory TemplateDate.of(DateTime date) => TemplateDate(
    _weekdays[date.weekday - 1],
    '${date.day}',
    ordinalSuffix(date.day),
  );

  @override
  String toString() => '$weekday $day$suffix';
}

String ordinalSuffix(int day) {
  if (day % 100 >= 11 && day % 100 <= 13) return 'TH';
  switch (day % 10) {
    case 1:
      return 'ST';
    case 2:
      return 'ND';
    case 3:
      return 'RD';
    default:
      return 'TH';
  }
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String toIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseIsoDate(String? value) {
  if (value == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime(y, mo, d);
  if (date.year != y || date.month != mo || date.day != d) return null;
  return date;
}

/// "Wednesday, 30 September 2026" — used in the app UI, not on the template.
String friendlyDate(DateTime d) {
  final weekday = _weekdays[d.weekday - 1];
  return '${weekday[0]}${weekday.substring(1).toLowerCase()}, '
      '${d.day} ${_months[d.month - 1]} ${d.year}';
}
