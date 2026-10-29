// Calendar helpers for the manager app.
//
// Weeks are Sunday..Saturday and a week is keyed by its Sunday
// dateKey (yyyy-MM-dd) — the same convention DeliveryFlow uses for
// summaries, adjustments and rollups, so both apps always agree on
// which week a day or an adjustment belongs to.

/// yyyy-MM-dd for a calendar date.
String dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses a yyyy-MM-dd key. Throws on a malformed key.
DateTime parseDateKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// The Sunday starting the week that contains [date].
/// Calendar arithmetic (never Duration addition) so a DST
/// transition inside the week cannot shift the wall-clock date.
DateTime weekStartSunday(DateTime date) {
  final dayOnly = DateTime(date.year, date.month, date.day);
  // DateTime.weekday: Mon=1 .. Sun=7. Sunday starts the week.
  final back = dayOnly.weekday == 7 ? 0 : dayOnly.weekday;
  return DateTime(dayOnly.year, dayOnly.month, dayOnly.day - back);
}

/// Adds whole calendar days (DST-safe: Oct 25 + 6 days is Oct 31
/// even when a 25-hour day sits between them).
DateTime addDays(DateTime date, int days) {
  return DateTime(date.year, date.month, date.day + days);
}

/// The week's key: the dateKey of its Sunday.
String weekKeyOf(DateTime date) => dateKey(weekStartSunday(date));

/// The 7 dateKeys of a week, Sunday..Saturday, in order.
List<String> weekDateKeys(DateTime date) {
  final start = weekStartSunday(date);
  return [
    for (var i = 0; i < 7; i++)
      dateKey(addDays(start, i)),
  ];
}

/// Human label for a dateKey (e.g. "الخميس 29 أكتوبر") — weekday
/// names in Arabic, no dependency on intl.
String arabicDayLabel(String key) {
  const weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  final d = parseDateKey(key);
  final wd = weekdays[d.weekday - 1];
  return '$wd ${d.day} ${months[d.month - 1]}';
}

/// dateKey for a [DateTime] built from epoch millis (local timezone).
String dateKeyOfMillis(int millis) =>
    dateKey(DateTime.fromMillisecondsSinceEpoch(millis));
