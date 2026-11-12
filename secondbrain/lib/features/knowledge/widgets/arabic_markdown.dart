import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Markdown renderer with the project's conventions baked in:
/// - Single newline renders as a line break (`softLineBreak: true`) — needed
///   for imported Google Keep notes (spec §2 note format).
/// - Code blocks are always LTR (`AGENTS.md` convention) even though the app
///   is RTL — flutter_markdown inherits the ambient direction otherwise.
class ArabicMarkdownBody extends StatelessWidget {
  const ArabicMarkdownBody({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      softLineBreak: true,
      builders: {
        'pre': _LtrCodeBlockBuilder(),
      },
    );
  }
}

class _LtrCodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    // Replaces the default pre rendering; keeps the code style but forces
    // an LTR block. A little padding stands in for the codeblock style.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        child: Text(text.text, style: preferredStyle),
      ),
    );
  }
}
