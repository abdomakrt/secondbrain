/// Date and time helpers for the Arabic UI.
///
/// Timestamps are stored as UTC milliseconds (spec §5.1). *Day* values
/// (`planned_date`) are stored as the local midnight of that day so that
/// "today" means the user's today, not UTC today.
library;

const _weekdaysAr = [
  'الأحد', // DateTime.weekday == 1
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت', // DateTime.weekday == 6 (week start default per A3)
];

const _monthsAr = [
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

/// Weekday name in Arabic. [DateTime.weekday]: Monday = 1 … Sunday = 7.
String weekdayNameAr(DateTime d) => _weekdaysAr[(d.weekday - 1) % 7];

/// Month name in Arabic.
String monthNameAr(DateTime d) => _monthsAr[d.month - 1];

/// Local midnight of [day] as epoch milliseconds.
int startOfDay(DateTime day) =>
    DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;

/// Local midnight of today as epoch milliseconds.
int startOfToday() => startOfDay(DateTime.now());

/// Local midnight of the day [offset] days from today (negative = past).
int dayOffset(int offset) =>
    startOfDay(DateTime.now().add(Duration(days: offset)));

/// True when both stamps fall on the same local day.
bool isSameLocalDay(int? a, int? b) {
  if (a == null || b == null) return false;
  return startOfDay(DateTime.fromMillisecondsSinceEpoch(a)) ==
      startOfDay(DateTime.fromMillisecondsSinceEpoch(b));
}

/// The local day that contains [ms].
DateTime localDayOf(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return DateTime(d.year, d.month, d.day);
}

/// "اليوم" / "أمس" / "غدًا" / a date — for task due labels.
String relativeDayLabel(int ms, {int? todayMs}) {
  final now = todayMs ?? DateTime.now().millisecondsSinceEpoch;
  final today = startOfDay(DateTime.fromMillisecondsSinceEpoch(now));
  final day = startOfDay(DateTime.fromMillisecondsSinceEpoch(ms));
  final diff = (day - today) ~/ Duration.millisecondsPerDay;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'غدًا';
  if (diff == -1) return 'أمس';
  if (diff == 2) return 'بعد غد';
  if (diff > 0 && diff < 7) {
    return weekdayNameAr(DateTime.fromMillisecondsSinceEpoch(ms));
  }
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day} ${monthNameAr(d)}';
}

/// "HH:mm" in 24-hour form.
String formatClock(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_two(d.hour)}:${_two(d.minute)}';
}

/// "HH:mm" for a minutes-since-midnight value (planned_start_min).
String formatMinutesOfDay(int? minutes) {
  if (minutes == null) return '';
  final m = minutes.clamp(0, 24 * 60 - 1);
  return '${_two(m ~/ 60)}:${_two(m % 60)}';
}

/// "YYYY-MM-DD" — stable, sortable, used in exports and chips.
String formatIsoDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${_two(d.month)}-${_two(d.day)}';
}

/// "YYYY-MM-DD HH:mm" from epoch ms (existing convention in the app).
String formatStamp(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${_two(d.month)}-${_two(d.day)} '
      '${_two(d.hour)}:${_two(d.minute)}';
}

/// Duration in minutes → "1 س 30 د" / "45 د".
String formatMinutes(int minutes) {
  if (minutes <= 0) return '—';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m د';
  if (m == 0) return '$h س';
  return '$h س $m د';
}

/// Rough relative time for activity stamps: "الآن", "قبل 5 د", "أمس".
String formatRelativeTime(int ms, {int? nowMs}) {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final diff = now - ms;
  if (diff < 60 * 1000) return 'الآن';
  if (diff < 60 * 60 * 1000) return 'قبل ${diff ~/ (60 * 1000)} د';
  if (diff < 24 * 60 * 60 * 1000) return 'قبل ${diff ~/ (60 * 60 * 1000)} س';
  final days = diff ~/ (24 * 60 * 60 * 1000);
  if (days == 1) return 'أمس';
  if (days < 30) return 'قبل $days يوم';
  return formatIsoDate(ms);
}

String _two(int v) => v.toString().padLeft(2, '0');
