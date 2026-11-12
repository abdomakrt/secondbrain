import 'package:flutter/material.dart';

/// Keeps the content readable on wide windows.
///
/// Forms, lists and buttons never stretch past [maxWidth]: they stay
/// centred in the available space instead of filling the whole screen.
/// On narrow windows (phones) the width is the available one, so nothing
/// changes there.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 900,
  });

  /// The widest the content may become (logical pixels).
  final double maxWidth;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Widths used across the app so every screen feels the same.
class ContentWidths {
  const ContentWidths._();

  /// Forms (create/edit dialogs and screens).
  static const double form = 720;

  /// Lists (knowledge, tasks, projects, courses, inbox).
  static const double list = 1000;

  /// Grids and dense dashboards.
  static const double dashboard = 1240;

  /// Settings and read-only details.
  static const double details = 820;

  /// The quick-capture window.
  static const double capture = 680;
}
