/// Opens a file, a folder or a web link with the system handler.
///
/// The UI never talks to the OS directly: the desktop implementation lives in
/// `lib/platform/desktop/` and the mobile one is a no-op (spec §12 — the
/// folder section is desktop only).
abstract class SystemOpener {
  /// Whether the platform can open anything at all.
  bool get isSupported;

  /// Opens a local file or folder with the file manager.
  Future<bool> openPath(String path);

  /// Opens a web link with the default browser.
  Future<bool> openUrl(String url);
}

/// Used on platforms without a desktop file manager.
class UnsupportedSystemOpener implements SystemOpener {
  const UnsupportedSystemOpener();

  @override
  bool get isSupported => false;

  @override
  Future<bool> openPath(String path) async => false;

  @override
  Future<bool> openUrl(String url) async => false;
}
