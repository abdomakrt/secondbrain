import 'dart:io';

import '../system_opener.dart';

/// Opens paths and links with `xdg-open` (Linux desktop).
///
/// `xdg-open` is the freedesktop standard: it opens folders in the file
/// manager and links in the browser, whatever the user configured.
class XdgSystemOpener implements SystemOpener {
  const XdgSystemOpener();

  @override
  bool get isSupported => Platform.isLinux;

  @override
  Future<bool> openPath(String path) => _open(path);

  @override
  Future<bool> openUrl(String url) => _open(url);

  Future<bool> _open(String target) async {
    if (target.trim().isEmpty) return false;
    try {
      final result = await Process.run('xdg-open', [target]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}
