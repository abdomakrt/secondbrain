import 'package:flutter/material.dart';

import '../../../core/dates.dart';

/// Picks a calendar day and returns the local midnight (epoch ms).
Future<int?> pickDay(BuildContext context, {int? current}) async {
  final now = DateTime.now();
  final initial = current == null
      ? now
      : DateTime.fromMillisecondsSinceEpoch(current);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year + 5),
  );
  if (picked == null) return null;
  return startOfDay(picked);
}

/// Picks a time of day and returns minutes since midnight.
Future<int?> pickTimeOfDay(BuildContext context, {int? current}) async {
  final base = current == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(current);
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
  );
  if (picked == null) return null;
  return picked.hour * 60 + picked.minute;
}

/// Combines a day and a time into an absolute timestamp (epoch ms).
int combineDayAndTime(int dayStartMs, int minutesOfDay) {
  final d = DateTime.fromMillisecondsSinceEpoch(dayStartMs);
  return DateTime(d.year, d.month, d.day, minutesOfDay ~/ 60, minutesOfDay % 60)
      .millisecondsSinceEpoch;
}

/// A field that shows a date and lets the user pick or clear it.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon = Icons.event_outlined,
    this.clearable = true,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final IconData icon;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? '—'
        : '${relativeDayLabel(value!)} • ${formatClock(value!)}';
    return OutlinedButton.icon(
      onPressed: () async {
        final day = await pickDay(context, current: value);
        if (day == null || !context.mounted) return;
        final minutes = await pickTimeOfDay(context, current: value);
        if (minutes == null) return;
        onChanged(combineDayAndTime(day, minutes));
      },
      icon: Icon(icon),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(text),
        ],
      ),
    );
  }
}
