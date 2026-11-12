/// Hybrid Logical Clock (spec §7.2).
///
/// Text form: `{ms zero-padded to 13}-{counter as 4 hex digits}-{device_id}`.
/// Fixed widths make plain string comparison the ordering rule: larger wins.
class HlcClock {
  HlcClock({required this.deviceId, int Function()? nowMs})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final String deviceId;
  final int Function() _nowMs;

  int _ms = 0;
  int _counter = 0;

  /// The current logical time (what gets stamped on writes).
  String get last => '${_format(_ms, _counter)}-$deviceId';

  /// Wall-clock ms behind [last]; use as `updated_at` when stamping a row.
  int get lastMs => _ms;

  /// Local event: advance the clock and return the new logical time.
  String tick() {
    final now = _nowMs();
    if (now > _ms) {
      _ms = now;
      _counter = 0;
    } else {
      _counter++;
      if (_counter > 0xffff) {
        // Counter overflow: bump the ms so widths stay fixed.
        _ms++;
        _counter = 0;
      }
    }
    return last;
  }

  /// Merge a remote record's clock (called when receiving data in sync).
  String recv(String remote) {
    final r = parse(remote);
    final now = _nowMs();
    final m = _max(now, _max(_ms, r.ms));
    if (_ms == r.ms && _ms == m) {
      _counter = (_counter > r.counter ? _counter : r.counter) + 1;
    } else if (_ms == m) {
      _counter++;
    } else if (r.ms == m) {
      _counter = r.counter + 1;
    } else {
      _counter = 0;
    }
    _ms = m;
    if (_counter > 0xffff) {
      _counter = 0;
      _ms++;
    }
    return last;
  }

  static int _max(int a, int b) => a > b ? a : b;

  static String _format(int ms, int counter) =>
      '${ms.toString().padLeft(13, '0')}-${counter.toRadixString(16).padLeft(4, '0')}';

  /// Splits the device id last so uuid device ids (containing `-`) survive.
  static ({int ms, int counter, String deviceId}) parse(String hlc) {
    final i = hlc.indexOf('-');
    final j = hlc.indexOf('-', i + 1);
    return (
      ms: int.parse(hlc.substring(0, i)),
      counter: int.parse(hlc.substring(i + 1, j), radix: 16),
      deviceId: hlc.substring(j + 1),
    );
  }
}
