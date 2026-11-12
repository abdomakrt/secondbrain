import 'package:flutter/material.dart';

/// A [StreamBuilder] that keeps a single subscription for the lifetime of the
/// widget.
///
/// The stream factory is called once (in `initState`), so a query is not
/// re-run on every rebuild — which also avoids drift re-subscribing (and
/// scheduling a clean-up) on each frame.
class DbStreamBuilder<T> extends StatefulWidget {
  const DbStreamBuilder({
    super.key,
    required this.streamFactory,
    required this.builder,
  });

  final Stream<T> Function() streamFactory;
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot) builder;

  @override
  State<DbStreamBuilder<T>> createState() => _DbStreamBuilderState<T>();
}

class _DbStreamBuilderState<T> extends State<DbStreamBuilder<T>> {
  late final Stream<T> _stream = widget.streamFactory();

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        stream: _stream,
        builder: widget.builder,
      );
}
