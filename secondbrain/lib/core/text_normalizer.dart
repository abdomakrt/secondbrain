import 'package:unorm_dart/unorm_dart.dart';

/// Arabic text normalization for the FTS5 index and queries (spec §6.2).
///
/// Applied identically to stored text and to the query so both share one form.
String normalizeForSearch(String input) {
  var s = nfkc(input);

  // 2. Tashkeel + Quranic annotation marks.
  s = s.replaceAll(_diacritics, '');
  // 3. Tatweel.
  s = s.replaceAll('\u0640', '');
  // 4. Unify alef forms.
  s = s.replaceAll(_alefVariants, 'ا');
  // 5. ى→ي and ة→ه.
  s = s.replaceAll('ى', 'ي').replaceAll('ة', 'ه');
  // 6. Arabic-Indic and Persian digits → ASCII.
  s = s.replaceAllMapped(_easternDigits, (m) {
    final c = m[0]!.codeUnitAt(0);
    final base = c >= 0x06F0 ? 0x06F0 : 0x0660;
    return String.fromCharCode(0x30 + c - base);
  });
  // 7. Latin → lowercase.
  s = s.toLowerCase();
  // 8. Invisible control / bidi marks.
  s = s.replaceAll(_invisible, '');
  // 9. Squeeze whitespace.
  return s.replaceAll(_whitespace, ' ').trim();
}

final _diacritics = RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED]');
final _alefVariants = RegExp('[أإآٱ]');
final _easternDigits = RegExp('[\u0660-\u0669\u06F0-\u06F9]');
final _invisible = RegExp('[\u200B-\u200F\u202A-\u202E]');
final _whitespace = RegExp(r'\s+');

/// Word tokens of a normalized text (letters/digits only).
Iterable<String> tokens(String normalized) => normalized
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((t) => t.isNotEmpty);

/// Spec §6.3: token length > 4 after dropping a leading «ال».
String stripAl(String token) {
  if (token.startsWith('ال') && token.length > 2) return token.substring(2);
  return token;
}

/// Stems column content for [texts] (space-joined).
String buildStems(Iterable<String> texts) {
  final out = <String>{};
  for (final text in texts) {
    for (final t in tokens(normalizeForSearch(text))) {
      final s = stripAl(t);
      if (s.length > 4) out.add(s);
    }
  }
  return out.join(' ');
}

/// FTS5 MATCH expression for a query (spec §6.3): prefix match on the token
/// and on its «ال»-stripped form, tokens joined with AND.
String ftsMatchExpression(String query) {
  final parts = <String>[];
  for (final t in tokens(normalizeForSearch(query))) {
    final s = stripAl(t);
    if (s != t && s.isNotEmpty) {
      parts.add('($t* OR $s*)');
    } else {
      parts.add('$t*');
    }
  }
  return parts.join(' AND ');
}
