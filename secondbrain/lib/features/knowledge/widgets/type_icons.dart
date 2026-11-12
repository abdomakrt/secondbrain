import 'package:flutter/material.dart';

/// Icon per built-in knowledge type (by Arabic name).
IconData iconForType(String name) {
  switch (name) {
    case 'ملاحظة':
      return Icons.sticky_note_2_outlined;
    case 'معلومة':
      return Icons.lightbulb_outline;
    case 'رابط':
      return Icons.link;
    case 'أداة':
      return Icons.build_outlined;
    case 'تجربة':
      return Icons.science_outlined;
    case 'قرار':
      return Icons.gavel_outlined;
    case 'فكرة':
      return Icons.emoji_objects_outlined;
    case 'أمر تقني':
      return Icons.terminal;
    case 'ملخص محادثة':
      return Icons.chat_bubble_outline;
    case 'ملخص':
      return Icons.summarize_outlined;
    case 'بحث':
      return Icons.manage_search;
    case 'سؤال':
      return Icons.help_outline;
    default:
      return Icons.category_outlined;
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

/// yyyy-MM-dd HH:mm from epoch ms (UTC-stored → local display).
String formatStamp(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  return '${d.year}-${_two(d.month)}-${_two(d.day)} '
      '${_two(d.hour)}:${_two(d.minute)}';
}
