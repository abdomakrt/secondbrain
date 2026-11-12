/// Android share-intent interface (spec §9.7).
///
/// The Android share sheet sends text and links to the app; the capture
/// screen then shows the same fields as the desktop window.
library;

class SharedContent {
  const SharedContent({this.text, this.url, this.title});

  final String? text;
  final String? url;
  final String? title;
}

abstract class ShareIntentSource {
  /// The content shared into the app (null when the app was opened normally).
  Future<SharedContent?> pendingSharedContent();

  /// Consumes the pending shared content so it is not handled twice.
  Future<void> clearPendingSharedContent();
}

/// Default implementation until the Android plugin is wired in.
class NoopShareIntentSource implements ShareIntentSource {
  const NoopShareIntentSource();

  @override
  Future<SharedContent?> pendingSharedContent() async => null;

  @override
  Future<void> clearPendingSharedContent() async {}
}
